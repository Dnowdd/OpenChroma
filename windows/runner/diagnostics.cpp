// Hardware checkup: stress tests that verify their own results (unstable
// hardware computes wrong before it crashes) plus the memory, board and BIOS
// inventory from SMBIOS. Tests run one after another on a background thread;
// Dart starts them with OcDiagStart, polls OcDiagRead and may OcDiagCancel.
//
// Tests (all report errors, i.e. results that differ from a reference):
// - cpu:     AVX2/FMA kernel when the CPU has it, a scalar one otherwise, on
//            N threads; score = kernel runs per second.
// - memory:  fills a buffer with an address-derived pattern and checks it,
//            alternating the pattern and its inverse; GB/s both ways.
// - gpu:     a D3D11 compute shader on the GPU with the most dedicated memory,
//            calibrated so each dispatch takes ~60 ms on any GPU (no driver
//            timeouts on weak ones); every few seconds a run from known input
//            is compared bit for bit with the first one.
// - cpugpu:  both at once.
// - disk:    writes and reads back a file without the OS cache.
#include <windows.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <dxgi.h>
#include <immintrin.h>
#include <intrin.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "json_writer.h"

namespace {

using oc::Json;
using oc::Utf8;

double Now() {
  using namespace std::chrono;
  return duration<double>(steady_clock::now().time_since_epoch()).count();
}

// ---------------------------------------------------------------- CPU

bool HasAvx2Fma() {
  int r[4];
  __cpuid(r, 0);
  if (r[0] < 7) return false;
  __cpuid(r, 1);
  const bool fma = ((r[2] >> 12) & 1) != 0, osxsave = ((r[2] >> 27) & 1) != 0,
             avx = ((r[2] >> 28) & 1) != 0;
  if (!fma || !osxsave || !avx) return false;
  if ((_xgetbv(0) & 6) != 6) return false;  // OS saves YMM state
  __cpuidex(r, 7, 0);
  return ((r[1] >> 5) & 1) != 0;
}

uint64_t Mix(uint64_t h, double d) {
  uint64_t bits;
  memcpy(&bits, &d, 8);
  return (h ^ bits) * 0x100000001B3ull;
}

uint64_t IntegerPart(uint64_t seed) {
  uint64_t x = seed | 1;
  for (int i = 0; i < 60000; i++) {
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    x *= 0x9E3779B97F4A7C15ull;
  }
  return x;
}

// Deterministic: the same seed must always give the same result.
uint64_t KernelAvx2(uint64_t seed) {
  __m256d acc[8];
  for (int k = 0; k < 8; k++) {
    acc[k] = _mm256_set_pd(static_cast<double>((seed + k) & 0xFF) * 0.01,
                           static_cast<double>((seed >> 8) & 0xFF) * 0.01 + k,
                           0.5 + k, 1.5 + k);
  }
  const __m256d m = _mm256_set1_pd(0.9999993);
  const __m256d a = _mm256_set1_pd(1.0e-7);
  for (int i = 0; i < 120000; i++) {
    for (int k = 0; k < 8; k++) acc[k] = _mm256_fmadd_pd(acc[k], m, a);
  }
  uint64_t h = IntegerPart(seed);
  alignas(32) double out[4];
  for (int k = 0; k < 8; k++) {
    _mm256_store_pd(out, acc[k]);
    for (double d : out) h = Mix(h, d);
  }
  return h;
}

uint64_t KernelScalar(uint64_t seed) {
  double acc[8];
  for (int k = 0; k < 8; k++) acc[k] = static_cast<double>((seed + k) & 0xFF) * 0.01 + k;
  for (int i = 0; i < 120000; i++) {
    for (int k = 0; k < 8; k++) acc[k] = acc[k] * 0.9999993 + 1.0e-7;
  }
  uint64_t h = IntegerPart(seed);
  for (double d : acc) h = Mix(h, d);
  return h;
}

// ---------------------------------------------------------------- Memory

inline uint64_t Pattern(uint64_t index, uint64_t pass) {
  uint64_t x = index * 0x9E3779B97F4A7C15ull ^ (pass * 0xD1B54A32D192ED03ull);
  x ^= x >> 31;
  x *= 0xBF58476D1CE4E5B9ull;
  x ^= x >> 29;
  return x;
}

// ---------------------------------------------------------------- GPU

const char kShader[] = R"(
RWStructuredBuffer<float> buf : register(u0);
cbuffer C : register(b0) { uint iters; uint3 pad; }
[numthreads(256, 1, 1)]
void main(uint3 id : SV_DispatchThreadID) {
  float x0 = buf[id.x], x1 = x0 + 1, x2 = x0 + 2, x3 = x0 + 3;
  float x4 = x0 * 0.5, x5 = x1 * 0.5, x6 = x2 * 0.5, x7 = x3 * 0.5;
  [loop] for (uint i = 0; i < iters; i++) {
    x0 = mad(x0, 0.99991, 0.00009); x1 = mad(x1, 0.99992, 0.00008);
    x2 = mad(x2, 0.99993, 0.00007); x3 = mad(x3, 0.99994, 0.00006);
    x4 = mad(x4, 0.99995, 0.00005); x5 = mad(x5, 0.99996, 0.00004);
    x6 = mad(x6, 0.99997, 0.00003); x7 = mad(x7, 0.99998, 0.00002);
  }
  buf[id.x] = x0 + x1 + x2 + x3 + x4 + x5 + x6 + x7;
}
)";

