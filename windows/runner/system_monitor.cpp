// Hardware monitor: CPU, GPU, memory, storage, network and process usage
// plus temperatures. A background thread samples once per second and keeps
// the latest snapshot as JSON, read from Dart through the C functions at the
// bottom (looked up with DynamicLibrary.executable()).
//
// Sources, all usable without admin rights unless noted:
// - PDH counters (English names, so they work on any Windows language) for
//   CPU, GPU engine, disk and network activity, as Task Manager shows them.
// - NVML (nvml.dll, shipped with the NVIDIA driver) for NVIDIA GPUs.
// - D3DKMT adapter perf data for the temperature/fan of other GPUs.
// - IOCTL_STORAGE_QUERY_PROPERTY for SSD/HDD temperatures.
// - The PawnIO driver for CPU temperature and package power. Opening it
//   needs an elevated process; the module blobs ship in assets/pawnio.
#include <windows.h>
#include <dxgi.h>
#include <intrin.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <psapi.h>
#include <winioctl.h>
#include <nvme.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <map>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "json_writer.h"
#include "pawnio.h"

namespace {

using oc::IsElevated;
using oc::Json;
using oc::Utf8;
using oc::PawnIo;

std::string Trim(std::string s) {
  const auto b = s.find_first_not_of(" \t\r\n");
  const auto e = s.find_last_not_of(" \t\r\n");
  return b == std::string::npos ? std::string() : s.substr(b, e - b + 1);
}

// ---------------------------------------------------------------- PDH

// One wildcard counter read as an array of (instance, value).
class PdhArray {
 public:
  bool Add(PDH_HQUERY q, const wchar_t* path) {
    return PdhAddEnglishCounterW(q, path, 0, &counter_) == ERROR_SUCCESS;
  }

  std::vector<std::pair<std::wstring, double>> Read() const {
    std::vector<std::pair<std::wstring, double>> out;
    if (!counter_) return out;
    DWORD size = 0, count = 0;
    PDH_STATUS s = PdhGetFormattedCounterArrayW(
        counter_, PDH_FMT_DOUBLE | PDH_FMT_NOCAP100, &size, &count, nullptr);
    if (s != PDH_MORE_DATA) return out;
    std::vector<BYTE> buf(size);
    auto* items = reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buf.data());
    s = PdhGetFormattedCounterArrayW(counter_, PDH_FMT_DOUBLE | PDH_FMT_NOCAP100,
                                     &size, &count, items);
    if (s != ERROR_SUCCESS) return out;
    out.reserve(count);
    for (DWORD i = 0; i < count; i++) {
      if (items[i].FmtValue.CStatus == PDH_CSTATUS_VALID_DATA ||
          items[i].FmtValue.CStatus == PDH_CSTATUS_NEW_DATA) {
        out.emplace_back(items[i].szName, items[i].FmtValue.doubleValue);
      }
    }
    return out;
  }

  double Single() const {
    const auto v = Read();
    return v.empty() ? -1 : v[0].second;
  }

 private:
  PDH_HCOUNTER counter_ = nullptr;
};

// CPU package temperature, CCD temperatures and package power.
class CpuSensors {
 public:
  CpuSensors() {
    int r[4];
    __cpuid(r, 0);
    char vendor[13] = {};
    memcpy(vendor, &r[1], 4);
    memcpy(vendor + 4, &r[3], 4);
    memcpy(vendor + 8, &r[2], 4);
    amd_ = strcmp(vendor, "AuthenticAMD") == 0;
    intel_ = strcmp(vendor, "GenuineIntel") == 0;
    __cpuid(r, 1);
    const int base_family = (r[0] >> 8) & 0xF;
    family_ = base_family == 0xF ? base_family + ((r[0] >> 20) & 0xFF)
                                 : base_family;
    model_ = ((r[0] >> 4) & 0xF) | (base_family >= 0x6 ? ((r[0] >> 12) & 0xF0) : 0);
  }

  // "ok", "needs_admin", "no_driver" or "unsupported".
  const char* status() const { return status_; }
  double package = -1;
  double power = -1;
  std::vector<double> ccds;

  void Sample() {
    package = power = -1;
    ccds.clear();
    if (!Ready()) return;
    if (amd_) SampleAmd();
    if (intel_) SampleIntel();
  }

 private:
  bool Ready() {
    if (tried_) return opened_;
    tried_ = true;
    if (!(amd_ && family_ >= 0x17) && !intel_) {
      status_ = "unsupported";
      return false;
    }
    if (!IsElevated()) {
      status_ = "needs_admin";
      return false;
    }
    opened_ = io_.Open(amd_ ? L"AMDFamily17.bin" : L"IntelMSR.bin");
    status_ = opened_ ? "ok" : "no_driver";
    if (opened_ && amd_) {
      pci_mutex_ = CreateMutexW(nullptr, FALSE, L"Global\\Access_PCI");
    }
    return opened_;
  }

  bool Msr(ULONG64 msr, ULONG64& value) {
    return io_.Execute("ioctl_read_msr", &msr, 1, &value, 1);
  }

  bool Smn(ULONG64 offset, ULONG64& value) {
    // Other monitoring tools (LibreHardwareMonitor, FanControl, HWiNFO)
    // share the SMN index/data registers through this mutex.
    if (pci_mutex_ && WaitForSingleObject(pci_mutex_, 10) == WAIT_TIMEOUT) {
      return false;
    }
    const bool ok = io_.Execute("ioctl_read_smn", &offset, 1, &value, 1);
    if (pci_mutex_) ReleaseMutex(pci_mutex_);
    return ok;
  }

