// System-audio (WASAPI loopback) and microphone capture with a small FFT
// analyzer. Exposed to Dart through the C functions at the bottom, looked up
// from the executable with DynamicLibrary.executable().
#include <windows.h>
#include <audioclient.h>
#include <ksmedia.h>
#include <mmdeviceapi.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <complex>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

namespace {

constexpr int kFftSize = 1024;
constexpr int kMaxBands = 128;
constexpr double kPi = 3.14159265358979323846;

// One capture stream (render loopback or a capture device) writing mono
// samples into a ring buffer.
class Stream {
 public:
  explicit Stream(bool loopback) : loopback_(loopback), ring_(kFftSize * 4) {}
  ~Stream() { Stop(); }

  void Start() {
    running_ = true;
    thread_ = std::thread([this] { Run(); });
  }

  void Stop() {
    running_ = false;
    if (thread_.joinable()) thread_.join();
  }

  // Copies the latest kFftSize samples; returns the sample rate (0 if none).
  int Latest(std::vector<float>& out) {
    std::lock_guard<std::mutex> lock(mutex_);
    out.resize(kFftSize);
    const size_t n = ring_.size();
    // Silence when the device stopped delivering (loopback sends nothing
    // while no audio plays).
    const bool stale = ::GetTickCount64() - last_packet_ > 150;
    for (int i = 0; i < kFftSize; i++) {
      out[i] = stale ? 0.f : ring_[(write_ + n - kFftSize + i) % n];
    }
    return sample_rate_;
  }

 private:
  void Push(const float* mono, size_t count) {
    std::lock_guard<std::mutex> lock(mutex_);
    for (size_t i = 0; i < count; i++) {
      ring_[write_] = mono[i];
      write_ = (write_ + 1) % ring_.size();
    }
    last_packet_ = ::GetTickCount64();
  }

  void Run() {
    ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    while (running_) {
      Capture();  // Returns on error or device change; retry after a pause.
      for (int i = 0; i < 20 && running_; i++) ::Sleep(50);
    }
    ::CoUninitialize();
  }

  void Capture() {
    IMMDeviceEnumerator* enumerator = nullptr;
    IMMDevice* device = nullptr;
    IAudioClient* client = nullptr;
    IAudioCaptureClient* capture = nullptr;
    WAVEFORMATEX* format = nullptr;
    auto cleanup = [&] {
      if (format) ::CoTaskMemFree(format);
      if (capture) capture->Release();
      if (client) {
        client->Stop();
        client->Release();
      }
      if (device) device->Release();
      if (enumerator) enumerator->Release();
    };
    if (FAILED(::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                  CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
                                  reinterpret_cast<void**>(&enumerator))) ||
        FAILED(enumerator->GetDefaultAudioEndpoint(
            loopback_ ? eRender : eCapture, eConsole, &device)) ||
        FAILED(device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                reinterpret_cast<void**>(&client))) ||
        FAILED(client->GetMixFormat(&format)) ||
        FAILED(client->Initialize(AUDCLNT_SHAREMODE_SHARED,
                                  loopback_ ? AUDCLNT_STREAMFLAGS_LOOPBACK : 0,
                                  200000 /* 20 ms */, 0, format, nullptr)) ||
        FAILED(client->GetService(__uuidof(IAudioCaptureClient),
                                  reinterpret_cast<void**>(&capture))) ||
        FAILED(client->Start())) {
      cleanup();
      return;
    }