template <typename T>
void SafeRelease(T*& p) {
  if (p) p->Release();
  p = nullptr;
}

// ---------------------------------------------------------------- Runner

enum class Kind { kCpu, kMemory, kGpu, kCpuGpu, kDisk };

struct Step {
  Kind kind = Kind::kCpu;
  double seconds = 30;
  int threads = 0;      // cpu, cpugpu: 0 = all
  size_t megabytes = 0;  // memory, disk
  std::string id;

  // Results.
  std::string status = "pending";  // pending running done cancelled failed
  std::string error;
  uint64_t errors = 0;      // memory, disk
  uint64_t cpu_errors = 0;  // cpu, cpugpu
  uint64_t gpu_errors = 0;  // gpu, cpugpu
  double cpu_rate = 0;  // kernel runs per second
  std::string cpu_kernel;
  double mem_write = 0, mem_read = 0;  // GB/s
  double gpu_tflops = 0;
  std::string gpu_name;
  uint64_t gpu_checks = 0;
  double disk_write = 0, disk_read = 0;  // MB/s
  double elapsed = 0;
};

class Runner {
 public:
  bool Start(std::vector<Step> steps) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (running_) return false;
    if (thread_.joinable()) thread_.join();
    steps_ = std::move(steps);
    current_ = -1;
    cancel_ = false;
    running_ = true;
    thread_ = std::thread([this] { Run(); });
    return true;
  }

  void Cancel() { cancel_ = true; }

  std::string State() {
    std::lock_guard<std::mutex> lock(mutex_);
    Json j;
    j.Obj();
    j.Key("running").Bool(running_);
    j.Key("current").Int(current_);
    j.Key("stepElapsed").Num(current_ >= 0 && running_ ? Now() - step_start_ : 0);
    j.Key("steps").Arr();
    for (const auto& s : steps_) {
      j.Obj();
      j.Key("id").Str(s.id);
      j.Key("status").Str(s.status);
      j.Key("error").Str(s.error);
      j.Key("errors").Int(static_cast<long long>(s.errors + s.cpu_errors + s.gpu_errors));
      j.Key("cpuErrors").Int(static_cast<long long>(s.cpu_errors));
      j.Key("gpuErrors").Int(static_cast<long long>(s.gpu_errors));
      j.Key("seconds").Num(s.seconds);
      j.Key("elapsed").Num(s.elapsed);
      j.Key("cpuRate").Num(s.cpu_rate);
      j.Key("cpuKernel").Str(s.cpu_kernel);
      j.Key("threads").Int(s.threads);
      j.Key("megabytes").Int(static_cast<long long>(s.megabytes));
      j.Key("memWrite").Num(s.mem_write);
      j.Key("memRead").Num(s.mem_read);
      j.Key("gpuTflops").Num(s.gpu_tflops);
      j.Key("gpuName").Str(s.gpu_name);
      j.Key("gpuChecks").Int(static_cast<long long>(s.gpu_checks));
      j.Key("diskWrite").Num(s.disk_write);
      j.Key("diskRead").Num(s.disk_read);
      j.EndObj();
    }
    j.EndArr();
    j.EndObj();
    return j.str;
  }

 private:
  // Thread-safe updates of the step being run.
  template <typename F>
  void Update(int i, F f) {
    std::lock_guard<std::mutex> lock(mutex_);
    f(steps_[i]);
  }

  void Run() {
    for (int i = 0; i < static_cast<int>(steps_.size()); i++) {
      {
        std::lock_guard<std::mutex> lock(mutex_);
        if (cancel_) {
          steps_[i].status = "cancelled";
          continue;
        }
        current_ = i;
        step_start_ = Now();
        steps_[i].status = "running";
      }
      Step s;
      {
        std::lock_guard<std::mutex> lock(mutex_);
        s = steps_[i];
      }
      bool ok = true;
      switch (s.kind) {
        case Kind::kCpu:
          RunCpu(i, s.threads, s.seconds);
          break;
        case Kind::kMemory:
          ok = RunMemory(i, s.megabytes, s.seconds);
          break;
        case Kind::kGpu:
          ok = RunGpu(i, s.seconds);
          break;
        case Kind::kCpuGpu: {
          std::thread cpu([&] { RunCpu(i, s.threads, s.seconds); });
          ok = RunGpu(i, s.seconds);
          cpu.join();
          break;
        }
        case Kind::kDisk:
          ok = RunDisk(i, s.megabytes);
          break;
      }
      Update(i, [&](Step& st) {
        st.elapsed = Now() - step_start_;
        if (st.status == "running") st.status = cancel_ ? "cancelled" : ok ? "done" : "failed";
      });
    }
    std::lock_guard<std::mutex> lock(mutex_);
    running_ = false;
    current_ = -1;
  }

  void RunCpu(int index, int threads, double seconds) {
    const bool avx2 = HasAvx2Fma();
    auto kernel = avx2 ? KernelAvx2 : KernelScalar;
    if (threads <= 0) threads = static_cast<int>(std::thread::hardware_concurrency());
    constexpr int kSeeds = 16;
    uint64_t reference[kSeeds];
    for (int s = 0; s < kSeeds; s++) reference[s] = kernel(1234 + s);
    std::atomic<bool> stop{false};
    std::atomic<uint64_t> runs{0}, errors{0};
    std::vector<std::thread> pool;
    for (int t = 0; t < threads; t++) {
      pool.emplace_back([&, t] {
        for (uint64_t n = t; !stop; n++) {
          const int s = static_cast<int>(n % kSeeds);
          if (kernel(1234 + s) != reference[s]) errors++;
          runs++;
        }
      });
    }
    const double start = Now();
    while (Now() - start < seconds && !cancel_) {
      Sleep(250);
      const double t = Now() - start;
      Update(index, [&](Step& st) {
        st.threads = threads;
        st.cpu_kernel = avx2 ? "AVX2" : "escalar";
        st.cpu_rate = runs / t;
        st.cpu_errors = errors;
      });
    }
    stop = true;
    for (auto& th : pool) th.join();
    const double total = Now() - start;
    Update(index, [&](Step& st) {
      st.cpu_rate = total > 0 ? runs / total : 0;
      st.cpu_errors = errors;
    });
  }

  bool RunMemory(int index, size_t megabytes, double seconds) {
    const size_t words = std::max<size_t>(megabytes, 64) * 1024 * 1024 / 8;
    auto* mem = static_cast<uint64_t*>(
        VirtualAlloc(nullptr, words * 8, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE));
    if (!mem) {
      Update(index, [](Step& st) { st.error = "Sem memória livre para o teste"; });
      return false;
    }
    const int threads = static_cast<int>(std::thread::hardware_concurrency());
    auto parallel = [&](auto fn) {
      std::vector<std::thread> pool;
      for (int t = 0; t < threads; t++) {
        pool.emplace_back([&, t] { fn(words * t / threads, words * (t + 1) / threads); });
      }
      for (auto& th : pool) th.join();
    };
    const double start = Now();
    double best_write = 0, best_read = 0;
    uint64_t total_errors = 0;
    for (uint64_t pass = 0; (pass < 2 || Now() - start < seconds) && !cancel_; pass++) {
      const bool invert = (pass & 1) != 0;
      double t0 = Now();
      parallel([&](size_t from, size_t to) {
        for (size_t i = from; i < to && !cancel_; i++) {
          const uint64_t v = Pattern(i, pass);
          mem[i] = invert ? ~v : v;
        }
      });
      const double w = words * 8 / (Now() - t0) / 1e9;
      std::atomic<uint64_t> errors{0};
      t0 = Now();
      parallel([&](size_t from, size_t to) {
        uint64_t local = 0;
        for (size_t i = from; i < to && !cancel_; i++) {
          const uint64_t v = Pattern(i, pass);
          if (mem[i] != (invert ? ~v : v)) local++;
        }
        errors += local;
      });
      const double r = words * 8 / (Now() - t0) / 1e9;
      if (cancel_) break;
      best_write = std::max(best_write, w);
      best_read = std::max(best_read, r);
      total_errors += errors;
      Update(index, [&](Step& st) {
        st.mem_write = best_write;
        st.mem_read = best_read;
        st.errors = total_errors;
      });
    }
    VirtualFree(mem, 0, MEM_RELEASE);
    return true;
  }

  bool RunGpu(int index, double seconds) {
    IDXGIFactory1* factory = nullptr;
    IDXGIAdapter1* best = nullptr;
    ID3D11Device* dev = nullptr;
    ID3D11DeviceContext* ctx = nullptr;
    ID3DBlob* code = nullptr;
    ID3DBlob* err = nullptr;
    ID3D11ComputeShader* cs = nullptr;
    ID3D11Buffer* buf = nullptr;
    ID3D11Buffer* staging = nullptr;
    ID3D11Buffer* cb = nullptr;
    ID3D11UnorderedAccessView* uav = nullptr;
    ID3D11Query* done = nullptr;
    auto fail = [&](const char* message) {
      Update(index, [&](Step& st) { st.error = message; });
      SafeRelease(done);
      SafeRelease(uav);
      SafeRelease(cb);
      SafeRelease(staging);
      SafeRelease(buf);
      SafeRelease(cs);
      SafeRelease(err);
      SafeRelease(code);
      SafeRelease(ctx);
      SafeRelease(dev);
      SafeRelease(best);
      SafeRelease(factory);
      return false;
    };

    if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1), reinterpret_cast<void**>(&factory)))) {
      return fail("DirectX indisponível");
    }
    SIZE_T best_mem = 0;
    IDXGIAdapter1* a = nullptr;
    for (UINT i = 0; factory->EnumAdapters1(i, &a) != DXGI_ERROR_NOT_FOUND; i++) {
      DXGI_ADAPTER_DESC1 d;
      a->GetDesc1(&d);
      // Integrated GPUs report little dedicated memory but still count.
      const SIZE_T mem = d.DedicatedVideoMemory + 1;
      if (!(d.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) && d.VendorId != 0x1414 && mem > best_mem) {
        SafeRelease(best);
        best = a;
        best_mem = mem;
      } else {
        a->Release();
      }
    }
    if (!best) return fail("Nenhuma placa de vídeo encontrada");
    DXGI_ADAPTER_DESC1 desc;
    best->GetDesc1(&desc);
    const std::string name = Utf8(desc.Description);
    Update(index, [&](Step& st) { st.gpu_name = name; });

    const D3D_FEATURE_LEVEL levels[] = {D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0};
    if (FAILED(D3D11CreateDevice(best, D3D_DRIVER_TYPE_UNKNOWN, nullptr, 0, levels, 2,
                                 D3D11_SDK_VERSION, &dev, nullptr, &ctx))) {
      return fail("A placa de vídeo não suporta DirectX 11");
    }
    if (FAILED(D3DCompile(kShader, sizeof(kShader) - 1, nullptr, nullptr, nullptr, "main",
                          "cs_5_0", D3DCOMPILE_OPTIMIZATION_LEVEL3, 0, &code, &err))) {
      return fail("Falha ao preparar o teste da GPU");
    }
    dev->CreateComputeShader(code->GetBufferPointer(), code->GetBufferSize(), nullptr, &cs);

    constexpr UINT kCount = 1 << 21;  // 2M floats
    std::vector<float> init(kCount);
    for (UINT i = 0; i < kCount; i++) init[i] = static_cast<float>(i % 1000) * 0.001f;
    D3D11_BUFFER_DESC bd{};
    bd.ByteWidth = kCount * 4;
    bd.Usage = D3D11_USAGE_DEFAULT;
    bd.BindFlags = D3D11_BIND_UNORDERED_ACCESS;
    bd.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
    bd.StructureByteStride = 4;
    D3D11_SUBRESOURCE_DATA sd{init.data(), 0, 0};
    if (FAILED(dev->CreateBuffer(&bd, &sd, &buf))) return fail("Memória de vídeo insuficiente");
    dev->CreateUnorderedAccessView(buf, nullptr, &uav);
    D3D11_BUFFER_DESC sdesc = bd;
    sdesc.Usage = D3D11_USAGE_STAGING;
    sdesc.BindFlags = 0;
    sdesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    sdesc.MiscFlags = 0;
    dev->CreateBuffer(&sdesc, nullptr, &staging);
    D3D11_BUFFER_DESC cdesc{};
    cdesc.ByteWidth = 16;
    cdesc.Usage = D3D11_USAGE_DEFAULT;
    cdesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
    dev->CreateBuffer(&cdesc, nullptr, &cb);
    D3D11_QUERY_DESC qd{D3D11_QUERY_EVENT, 0};
    dev->CreateQuery(&qd, &done);
    if (!cs || !uav || !staging || !cb || !done) return fail("Falha ao preparar o teste da GPU");

    ctx->CSSetShader(cs, nullptr, 0);
    ctx->CSSetUnorderedAccessViews(0, 1, &uav, nullptr);
    ctx->CSSetConstantBuffers(0, 1, &cb);
    auto wait = [&] {
      ctx->End(done);
      while (ctx->GetData(done, nullptr, 0, 0) == S_FALSE) Sleep(0);
    };
    UINT iters = 64;
    auto set_iters = [&](UINT n) {
      iters = n;
      const UINT data[4] = {iters, 0, 0, 0};
      ctx->UpdateSubresource(cb, 0, nullptr, data, 0, 0);
    };
    // Calibrate: each dispatch ~60 ms, far below the 2 s driver timeout.
    set_iters(64);
    for (int round = 0; round < 6; round++) {
      const double t0 = Now();
      ctx->Dispatch(kCount / 256, 1, 1);
      wait();
      const double t = std::max(Now() - t0, 1e-4);
      const UINT next = static_cast<UINT>(std::clamp(iters * 0.06 / t, 32.0, 16384.0));
      if (round > 0 && next > iters * 0.8 && next < iters * 1.25) break;
      set_iters(next);
    }
    auto checked_run = [&](std::vector<float>& out) {
      ctx->UpdateSubresource(buf, 0, nullptr, init.data(), 0, 0);
      ctx->Dispatch(kCount / 256, 1, 1);
      ctx->CopyResource(staging, buf);
      D3D11_MAPPED_SUBRESOURCE m;
      if (FAILED(ctx->Map(staging, 0, D3D11_MAP_READ, 0, &m))) {
        out.clear();
        return;
      }
      out.assign(static_cast<float*>(m.pData), static_cast<float*>(m.pData) + kCount);
      ctx->Unmap(staging, 0);
    };
    std::vector<float> reference, check;
    checked_run(reference);
    if (reference.size() != kCount) return fail("Falha ao ler o resultado da GPU");

    const double flop = 2.0 * 8 * iters * kCount;
    const double start = Now();
    double last_check = start;
    uint64_t dispatches = 0, errors = 0, checks = 0;
    while (Now() - start < seconds && !cancel_) {
      for (int i = 0; i < 4; i++) ctx->Dispatch(kCount / 256, 1, 1);
      wait();
      dispatches += 4;
      if (Now() - last_check >= 3) {
        checked_run(check);
        checks++;
        if (check.size() != kCount) {
          errors++;
        } else {
          for (UINT i = 0; i < kCount; i++) {
            if (memcmp(&check[i], &reference[i], 4) != 0) errors++;
          }
        }
        last_check = Now();
      }
      const double t = Now() - start;
      Update(index, [&](Step& st) {
        st.gpu_tflops = dispatches * flop / t / 1e12;
        st.gpu_checks = checks;
        st.gpu_errors = errors;
      });
    }
    SafeRelease(done);
    SafeRelease(uav);
    SafeRelease(cb);
    SafeRelease(staging);
    SafeRelease(buf);
    SafeRelease(cs);
    SafeRelease(err);
    SafeRelease(code);
    SafeRelease(ctx);
    SafeRelease(dev);
    SafeRelease(best);
    SafeRelease(factory);
    return true;
  }

  bool RunDisk(int index, size_t megabytes) {
    wchar_t dir[MAX_PATH];
    GetTempPathW(MAX_PATH, dir);
    const std::wstring path = std::wstring(dir) + L"openchroma_checkup.tmp";
    ULARGE_INTEGER free{};
    GetDiskFreeSpaceExW(dir, &free, nullptr, nullptr);
    if (free.QuadPart < (megabytes + 2048) * 1024ull * 1024) {
      Update(index, [](Step& st) { st.error = "Pouco espaço livre para o teste"; });
      return false;
    }
    constexpr DWORD kChunk = 4 << 20;
    auto* block = static_cast<uint64_t*>(
        VirtualAlloc(nullptr, kChunk, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE));
    if (!block) return false;
    const size_t chunks = std::max<size_t>(megabytes, 64) / 4;
    auto fill = [&](size_t c) {
      for (size_t i = 0; i < kChunk / 8; i++) block[i] = Pattern(c * (kChunk / 8) + i, 77);
    };
    bool ok = true;
    // No OS cache: the numbers are the drive's, and the read really comes
    // back from it.
    HANDLE f = CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                           FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_NO_BUFFERING |
                               FILE_FLAG_WRITE_THROUGH | FILE_FLAG_DELETE_ON_CLOSE,
                           nullptr);
    if (f == INVALID_HANDLE_VALUE) {
      VirtualFree(block, 0, MEM_RELEASE);
      Update(index, [](Step& st) { st.error = "Não foi possível criar o arquivo de teste"; });
      return false;
    }
    double t0 = Now(), fill_time = 0;
    for (size_t c = 0; c < chunks && !cancel_ && ok; c++) {
      const double f0 = Now();
      fill(c);
      fill_time += Now() - f0;
      DWORD n = 0;
      ok = WriteFile(f, block, kChunk, &n, nullptr) && n == kChunk;
      if (c % 16 == 0) {
        const double mb = (c + 1) * 4.0;
        Update(index, [&](Step& st) { st.disk_write = mb / std::max(Now() - t0 - fill_time, 1e-3); });
      }
    }
    const double write_time = Now() - t0 - fill_time;
    if (ok && !cancel_) {
      Update(index, [&](Step& st) { st.disk_write = chunks * 4.0 / std::max(write_time, 1e-3); });
      LARGE_INTEGER zero{};
      SetFilePointerEx(f, zero, nullptr, FILE_BEGIN);
      uint64_t errors = 0;
      double read_time = 0;
      for (size_t c = 0; c < chunks && !cancel_ && ok; c++) {
        const double r0 = Now();
        DWORD n = 0;
        ok = ReadFile(f, block, kChunk, &n, nullptr) && n == kChunk;
        read_time += Now() - r0;
        for (size_t i = 0; i < kChunk / 8; i++) {
          if (block[i] != Pattern(c * (kChunk / 8) + i, 77)) errors++;
        }
        if (c % 16 == 0) {
          const double mb = (c + 1) * 4.0;
          Update(index, [&](Step& st) {
            st.disk_read = mb / std::max(read_time, 1e-3);
            st.errors = errors;
          });
        }
      }
      Update(index, [&](Step& st) {
        if (read_time > 0) st.disk_read = chunks * 4.0 / read_time;
        st.errors = errors;
      });
    }
    CloseHandle(f);
    VirtualFree(block, 0, MEM_RELEASE);
    if (!ok) Update(index, [](Step& st) { st.error = "Erro de leitura ou escrita no disco"; });
    return ok;
  }

  std::mutex mutex_;
  std::thread thread_;
  std::vector<Step> steps_;
  int current_ = -1;
  bool running_ = false;
  double step_start_ = 0;
  std::atomic<bool> cancel_{false};
};