  void SampleAmd() {
    ULONG64 v = 0;
    if (Smn(0x00059800, v)) {
      double t = ((v >> 21) & 0x7FF) * 0.125;
      if (v & 0x80000) t -= 49;
      if (t > 0 && t < 150) package = t;
    }
    // Per-CCD temperatures (Zen 2 / Zen 3 desktop at 0x59954, Zen 4 / 5 at 0x59b08).
    ULONG64 ccd_base = 0;
    if ((family_ == 0x17 && (model_ == 0x31 || model_ == 0x71)) ||
        (family_ == 0x19 && model_ <= 0x2F)) {
      ccd_base = 0x00059954;
    } else if ((family_ == 0x19 && model_ >= 0x60) || family_ == 0x1A) {
      ccd_base = 0x00059b08;
    }
    if (ccd_base) {
      for (int i = 0; i < 8; i++) {
        if (!Smn(ccd_base + i * 4, v)) break;
        if ((v & 0xFFF) == 0) continue;
        const double t = ((v & 0xFFF) * 125 - 305000) / 1000.0;
        if (t > 0 && t < 150) ccds.push_back(t);
      }
    }
    // Package power from the RAPL energy counter.
    ULONG64 unit = 0, energy = 0;
    if (Msr(0xC0010299, unit) && Msr(0xC001029B, energy)) {
      Power(energy, unit);
    }
  }

  void SampleIntel() {
    ULONG64 target = 0, therm = 0;
    if (Msr(0x1A2, target) && Msr(0x1B1, therm) && (therm & 0x80000000)) {
      const double tjmax = static_cast<double>((target >> 16) & 0xFF);
      const double t = tjmax - static_cast<double>((therm >> 16) & 0x7F);
      if (tjmax > 0 && t > 0 && t < 150) package = t;
    }
    ULONG64 unit = 0, energy = 0;
    if (Msr(0x606, unit) && Msr(0x611, energy)) {
      Power(energy, unit);
    }
  }

  // [energy] is a 32-bit wrapping counter in units of 1 / 2^ESU joules,
  // with ESU in bits 12:8 of [unit].
  void Power(ULONG64 energy, ULONG64 unit) {
    const ULONGLONG now = GetTickCount64();
    const auto raw = static_cast<uint32_t>(energy);
    if (last_tick_ && now > last_tick_) {
      const uint32_t delta = raw - last_energy_;
      const double joules =
          delta / static_cast<double>(1ull << ((unit >> 8) & 0x1F));
      const double w = joules / ((now - last_tick_) / 1000.0);
      if (w >= 0 && w < 1000) power = w;
    }
    last_tick_ = now;
    last_energy_ = raw;
  }

  bool amd_ = false, intel_ = false;
  int family_ = 0, model_ = 0;
  bool tried_ = false, opened_ = false;
  const char* status_ = "needs_admin";
  PawnIo io_;
  HANDLE pci_mutex_ = nullptr;
  ULONGLONG last_tick_ = 0;
  uint32_t last_energy_ = 0;
};

// ---------------------------------------------------------------- GPU

struct D3dkmtOpenAdapterFromLuid {
  LUID AdapterLuid;
  UINT hAdapter;
};
struct D3dkmtQueryAdapterInfo {
  UINT hAdapter;
  UINT Type;
  void* pPrivateDriverData;
  UINT PrivateDriverDataSize;
};
struct D3dkmtCloseAdapter {
  UINT hAdapter;
};
struct D3dkmtAdapterPerfData {
  UINT32 PhysicalAdapterIndex;
  ULONGLONG MemoryFrequency;
  ULONGLONG MaxMemoryFrequency;
  ULONGLONG MaxMemoryFrequencyOC;
  ULONGLONG MemoryBandwidth;
  ULONGLONG PCIEBandwidth;
  ULONG FanRPM;
  ULONG Power;
  ULONG Temperature;
  UCHAR PowerStateOverride;
};
constexpr UINT kKmtQaiAdapterPerfData = 62;

// The subset of NVML used here.
class Nvml {
 public:
  struct Reading {
    double temp = -1, util = -1, mem_used = -1, mem_total = -1, power = -1,
           power_limit = -1, fan = -1, clock = -1, mem_clock = -1;
  };

  Nvml() {
    lib_ = LoadLibraryW(L"nvml.dll");
    if (!lib_) {
      wchar_t pf[MAX_PATH];
      if (GetEnvironmentVariableW(L"ProgramW6432", pf, MAX_PATH)) {
        lib_ = LoadLibraryW(
            (std::wstring(pf) + L"\\NVIDIA Corporation\\NVSMI\\nvml.dll").c_str());
      }
    }
    if (!lib_) return;
    auto init = Fn<int (*)()>("nvmlInit_v2");
    count_ = Fn<int (*)(unsigned*)>("nvmlDeviceGetCount_v2");
    handle_ = Fn<int (*)(unsigned, void**)>("nvmlDeviceGetHandleByIndex_v2");
    name_ = Fn<int (*)(void*, char*, unsigned)>("nvmlDeviceGetName");
    temp_ = Fn<int (*)(void*, int, unsigned*)>("nvmlDeviceGetTemperature");
    util_ = Fn<int (*)(void*, unsigned*)>("nvmlDeviceGetUtilizationRates");
    mem_ = Fn<int (*)(void*, unsigned long long*)>("nvmlDeviceGetMemoryInfo");
    power_ = Fn<int (*)(void*, unsigned*)>("nvmlDeviceGetPowerUsage");
    limit_ = Fn<int (*)(void*, unsigned*)>("nvmlDeviceGetEnforcedPowerLimit");
    fan_ = Fn<int (*)(void*, unsigned*)>("nvmlDeviceGetFanSpeed");
    clock_ = Fn<int (*)(void*, int, unsigned*)>("nvmlDeviceGetClockInfo");
    ok_ = init && count_ && handle_ && name_ && init() == 0;
  }