    bool is_float = format->wFormatTag == WAVE_FORMAT_IEEE_FLOAT;
    if (format->wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
      auto* ext = reinterpret_cast<WAVEFORMATEXTENSIBLE*>(format);
      is_float = ext->SubFormat == KSDATAFORMAT_SUBTYPE_IEEE_FLOAT;
    }
    const int channels = std::max<int>(1, format->nChannels);
    const int bits = format->wBitsPerSample;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      sample_rate_ = static_cast<int>(format->nSamplesPerSec);
    }
    std::vector<float> mono;

    while (running_) {
      ::Sleep(10);
      UINT32 packet = 0;
      if (FAILED(capture->GetNextPacketSize(&packet))) break;
      while (packet > 0) {
        BYTE* data = nullptr;
        UINT32 frames = 0;
        DWORD flags = 0;
        if (FAILED(capture->GetBuffer(&data, &frames, &flags, nullptr, nullptr))) {
          packet = 0;
          break;
        }
        mono.assign(frames, 0.f);
        if (!(flags & AUDCLNT_BUFFERFLAGS_SILENT)) {
          for (UINT32 f = 0; f < frames; f++) {
            float sum = 0.f;
            for (int c = 0; c < channels; c++) {
              const size_t i = static_cast<size_t>(f) * channels + c;
              if (is_float && bits == 32) {
                sum += reinterpret_cast<float*>(data)[i];
              } else if (bits == 16) {
                sum += reinterpret_cast<int16_t*>(data)[i] / 32768.f;
              } else if (bits == 32) {
                sum += reinterpret_cast<int32_t*>(data)[i] / 2147483648.f;
              }
            }
            mono[f] = sum / channels;
          }
        }
        Push(mono.data(), mono.size());
        capture->ReleaseBuffer(frames);
        if (FAILED(capture->GetNextPacketSize(&packet))) packet = 0;
      }
    }
    cleanup();
  }

  const bool loopback_;
  std::atomic<bool> running_{false};
  std::thread thread_;
  std::mutex mutex_;
  std::vector<float> ring_;
  size_t write_ = 0;
  int sample_rate_ = 0;
  ULONGLONG last_packet_ = 0;
};

void Fft(std::vector<std::complex<double>>& a) {
  const size_t n = a.size();
  for (size_t i = 1, j = 0; i < n; i++) {
    size_t bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) std::swap(a[i], a[j]);
  }
  for (size_t len = 2; len <= n; len <<= 1) {
    const double ang = -2 * kPi / static_cast<double>(len);
    const std::complex<double> wl(std::cos(ang), std::sin(ang));
    for (size_t i = 0; i < n; i += len) {
      std::complex<double> w(1);
      for (size_t j = 0; j < len / 2; j++) {
        const auto u = a[i + j], v = a[i + j + len / 2] * w;
        a[i + j] = u + v;
        a[i + j + len / 2] = u - v;
        w *= wl;
      }
    }
  }
}

struct Analyzer {
  std::mutex mutex;
  std::unique_ptr<Stream> system;
  std::unique_ptr<Stream> mic;
  float smooth[kMaxBands] = {};
  float level = 0.f;
  // Beat detection state (onset of bass energy against its recent spread).
  float prev_bass = 0.f;
  float flux_mean = 0.f;
  float flux_var = 0.f;
  int since_beat = 0;
  float beat = 0.f;
  float beats = 0.f;

  // Fills `bands` (0..1, log spaced 30 Hz..16 kHz) from one stream, keeping
  // the louder value per band.
  float Accumulate(Stream* s, float* bands, int n) {
    std::vector<float> samples;
    const int rate = s->Latest(samples);
    if (rate <= 0) return 0.f;
    std::vector<std::complex<double>> buf(kFftSize);
    double rms = 0;
    for (int i = 0; i < kFftSize; i++) {
      const double hann = 0.5 * (1 - std::cos(2 * kPi * i / (kFftSize - 1)));
      buf[i] = samples[i] * hann;
      rms += samples[i] * samples[i];
    }
    Fft(buf);
    const double lo = std::log(30.0), hi = std::log(16000.0);
    const double hz_per_bin = static_cast<double>(rate) / kFftSize;
    for (int b = 0; b < n; b++) {
      const double f0 = std::exp(lo + (hi - lo) * b / n);
      const double f1 = std::exp(lo + (hi - lo) * (b + 1) / n);
      int i0 = std::max(1, static_cast<int>(f0 / hz_per_bin));
      int i1 = std::max(i0, std::min(kFftSize / 2 - 1, static_cast<int>(f1 / hz_per_bin)));
      double peak = 0;
      for (int i = i0; i <= i1; i++) peak = std::max(peak, std::abs(buf[i]));
      // Magnitude to dB, mapped from -70..-10 dBFS to 0..1.
      const double db = 20 * std::log10(peak / (kFftSize / 4.0) + 1e-9);
      bands[b] = std::max(bands[b], static_cast<float>(std::clamp((db + 70) / 60, 0.0, 1.0)));
    }
    return static_cast<float>(std::sqrt(rms / kFftSize));
  }
};