Runner& Instance() {
  static Runner* r = new Runner();  // Outlives the worker thread.
  return *r;
}

// "cpu:30:1,cpu:90:0,memory:45:4096,gpu:60,cpugpu:60:0,disk:0:1024"
// = kind:seconds[:threads or megabytes]
std::vector<Step> ParsePlan(const char* plan) {
  std::vector<Step> steps;
  std::string s(plan ? plan : "");
  size_t pos = 0;
  while (pos < s.size()) {
    size_t end = s.find(',', pos);
    if (end == std::string::npos) end = s.size();
    const std::string item = s.substr(pos, end - pos);
    pos = end + 1;
    std::vector<std::string> parts;
    for (size_t p = 0, q; p <= item.size(); p = q + 1) {
      q = item.find(':', p);
      if (q == std::string::npos) q = item.size();
      parts.push_back(item.substr(p, q - p));
    }
    if (parts.empty() || parts[0].empty()) continue;
    Step st;
    st.id = parts[0];
    const double secs = parts.size() > 1 ? atof(parts[1].c_str()) : 30;
    const long long extra = parts.size() > 2 ? atoll(parts[2].c_str()) : 0;
    st.seconds = std::clamp(secs, 1.0, 3600.0);
    if (st.id == "cpu1" || st.id == "cpu") {
      st.kind = Kind::kCpu;
      st.threads = static_cast<int>(extra);
    } else if (st.id == "memory") {
      st.kind = Kind::kMemory;
      st.megabytes = static_cast<size_t>(std::max(64LL, extra));
    } else if (st.id == "gpu") {
      st.kind = Kind::kGpu;
    } else if (st.id == "cpugpu") {
      st.kind = Kind::kCpuGpu;
      st.threads = static_cast<int>(extra);
    } else if (st.id == "disk") {
      st.kind = Kind::kDisk;
      st.megabytes = static_cast<size_t>(std::max(64LL, extra));
    } else {
      continue;
    }
    steps.push_back(st);
  }
  return steps;
}