  // NVIDIA devices by name.
  std::map<std::string, void*> Devices() {
    std::map<std::string, void*> out;
    unsigned n = 0;
    if (!ok_ || count_(&n) != 0) return out;
    for (unsigned i = 0; i < n; i++) {
      void* d = nullptr;
      char name[96] = {};
      if (handle_(i, &d) == 0 && name_(d, name, sizeof(name)) == 0) {
        out[name] = d;
      }
    }
    return out;
  }

  Reading Read(void* d) {
    Reading r;
    unsigned v = 0;
    if (temp_ && temp_(d, 0, &v) == 0) r.temp = v;
    unsigned util[2] = {};
    if (util_ && util_(d, util) == 0) r.util = util[0];
    unsigned long long mem[3] = {};  // total, free, used
    if (mem_ && mem_(d, mem) == 0) {
      r.mem_total = static_cast<double>(mem[0]);
      r.mem_used = static_cast<double>(mem[2]);
    }
    if (power_ && power_(d, &v) == 0) r.power = v / 1000.0;
    if (limit_ && limit_(d, &v) == 0) r.power_limit = v / 1000.0;
    if (fan_ && fan_(d, &v) == 0) r.fan = v;
    if (clock_ && clock_(d, 0, &v) == 0) r.clock = v;
    if (clock_ && clock_(d, 2, &v) == 0) r.mem_clock = v;
    return r;
  }

 private:
  template <typename T>
  T Fn(const char* name) {
    return reinterpret_cast<T>(GetProcAddress(lib_, name));
  }

  HMODULE lib_ = nullptr;
  bool ok_ = false;
  int (*count_)(unsigned*) = nullptr;
  int (*handle_)(unsigned, void**) = nullptr;
  int (*name_)(void*, char*, unsigned) = nullptr;
  int (*temp_)(void*, int, unsigned*) = nullptr;
  int (*util_)(void*, unsigned*) = nullptr;
  int (*mem_)(void*, unsigned long long*) = nullptr;
  int (*power_)(void*, unsigned*) = nullptr;
  int (*limit_)(void*, unsigned*) = nullptr;
  int (*fan_)(void*, unsigned*) = nullptr;
  int (*clock_)(void*, int, unsigned*) = nullptr;
};

struct GpuAdapter {
  std::string name;
  LUID luid{};
  UINT vendor = 0;
  double dedicated = 0;  // bytes
  void* nvml = nullptr;
};

std::string LuidKey(LUID l) {
  char buf[48];
  snprintf(buf, sizeof(buf), "luid_0x%08lX_0x%08lX",
           static_cast<unsigned long>(l.HighPart), l.LowPart);
  return buf;
}

std::string LowerAscii(std::string s) {
  for (auto& c : s) c = static_cast<char>(tolower(static_cast<unsigned char>(c)));
  return s;
}

// ---------------------------------------------------------------- Disks

struct PhysicalDisk {
  int number = -1;
  std::string model;
  std::string bus;
  double temp = -1;
};

const char* BusName(STORAGE_BUS_TYPE t) {
  switch (t) {
    case BusTypeNvme: return "NVMe";
    case BusTypeSata: return "SATA";
    case BusTypeUsb: return "USB";
    case BusTypeSas: return "SAS";
    case BusTypeAta: return "ATA";
    case BusTypeRAID: return "RAID";
    case BusTypeSd: return "SD";
    default: return "";
  }
}