Analyzer& analyzer() {
  static Analyzer a;
  return a;
}

}  // namespace

extern "C" {

/// Selects the capture source: 0 off, 1 system audio, 2 microphone, 3 both.
__declspec(dllexport) void OcAudioSetSource(int source) {
  auto& a = analyzer();
  std::lock_guard<std::mutex> lock(a.mutex);
  const bool want_system = source & 1, want_mic = source & 2;
  if (want_system && !a.system) {
    a.system = std::make_unique<Stream>(true);
    a.system->Start();
  } else if (!want_system) {
    a.system.reset();
  }
  if (want_mic && !a.mic) {
    a.mic = std::make_unique<Stream>(false);
    a.mic->Start();
  } else if (!want_mic) {
    a.mic.reset();
  }
}

/// Writes `count` smoothed bands (0..1) and returns
/// [level 0..1, bass, mid, treble, beat 0..1, beat counter] in `stats`.
__declspec(dllexport) void OcAudioRead(float* bands, int count, float* stats) {
  auto& a = analyzer();
  std::lock_guard<std::mutex> lock(a.mutex);
  count = std::clamp(count, 1, kMaxBands);
  float raw[kMaxBands] = {};
  float rms = 0.f;
  if (a.system) rms = std::max(rms, a.Accumulate(a.system.get(), raw, count));
  if (a.mic) rms = std::max(rms, a.Accumulate(a.mic.get(), raw, count));
  for (int b = 0; b < count; b++) {
    // Fast attack, slower release, so bars move but don't flicker.
    const float k = raw[b] > a.smooth[b] ? 0.6f : 0.15f;
    a.smooth[b] += (raw[b] - a.smooth[b]) * k;
    bands[b] = a.smooth[b];
  }
  auto avg = [&](int from, int to) {
    float s = 0;
    for (int b = from; b < to; b++) s += a.smooth[b];
    return s / std::max(1, to - from);
  };
  const float bass = avg(0, count / 6), mid = avg(count / 6, count / 2),
              treble = avg(count / 2, count);
  const float target = std::clamp((20 * std::log10(rms + 1e-9f) + 60) / 60, 0.f, 1.f);
  a.level += (target - a.level) * (target > a.level ? 0.5f : 0.12f);
  // Beat: a rise in (unsmoothed) bass that stands out from the song's own
  // recent rises, so it works at any volume. Called at ~30 Hz; at least
  // 5 calls (~165 ms) between beats.
  float raw_bass = 0.f;
  for (int b = 0; b < std::max(1, count / 6); b++) raw_bass += raw[b];
  raw_bass /= std::max(1, count / 6);
  const float flux = std::max(0.f, raw_bass - a.prev_bass);
  a.prev_bass = raw_bass;
  const float threshold = a.flux_mean + 1.4f * std::sqrt(a.flux_var);
  a.since_beat++;
  if (flux > threshold && flux > 0.015f && raw_bass > 0.08f && a.since_beat >= 5) {
    a.beat = 1.f;
    a.beats += 1.f;
    a.since_beat = 0;
  } else {
    a.beat *= 0.85f;
  }
  const float dev = flux - a.flux_mean;
  a.flux_mean += dev * 0.05f;
  a.flux_var += (dev * dev - a.flux_var) * 0.05f;
  stats[0] = a.level;
  stats[1] = bass;
  stats[2] = mid;
  stats[3] = treble;
  stats[4] = a.beat;
  stats[5] = a.beats;
}

}  // extern "C"