// ---------------------------------------------------------------- SMBIOS

std::string SmbiosString(const BYTE* s, const BYTE* end, BYTE index) {
  if (index == 0) return {};
  const char* p = reinterpret_cast<const char*>(s);
  for (BYTE i = 1; p < reinterpret_cast<const char*>(end) && *p; i++) {
    const size_t n = strnlen(p, reinterpret_cast<const char*>(end) - p);
    if (i == index) {
      std::string v(p, n);
      while (!v.empty() && v.back() == ' ') v.pop_back();
      return v;
    }
    p += n + 1;
  }
  return {};
}

std::string SystemInfo() {
  Json j;
  j.Obj();
  const UINT size = GetSystemFirmwareTable('RSMB', 0, nullptr, 0);
  std::vector<BYTE> buf(size);
  if (!size || GetSystemFirmwareTable('RSMB', 0, buf.data(), size) != size || size < 8) {
    j.Key("available").Bool(false);
    j.EndObj();
    return j.str;
  }
  j.Key("available").Bool(true);
  const DWORD length = *reinterpret_cast<DWORD*>(buf.data() + 4);
  const BYTE* p = buf.data() + 8;
  const BYTE* end = p + std::min<size_t>(length, size - 8);
  std::string board_maker, board, bios_vendor, bios_version, bios_date;
  int slots = 0;
  Json modules;
  modules.Arr();
  while (p + 4 <= end) {
    const BYTE type = p[0], len = p[1];
    if (len < 4 || p + len > end) break;
    const BYTE* strings = p + len;
    const BYTE* next = strings;
    while (next + 1 < end && !(next[0] == 0 && next[1] == 0)) next++;
    next += 2;
    auto str = [&](BYTE off) { return off < len ? SmbiosString(strings, end, p[off]) : std::string(); };
    auto word = [&](BYTE off) { return off + 1 < len ? *reinterpret_cast<const WORD*>(p + off) : WORD(0); };
    auto dword = [&](BYTE off) { return off + 3 < len ? *reinterpret_cast<const DWORD*>(p + off) : DWORD(0); };
    if (type == 0) {
      bios_vendor = str(0x04);
      bios_version = str(0x05);
      bios_date = str(0x08);
    } else if (type == 2) {
      board_maker = str(0x04);
      board = str(0x05);
    } else if (type == 16) {
      slots += word(0x0D);
    } else if (type == 17) {
      DWORD mb = word(0x0C);
      if (mb == 0x7FFF) {
        mb = dword(0x1C);
      } else if (mb & 0x8000) {
        mb = (mb & 0x7FFF) / 1024;  // in KB
      }
      if (mb != 0 && mb != 0xFFFF) {
        DWORD speed = word(0x15), configured = word(0x20);
        if (speed == 0xFFFF) speed = dword(0x54);
        if (configured == 0xFFFF) configured = dword(0x58);
        const BYTE kind = len > 0x12 ? p[0x12] : 0;
        modules.Obj();
        modules.Key("slot").Str(str(0x10));
        modules.Key("bank").Str(str(0x11));
        modules.Key("type").Str(kind == 0x22 ? "DDR5" : kind == 0x1A ? "DDR4" : kind == 0x18 ? "DDR3"
                                : kind == 0x23 ? "LPDDR5" : kind == 0x1E ? "LPDDR4" : "");
        modules.Key("megabytes").Int(mb);
        modules.Key("speed").Int(speed);
        modules.Key("configured").Int(configured);
        modules.Key("maker").Str(str(0x17));
        modules.Key("part").Str(str(0x1A));
        modules.EndObj();
      }
    } else if (type == 127) {
      break;
    }
    p = next;
  }
  modules.EndArr();
  j.Key("boardMaker").Str(board_maker);
  j.Key("board").Str(board);
  j.Key("biosVendor").Str(bios_vendor);
  j.Key("biosVersion").Str(bios_version);
  j.Key("biosDate").Str(bios_date);
  j.Key("slots").Int(slots);
  j.Key("avx2").Bool(HasAvx2Fma());
  j.str += ",\"modules\":" + modules.str;
  j.EndObj();
  return j.str;
}

int Copy(const std::string& s, char* buf, int cap) {
  const int n = static_cast<int>(s.size());
  if (buf && cap > n) {
    memcpy(buf, s.data(), n);
    buf[n] = '\0';
  }
  return n;
}

}  // namespace

extern "C" {

// Starts the tests in [plan] (see ParsePlan); false while others still run.
__declspec(dllexport) int OcDiagStart(const char* plan) {
  return Instance().Start(ParsePlan(plan)) ? 1 : 0;
}

__declspec(dllexport) void OcDiagCancel() { Instance().Cancel(); }

// Progress and results as JSON; returns the length (copies when it fits).
__declspec(dllexport) int OcDiagRead(char* buf, int cap) {
  return Copy(Instance().State(), buf, cap);
}

// Memory modules, board and BIOS from SMBIOS, as JSON.
__declspec(dllexport) int OcDiagSystemInfo(char* buf, int cap) {
  return Copy(SystemInfo(), buf, cap);
}

}  // extern "C"