PhysicalDisk QueryDisk(int number, bool with_identity) {
  PhysicalDisk d;
  d.number = number;
  wchar_t path[40];
  swprintf(path, 40, L"\\\\.\\PhysicalDrive%d", number);
  HANDLE h = CreateFileW(path, 0, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                         OPEN_EXISTING, 0, nullptr);
  if (h == INVALID_HANDLE_VALUE) {
    d.number = -1;
    return d;
  }
  DWORD ret = 0;
  if (with_identity) {
    STORAGE_PROPERTY_QUERY q{StorageDeviceProperty, PropertyStandardQuery, {0}};
    std::vector<BYTE> buf(1024);
    if (DeviceIoControl(h, IOCTL_STORAGE_QUERY_PROPERTY, &q, sizeof(q),
                        buf.data(), static_cast<DWORD>(buf.size()), &ret,
                        nullptr)) {
      auto* desc = reinterpret_cast<STORAGE_DEVICE_DESCRIPTOR*>(buf.data());
      auto field = [&](DWORD off) {
        return off && off < ret ? Trim(reinterpret_cast<char*>(buf.data() + off))
                                : std::string();
      };
      const std::string vendor = field(desc->VendorIdOffset);
      const std::string product = field(desc->ProductIdOffset);
      d.model = vendor.empty() || product.rfind(vendor, 0) == 0
                    ? product
                    : vendor + " " + product;
      d.bus = BusName(desc->BusType);
    }
  }
  STORAGE_PROPERTY_QUERY tq{StorageDeviceTemperatureProperty,
                            PropertyStandardQuery,
                            {0}};
  alignas(8) BYTE tbuf[sizeof(STORAGE_TEMPERATURE_DATA_DESCRIPTOR) +
            8 * sizeof(STORAGE_TEMPERATURE_INFO)] = {};
  if (DeviceIoControl(h, IOCTL_STORAGE_QUERY_PROPERTY, &tq, sizeof(tq), tbuf,
                      sizeof(tbuf), &ret, nullptr)) {
    auto* t = reinterpret_cast<STORAGE_TEMPERATURE_DATA_DESCRIPTOR*>(tbuf);
    if (t->InfoCount > 0) {
      const SHORT c = t->TemperatureInfo[0].Temperature;
      if (c > -40 && c < 150) d.temp = c;
    }
  }
  if (d.temp < 0) {
    // Many NVMe drivers only answer through the SMART / health log page.
    constexpr DWORD kLog = 512;
    constexpr DWORD kSize = FIELD_OFFSET(STORAGE_PROPERTY_QUERY, AdditionalParameters) +
                            sizeof(STORAGE_PROTOCOL_SPECIFIC_DATA) + kLog;
    alignas(8) BYTE buf[kSize] = {};
    auto* q = reinterpret_cast<STORAGE_PROPERTY_QUERY*>(buf);
    q->PropertyId = StorageDeviceProtocolSpecificProperty;
    q->QueryType = PropertyStandardQuery;
    auto* p = reinterpret_cast<STORAGE_PROTOCOL_SPECIFIC_DATA*>(q->AdditionalParameters);
    p->ProtocolType = ProtocolTypeNvme;
    p->DataType = NVMeDataTypeLogPage;
    p->ProtocolDataRequestValue = NVME_LOG_PAGE_HEALTH_INFO;
    p->ProtocolDataOffset = sizeof(STORAGE_PROTOCOL_SPECIFIC_DATA);
    p->ProtocolDataLength = kLog;
    if (DeviceIoControl(h, IOCTL_STORAGE_QUERY_PROPERTY, buf, kSize, buf, kSize,
                        &ret, nullptr)) {
      auto* desc = reinterpret_cast<STORAGE_PROTOCOL_DATA_DESCRIPTOR*>(buf);
      const auto& data = desc->ProtocolSpecificData;
      if (data.ProtocolDataOffset + 3 <= kLog + sizeof(STORAGE_PROTOCOL_SPECIFIC_DATA)) {
        const BYTE* log = reinterpret_cast<const BYTE*>(&data) + data.ProtocolDataOffset;
        const int kelvin = log[1] | (log[2] << 8);  // Composite temperature.
        if (kelvin > 233 && kelvin < 423) d.temp = kelvin - 273;
      }
    }
  }
  CloseHandle(h);
  return d;
}

// ---------------------------------------------------------------- Processes

// SYSTEM_PROCESS_INFORMATION as returned by NtQuerySystemInformation(5);
// winternl.h hides most of these fields.
struct ProcInfo {
  ULONG NextEntryOffset;
  ULONG NumberOfThreads;
  LARGE_INTEGER WorkingSetPrivateSize;
  ULONG HardFaultCount;
  ULONG NumberOfThreadsHighWatermark;
  ULONGLONG CycleTime;
  LARGE_INTEGER CreateTime;
  LARGE_INTEGER UserTime;
  LARGE_INTEGER KernelTime;
  USHORT NameLength;
  USHORT NameMaximumLength;
  PWSTR NameBuffer;
  LONG BasePriority;
  HANDLE UniqueProcessId;
};

using NtQuerySystemInformationFn = LONG(WINAPI*)(ULONG, PVOID, ULONG, PULONG);

struct ProcGroup {
  std::string name;
  int count = 0;
  double cpu = 0;     // percent of the whole CPU
  double memory = 0;  // private working set, bytes
};

// ---------------------------------------------------------------- Sampler

class Monitor {
 public:
  void Start() {
    std::lock_guard<std::mutex> lock(control_);
    if (users_++ > 0) return;
    running_ = true;
    thread_ = std::thread([this] { Run(); });
    // The CPU sensor goes through a kernel driver; it gets its own thread,
    // never joined, so a driver that stops answering cannot stall the other
    // readings or a Stop() on the UI thread.
    if (!sensor_thread_started_) {
      sensor_thread_started_ = true;
      sensor_started_at_ = GetTickCount64();
      std::thread([this] { RunCpuSensor(); }).detach();
    }
  }

  void Stop() {
    std::lock_guard<std::mutex> lock(control_);
    if (users_ == 0 || --users_ > 0) return;
    running_ = false;
    if (thread_.joinable()) thread_.join();
  }

  int Read(char* buf, int cap) {
    std::lock_guard<std::mutex> lock(snapshot_mutex_);
    const int n = static_cast<int>(snapshot_.size());
    if (buf && cap > n) {
      memcpy(buf, snapshot_.data(), n);
      buf[n] = '\0';
    }
    return n;
  }

 private:
  void RunCpuSensor() {
    for (;;) {
      if (running_) {
        cpu_sensors_.Sample();
        std::lock_guard<std::mutex> lock(sensor_mutex_);
        sensor_status_ = cpu_sensors_.status();
        sensor_temp_ = cpu_sensors_.package;
        sensor_power_ = cpu_sensors_.power;
        sensor_ccds_ = cpu_sensors_.ccds;
        sensor_updated_ = GetTickCount64();
      }
      Sleep(1000);
    }
  }

  void Run() {
    Init();
    while (running_) {
      const ULONGLONG start = GetTickCount64();
      Json j = Sample();
      {
        std::lock_guard<std::mutex> lock(snapshot_mutex_);
        snapshot_ = std::move(j.str);
      }
      while (running_ && GetTickCount64() - start < 1000) Sleep(50);
    }
    if (query_) PdhCloseQuery(query_);
    query_ = nullptr;
  }

  void Init() {
    if (inited_) {
      // Restarted after a stop: only PDH needs reopening.
      OpenPdh();
      return;
    }
    inited_ = true;
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    threads_ = static_cast<int>(si.dwNumberOfProcessors);
    cpu_name_ = ReadCpuName();
    cores_ = CountCores();
    nt_query_ = reinterpret_cast<NtQuerySystemInformationFn>(
        GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "NtQuerySystemInformation"));
    HMODULE gdi = GetModuleHandleW(L"gdi32.dll");
    if (!gdi) gdi = LoadLibraryW(L"gdi32.dll");
    kmt_open_ = reinterpret_cast<LONG(WINAPI*)(D3dkmtOpenAdapterFromLuid*)>(
        GetProcAddress(gdi, "D3DKMTOpenAdapterFromLuid"));
    kmt_query_ = reinterpret_cast<LONG(WINAPI*)(D3dkmtQueryAdapterInfo*)>(
        GetProcAddress(gdi, "D3DKMTQueryAdapterInfo"));
    kmt_close_ = reinterpret_cast<LONG(WINAPI*)(D3dkmtCloseAdapter*)>(
        GetProcAddress(gdi, "D3DKMTCloseAdapter"));
    EnumerateGpus();
    EnumerateDisks();
    OpenPdh();
  }

  void OpenPdh() {
    if (PdhOpenQueryW(nullptr, 0, &query_) != ERROR_SUCCESS) return;
    cpu_total_.Add(query_, L"\\Processor Information(_Total)\\% Processor Utility");
    cpu_cores_.Add(query_, L"\\Processor Information(*)\\% Processor Utility");
    cpu_perf_.Add(query_, L"\\Processor Information(_Total)\\% Processor Performance");
    cpu_freq_.Add(query_, L"\\Processor Information(_Total)\\Processor Frequency");
    gpu_engine_.Add(query_, L"\\GPU Engine(*)\\Utilization Percentage");
    gpu_dedicated_.Add(query_, L"\\GPU Adapter Memory(*)\\Dedicated Usage");
    disk_idle_.Add(query_, L"\\PhysicalDisk(*)\\% Idle Time");
    disk_read_.Add(query_, L"\\PhysicalDisk(*)\\Disk Read Bytes/sec");
    disk_write_.Add(query_, L"\\PhysicalDisk(*)\\Disk Write Bytes/sec");
    net_down_.Add(query_, L"\\Network Interface(*)\\Bytes Received/sec");
    net_up_.Add(query_, L"\\Network Interface(*)\\Bytes Sent/sec");
    PdhCollectQueryData(query_);
  }

  static std::string ReadCpuName() {
    wchar_t buf[128] = {};
    DWORD size = sizeof(buf);
    RegGetValueW(HKEY_LOCAL_MACHINE,
                 L"HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0",
                 L"ProcessorNameString", RRF_RT_REG_SZ, nullptr, buf, &size);
    return Trim(Utf8(buf));
  }

  static int CountCores() {
    DWORD len = 0;
    GetLogicalProcessorInformationEx(RelationProcessorCore, nullptr, &len);
    std::vector<BYTE> buf(len);
    if (!GetLogicalProcessorInformationEx(
            RelationProcessorCore,
            reinterpret_cast<SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX*>(buf.data()),
            &len)) {
      return 0;
    }
    int n = 0;
    for (DWORD off = 0; off < len;) {
      auto* p = reinterpret_cast<SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX*>(
          buf.data() + off);
      n++;
      off += p->Size;
    }
    return n;
  }

  void EnumerateGpus() {
    IDXGIFactory1* factory = nullptr;
    if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1),
                                  reinterpret_cast<void**>(&factory)))) {
      return;
    }
    auto nv = nvml_.Devices();
    IDXGIAdapter1* a = nullptr;
    for (UINT i = 0; factory->EnumAdapters1(i, &a) != DXGI_ERROR_NOT_FOUND; i++) {
      DXGI_ADAPTER_DESC1 d;
      if (SUCCEEDED(a->GetDesc1(&d)) && !(d.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) &&
          d.VendorId != 0x1414) {
        bool dup = false;
        for (auto& g : gpus_) {
          dup |= g.luid.LowPart == d.AdapterLuid.LowPart &&
                 g.luid.HighPart == d.AdapterLuid.HighPart;
        }
        if (!dup) {
          GpuAdapter g;
          g.name = Trim(Utf8(d.Description));
          g.luid = d.AdapterLuid;
          g.vendor = d.VendorId;
          g.dedicated = static_cast<double>(d.DedicatedVideoMemory);
          auto it = nv.find(g.name);
          if (it == nv.end() && g.vendor == 0x10DE && nv.size() == 1) {
            it = nv.begin();
          }
          if (it != nv.end()) g.nvml = it->second;
          gpus_.push_back(g);
        }
      }
      a->Release();
    }
    factory->Release();
    // Discrete GPUs first.
    std::stable_sort(gpus_.begin(), gpus_.end(), [](auto& x, auto& y) {
      return x.dedicated > y.dedicated;
    });
  }

  void EnumerateDisks() {
    for (int i = 0; i < 32; i++) {
      PhysicalDisk d = QueryDisk(i, true);
      if (d.number >= 0) disks_.push_back(d);
    }
  }

  double KmtTemperature(LUID luid, double& fan_rpm) {
    fan_rpm = -1;
    if (!kmt_open_ || !kmt_query_) return -1;
    D3dkmtOpenAdapterFromLuid open{luid, 0};
    if (kmt_open_(&open) != 0) return -1;
    D3dkmtAdapterPerfData perf{};
    D3dkmtQueryAdapterInfo q{open.hAdapter, kKmtQaiAdapterPerfData, &perf,
                             sizeof(perf)};
    double t = -1;
    if (kmt_query_(&q) == 0) {
      if (perf.Temperature > 0 && perf.Temperature < 1500) t = perf.Temperature / 10.0;
      if (perf.FanRPM > 0) fan_rpm = perf.FanRPM;
    }
    if (kmt_close_) {
      D3dkmtCloseAdapter c{open.hAdapter};
      kmt_close_(&c);
    }
    return t;
  }

  Json Sample() {
    if (query_) PdhCollectQueryData(query_);
    Json j;
    j.Obj();
    j.Key("time").Int(static_cast<long long>(GetTickCount64()));
    j.Key("uptime").Int(static_cast<long long>(GetTickCount64() / 1000));
    j.Key("elevated").Bool(IsElevated());
    WriteCpu(j);
    WriteMemory(j);
    WriteGpus(j);
    WriteStorage(j);
    WriteNetwork(j);
    WriteProcesses(j);
    j.EndObj();
    return j;
  }

  void WriteCpu(Json& j) {
    j.Key("cpu").Obj();
    j.Key("name").Str(cpu_name_);
    j.Key("cores").Int(cores_);
    j.Key("threads").Int(threads_);
    const double total = cpu_total_.Single();
    j.Key("usage").Opt(total < 0 ? -1 : std::min(100.0, total));
    const double perf = cpu_perf_.Single();
    const double freq = cpu_freq_.Single();
    j.Key("clock").Opt(perf > 0 && freq > 0 ? freq * perf / 100 : -1);
    j.Key("baseClock").Opt(freq);
    // "0,3" style instances; keep per-thread values in processor order.
    std::vector<std::pair<int, double>> per;
    for (auto& [name, v] : cpu_cores_.Read()) {
      if (name.find(L"_Total") != std::wstring::npos) continue;
      const auto comma = name.find(L',');
      const int group = _wtoi(name.substr(0, comma).c_str());
      const int idx = comma == std::wstring::npos ? 0 : _wtoi(name.c_str() + comma + 1);
      per.emplace_back(group * 64 + idx, std::min(100.0, v));
    }
    std::sort(per.begin(), per.end());
    j.Key("perThread").Arr();
    for (auto& p : per) j.Num(std::round(p.second * 10) / 10);
    j.EndArr();
    std::lock_guard<std::mutex> lock(sensor_mutex_);
    const ULONGLONG now = GetTickCount64();
    if (sensor_updated_ == 0 || now - sensor_updated_ > 5000) {
      // Still opening the driver, or it stopped answering.
      j.Key("sensor").Str(
          sensor_updated_ == 0 && now - sensor_started_at_ < 10000 ? "pending"
                                                                 : "failed");
      j.Key("temp").Opt(-1);
      j.Key("ccds").Arr().EndArr();
      j.Key("power").Opt(-1);
    } else {
      j.Key("sensor").Str(sensor_status_);
      j.Key("temp").Opt(sensor_temp_);
      j.Key("ccds").Arr();
      for (double t : sensor_ccds_) j.Num(t);
      j.EndArr();
      j.Key("power").Opt(sensor_power_);
    }
    j.EndObj();
  }

  void WriteMemory(Json& j) {
    MEMORYSTATUSEX m{sizeof(m)};
    GlobalMemoryStatusEx(&m);
    PERFORMANCE_INFORMATION pi{sizeof(pi)};
    GetPerformanceInfo(&pi, sizeof(pi));
    const double page = static_cast<double>(pi.PageSize);
    j.Key("memory").Obj();
    j.Key("total").Num(static_cast<double>(m.ullTotalPhys));
    j.Key("used").Num(static_cast<double>(m.ullTotalPhys - m.ullAvailPhys));
    j.Key("available").Num(static_cast<double>(m.ullAvailPhys));
    j.Key("committed").Num(pi.CommitTotal * page);
    j.Key("commitLimit").Num(pi.CommitLimit * page);
    j.Key("cached").Num(pi.SystemCache * page);
    j.EndObj();
  }

  void WriteGpus(Json& j) {
    // Task Manager's GPU %: per adapter, the busiest engine type, where each
    // engine type sums its per-process instances.
    std::map<std::string, std::map<std::wstring, double>> engines;
    for (auto& [name, v] : gpu_engine_.Read()) {
      const std::string n = Utf8(name);
      const auto l = n.find("luid_");
      const auto e = n.find("engtype_");
      if (l == std::string::npos || e == std::string::npos) continue;
      engines[LowerAscii(n.substr(l, 26))][name.substr(e)] += v;
    }
    std::map<std::string, double> dedicated;
    for (auto& [name, v] : gpu_dedicated_.Read()) {
      const std::string n = Utf8(name);
      const auto l = n.find("luid_");
      if (l != std::string::npos) dedicated[LowerAscii(n.substr(l, 26))] += v;
    }

    j.Key("gpus").Arr();
    for (auto& g : gpus_) {
      const std::string key = LowerAscii(LuidKey(g.luid));
      double util = -1;
      if (auto it = engines.find(key); it != engines.end()) {
        util = 0;
        for (auto& [_, v] : it->second) util = std::max(util, v);
        util = std::min(100.0, util);
      }
      double mem_used = -1;
      if (auto it = dedicated.find(key); it != dedicated.end()) mem_used = it->second;
      double mem_total = g.dedicated;
      double fan_rpm = -1;
      double temp = KmtTemperature(g.luid, fan_rpm);
      Nvml::Reading nv;
      if (g.nvml) {
        nv = nvml_.Read(g.nvml);
        if (nv.temp >= 0) temp = nv.temp;
        if (nv.util >= 0) util = nv.util;
        if (nv.mem_used >= 0) mem_used = nv.mem_used;
        if (nv.mem_total > 0) mem_total = nv.mem_total;
      }
      j.Obj();
      j.Key("name").Str(g.name);
      j.Key("vendor").Int(g.vendor);
      j.Key("integrated").Bool(g.dedicated < 1024.0 * 1024 * 1024 && g.vendor != 0x10DE);
      j.Key("usage").Opt(util);
      j.Key("temp").Opt(temp);
      j.Key("memUsed").Opt(mem_used);
      j.Key("memTotal").Opt(mem_total);
      j.Key("power").Opt(nv.power);
      j.Key("powerLimit").Opt(nv.power_limit);
      j.Key("fan").Opt(nv.fan);
      j.Key("fanRpm").Opt(fan_rpm);
      j.Key("clock").Opt(nv.clock);
      j.Key("memClock").Opt(nv.mem_clock);
      j.EndObj();
    }
    j.EndArr();
  }

  void WriteStorage(Json& j) {
    // Activity by disk number; PDH instances look like "0 C: D:".
    std::map<int, double> idle, rd, wr;
    auto collect = [](const PdhArray& c, std::map<int, double>& out) {
      for (auto& [name, v] : c.Read()) {
        if (name == L"_Total" || name.empty() || !iswdigit(name[0])) continue;
        out[_wtoi(name.c_str())] = v;
      }
    };
    collect(disk_idle_, idle);
    collect(disk_read_, rd);
    collect(disk_write_, wr);

    // Temperatures change slowly; refresh them every 5 s.
    const bool refresh_temps = tick_++ % 5 == 0;
    j.Key("disks").Arr();
    for (auto& d : disks_) {
      if (refresh_temps) d.temp = QueryDisk(d.number, false).temp;
      j.Obj();
      j.Key("number").Int(d.number);
      j.Key("model").Str(d.model);
      j.Key("bus").Str(d.bus);
      j.Key("temp").Opt(d.temp);
      const auto i = idle.find(d.number);
      j.Key("active").Opt(i == idle.end() ? -1 : std::clamp(100 - i->second, 0.0, 100.0));
      j.Key("read").Opt(rd.count(d.number) ? rd[d.number] : -1);
      j.Key("write").Opt(wr.count(d.number) ? wr[d.number] : -1);
      j.EndObj();
    }
    j.EndArr();

    j.Key("volumes").Arr();
    wchar_t drives[256];
    const DWORD n = GetLogicalDriveStringsW(255, drives);
    for (const wchar_t* p = drives; p < drives + n && *p; p += wcslen(p) + 1) {
      const UINT type = GetDriveTypeW(p);
      if (type != DRIVE_FIXED && type != DRIVE_REMOVABLE) continue;
      ULARGE_INTEGER free{}, total{};
      if (!GetDiskFreeSpaceExW(p, nullptr, &total, &free) || total.QuadPart == 0) {
        continue;
      }
      wchar_t label[MAX_PATH] = {}, fs[32] = {};
      GetVolumeInformationW(p, label, MAX_PATH, nullptr, nullptr, nullptr, fs, 32);
      int disk = -1;
      wchar_t dev[16];
      swprintf(dev, 16, L"\\\\.\\%c:", p[0]);
      HANDLE h = CreateFileW(dev, 0, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                             OPEN_EXISTING, 0, nullptr);
      if (h != INVALID_HANDLE_VALUE) {
        STORAGE_DEVICE_NUMBER num{};
        DWORD ret = 0;
        if (DeviceIoControl(h, IOCTL_STORAGE_GET_DEVICE_NUMBER, nullptr, 0, &num,
                            sizeof(num), &ret, nullptr)) {
          disk = static_cast<int>(num.DeviceNumber);
        }
        CloseHandle(h);
      }
      j.Obj();
      j.Key("letter").Str(Utf8(std::wstring(1, p[0])));
      j.Key("label").Str(Utf8(label));
      j.Key("fs").Str(Utf8(fs));
      j.Key("total").Num(static_cast<double>(total.QuadPart));
      j.Key("free").Num(static_cast<double>(free.QuadPart));
      j.Key("disk").Int(disk);
      j.Key("removable").Bool(type == DRIVE_REMOVABLE);
      j.EndObj();
    }
    j.EndArr();
  }

  void WriteNetwork(Json& j) {
    auto sum = [](const PdhArray& c) {
      double s = 0;
      for (auto& [name, v] : c.Read()) {
        std::wstring lower = name;
        for (auto& ch : lower) ch = towlower(ch);
        if (lower.find(L"loopback") != std::wstring::npos ||
            lower.find(L"isatap") != std::wstring::npos ||
            lower.find(L"teredo") != std::wstring::npos) {
          continue;
        }
        s += v;
      }
      return s;
    };
    j.Key("network").Obj();
    j.Key("down").Num(sum(net_down_));
    j.Key("up").Num(sum(net_up_));
    j.EndObj();
  }

  void WriteProcesses(Json& j) {
    j.Key("processes").Arr();
    if (!nt_query_) {
      j.EndArr();
      return;
    }
    ULONG size = 0;
    std::vector<BYTE>& buf = proc_buf_;
    for (int attempt = 0; attempt < 4; attempt++) {
      if (buf.empty()) buf.resize(1 << 20);
      const LONG s = nt_query_(5, buf.data(), static_cast<ULONG>(buf.size()), &size);
      if (s == 0) break;
      if (s != static_cast<LONG>(0xC0000004)) {  // STATUS_INFO_LENGTH_MISMATCH
        j.EndArr();
        return;
      }
      buf.resize(size + (64 << 10));
      size = 0;
    }
    if (size == 0) {
      j.EndArr();
      return;
    }
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    const ULONGLONG now = (static_cast<ULONGLONG>(ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
    const double elapsed = last_proc_time_ ? static_cast<double>(now - last_proc_time_) : 0;

    std::map<ULONG_PTR, ULONGLONG> times;
    std::map<std::wstring, ProcGroup> groups;
    for (ULONG off = 0;;) {
      auto* p = reinterpret_cast<ProcInfo*>(buf.data() + off);
      const auto pid = reinterpret_cast<ULONG_PTR>(p->UniqueProcessId);
      if (pid != 0) {
        const ULONGLONG t = static_cast<ULONGLONG>(p->UserTime.QuadPart) +
                            static_cast<ULONGLONG>(p->KernelTime.QuadPart);
        times[pid] = t;
        std::wstring name = p->NameBuffer
                                ? std::wstring(p->NameBuffer, p->NameLength / 2)
                                : std::wstring(L"System");
        std::wstring lower = name;
        for (auto& c : lower) c = towlower(c);
        auto& g = groups[lower];
        if (g.name.empty()) g.name = Utf8(name);
        g.count++;
        g.memory += static_cast<double>(p->WorkingSetPrivateSize.QuadPart);
        const auto prev = last_proc_times_.find(pid);
        if (elapsed > 0 && prev != last_proc_times_.end() && t >= prev->second) {
          g.cpu += (t - prev->second) / (elapsed * threads_) * 100;
        }
      }
      if (!p->NextEntryOffset) break;
      off += p->NextEntryOffset;
    }
    last_proc_times_ = std::move(times);
    last_proc_time_ = now;

    std::vector<ProcGroup> list;
    for (auto& [_, g] : groups) list.push_back(g);
    // The 25 busiest by CPU plus the 25 largest by memory.
    std::vector<ProcGroup> out;
    std::sort(list.begin(), list.end(), [](auto& a, auto& b) { return a.cpu > b.cpu; });
    for (size_t i = 0; i < list.size() && i < 25; i++) out.push_back(list[i]);
    std::sort(list.begin(), list.end(),
              [](auto& a, auto& b) { return a.memory > b.memory; });
    for (size_t i = 0, added = 0; i < list.size() && added < 25; i++) {
      bool seen = false;
      for (auto& o : out) seen |= o.name == list[i].name;
      if (!seen) {
        out.push_back(list[i]);
        added++;
      }
    }
    for (auto& g : out) {
      j.Obj();
      j.Key("name").Str(g.name);
      j.Key("count").Int(g.count);
      j.Key("cpu").Num(std::round(std::min(100.0, g.cpu) * 10) / 10);
      j.Key("memory").Num(g.memory);
      j.EndObj();
    }
    j.EndArr();
  }

  std::mutex control_;
  int users_ = 0;
  std::atomic<bool> running_{false};
  std::thread thread_;
  std::mutex snapshot_mutex_;
  std::string snapshot_;

  bool inited_ = false;
  int threads_ = 1, cores_ = 0;
  unsigned tick_ = 0;
  std::string cpu_name_;
  CpuSensors cpu_sensors_;
  bool sensor_thread_started_ = false;
  std::mutex sensor_mutex_;
  std::string sensor_status_;
  double sensor_temp_ = -1, sensor_power_ = -1;
  std::vector<double> sensor_ccds_;
  ULONGLONG sensor_updated_ = 0;
  ULONGLONG sensor_started_at_ = 0;
  Nvml nvml_;
  std::vector<GpuAdapter> gpus_;
  std::vector<PhysicalDisk> disks_;

  PDH_HQUERY query_ = nullptr;
  PdhArray cpu_total_, cpu_cores_, cpu_perf_, cpu_freq_;
  PdhArray gpu_engine_, gpu_dedicated_;
  PdhArray disk_idle_, disk_read_, disk_write_;
  PdhArray net_down_, net_up_;

  LONG(WINAPI* kmt_open_)(D3dkmtOpenAdapterFromLuid*) = nullptr;
  LONG(WINAPI* kmt_query_)(D3dkmtQueryAdapterInfo*) = nullptr;
  LONG(WINAPI* kmt_close_)(D3dkmtCloseAdapter*) = nullptr;

  NtQuerySystemInformationFn nt_query_ = nullptr;
  std::vector<BYTE> proc_buf_;
  std::map<ULONG_PTR, ULONGLONG> last_proc_times_;
  ULONGLONG last_proc_time_ = 0;
};

Monitor& Instance() {
  static Monitor* m = new Monitor();  // Never destroyed: the thread may outlive statics.
  return *m;
}

}  // namespace

extern "C" {

__declspec(dllexport) void OcSysmonStart() { Instance().Start(); }

__declspec(dllexport) void OcSysmonStop() { Instance().Stop(); }

// Copies the latest snapshot (JSON, UTF-8, NUL-terminated) into [buf] when
// it fits in [cap] bytes; returns its length either way (0 before the first
// sample).
__declspec(dllexport) int OcSysmonRead(char* buf, int cap) {
  return Instance().Read(buf, cap);
}

}  // extern "C"
