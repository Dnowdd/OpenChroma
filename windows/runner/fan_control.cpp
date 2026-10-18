// Fan control: motherboard fan headers on ITE IT87xx Super I/O chips and
// NVIDIA GPU coolers. A background thread reads every channel once per
// second and keeps the latest snapshot as JSON, read from Dart through the
// C functions at the bottom; Dart sets duty cycles with OcFansSet.
//
// - Super I/O: the PawnIO LpcIO module (assets/pawnio/LpcIO.bin), driven the
//   way LibreHardwareMonitor's IT87XX does: enter config mode on port 0x2E,
//   read the environment controller's base address, then talk to its
//   address/data ports at base + 5 / base + 6. Needs an elevated process.
// - NVIDIA: NvAPI's client fan cooler functions (as NvAPIWrapper uses them),
//   which report and set every GPU fan on its own.
//
// Safety:
// - A channel returns to firmware control (BIOS / driver curve) when Dart
//   releases it, when no command arrived for kWatchdogMs (UI hung), on
//   OcFansReleaseAll and at process exit.
// - Commands are ignored while another fan program runs.
// - Super I/O access holds the mutex LibreHardwareMonitor-based tools share.
#include <windows.h>
#include <tlhelp32.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <condition_variable>
#include <cstdint>
#include <cstdlib>
#include <map>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "json_writer.h"
#include "pawnio.h"

namespace {

using oc::Json;

constexpr ULONGLONG kWatchdogMs = 15000;

// ---------------------------------------------------------------- ISA bus

// Shared with LibreHardwareMonitor, FanControl, HWiNFO and others so two
// programs never interleave address/data port accesses.
class IsaBusLock {
 public:
  IsaBusLock() {
    static HANDLE mutex =
        CreateMutexW(nullptr, FALSE, L"Global\\Access_ISABUS.HTP.Method");
    mutex_ = mutex;
    if (!mutex_) {
      locked_ = true;  // Could not open it: nobody to coordinate with.
      return;
    }
    const DWORD r = WaitForSingleObject(mutex_, 50);
    locked_ = r == WAIT_OBJECT_0 || r == WAIT_ABANDONED;
    owned_ = locked_;
  }
  ~IsaBusLock() {
    if (owned_) ReleaseMutex(mutex_);
  }
  bool locked() const { return locked_; }

 private:
  HANDLE mutex_ = nullptr;
  bool locked_ = false;
  bool owned_ = false;
};

// ---------------------------------------------------------------- ITE

struct IteModel {
  uint16_t id;
  const char* name;
  int fans, controls, temps;
  bool control;  // Writes are known to work the LibreHardwareMonitor way.
};

// Chips with 16-bit fan counters and extended PWM registers, the layout
// IT87XX handles without special cases. Others are left alone.
constexpr IteModel kIteModels[] = {
    {0x8613, "IT8613E", 5, 4, 4, true},  {0x8620, "IT8620E", 5, 5, 3, true},
    {0x8628, "IT8628E", 6, 6, 6, true},  {0x8631, "IT8631E", 2, 2, 2, true},
    {0x8638, "IT8638E", 2, 2, 2, true},  {0x8686, "IT8686E", 6, 5, 7, true},
    {0x8688, "IT8688E", 6, 5, 6, true},  {0x8689, "IT8689E", 6, 6, 6, true},
    {0x8696, "IT8696E", 6, 6, 6, true},  {0x8721, "IT8721F", 5, 3, 3, true},
    {0x8728, "IT8728F", 5, 3, 3, true},  {0x8772, "IT8772E", 5, 3, 3, true},
};

class IteChip {
 public:
  const IteModel* model = nullptr;

  // "ok", "needs_admin", "no_driver", "not_found" or "busy".
  const char* Probe() {
    if (!oc::IsElevated()) return "needs_admin";
    if (!oc::PawnIo::Installed()) return "no_driver";
    if (!io_.Open(L"LpcIO.bin")) return "no_driver";
    IsaBusLock lock;
    if (!lock.locked()) return "busy";

    ULONG64 slot = 0;  // Config ports 0x2E / 0x2F.
    io_.Execute("ioctl_select_slot", &slot, 1, nullptr, 0);
    // Enter the ITE configuration mode.
    for (const uint8_t b : {uint8_t{0x87}, uint8_t{0x01}, uint8_t{0x55},
                            uint8_t{0x55}}) {
      PioOut(kConfigPort, b);
    }
    const uint16_t chip_id = SuperIoWord(0x20);
    for (const auto& m : kIteModels) {
      if (m.id == chip_id) model = &m;
    }
    if (!model) {
      ExitConfig();
      return "not_found";
    }
    // Lets the module reach the base addresses the chip decodes.
    io_.Execute("ioctl_find_bars", nullptr, 0, nullptr, 0);
    SuperIoOut(0x07, 0x04);  // Environment controller logical device.
    const uint16_t address = SuperIoWord(0x60);
    Sleep(1);
    const uint16_t verify = SuperIoWord(0x60);
    ExitConfig();
    if (address != verify || address < 0x100 || (address & 0xF007) != 0) {
      model = nullptr;
      return "not_found";
    }
    address_ = address;

    bool valid = false;
    const uint8_t vendor = Read(0x58, valid);
    if (!valid || (vendor != 0x90 && vendor != 0x7F)) {
      model = nullptr;
      return "not_found";
    }
    const uint8_t config = Read(0x00, valid);
    if (!valid || !(config & 0x10)) {
      model = nullptr;
      return "not_found";
    }
    disabled_.assign(model->fans, false);
    const uint8_t modes = Read(0x0C, valid);
    if (valid) {
      if (model->fans >= 5) {
        disabled_[3] = !(modes & 0x10);
        disabled_[4] = !(modes & 0x20);
      }
      if (model->fans >= 6) disabled_[5] = !(modes & 0x04);
    }
    saved_.assign(model->controls, Saved{});
    return "ok";
  }

  // RPM per fan and duty per control (-1: no reading / firmware control).
  void Sample(std::vector<double>& rpm, std::vector<double>& duty,
              std::vector<double>& temps) {
    rpm.assign(model->fans, -1);
    duty.assign(model->controls, -1);
    temps.assign(model->temps, -1);
    IsaBusLock lock;
    if (!lock.locked()) return;
    bool valid = false;
    for (int i = 0; i < model->fans; i++) {
      if (disabled_[i]) continue;
      int v = Read(kTach[i], valid);
      if (!valid) continue;
      v |= Read(kTachExt[i], valid) << 8;
      if (!valid) continue;
      if (v > 0x3F) rpm[i] = v < 0xFFFF ? 1.35e6 / (v * 2.0) : 0;
    }
    for (int i = 0; i < model->controls; i++) {
      const uint8_t ctrl = Read(kPwmCtrl[i], valid);
      if (!valid || (ctrl & 0x80)) continue;  // Automatic: unreadable.
      const uint8_t v = Read(kPwmExt[i], valid);
      if (valid) duty[i] = std::round(v * 100.0 / 255);
    }
    for (int i = 0; i < model->temps; i++) {
      const auto v = static_cast<int8_t>(Read(static_cast<uint8_t>(0x29 + i), valid));
      if (valid && v > 0 && v < 127) temps[i] = v;
    }
  }

  bool Set(int i, int percent) {
    IsaBusLock lock;
    if (!lock.locked()) return false;
    bool valid = false;
    Saved& s = saved_[i];
    if (!s.held) {
      s.ctrl = Read(kPwmCtrl[i], valid);
      if (!valid) return false;
      if (i < 3) s.main_on = ((Read(kMainCtrl, valid) >> i) & 1) != 0;
      s.ext = Read(kPwmExt[i], valid);
      s.held = true;
    }
    if (i < 3 && !s.main_on) {
      Write(kMainCtrl, static_cast<uint8_t>(Read(kMainCtrl, valid) | (1 << i)));
    }
    // Bit 7 clear selects software (manual) operation.
    Write(kPwmCtrl[i], static_cast<uint8_t>(model->id == 0x8689 ? 0x7F : (s.ctrl & 0x7F)));
    Write(kPwmExt[i], static_cast<uint8_t>(std::lround(percent * 255.0 / 100)));
    return true;
  }

  void Restore(int i) {
    Saved& s = saved_[i];
    if (!s.held) return;
    IsaBusLock lock;
    if (!lock.locked()) return;
    Write(kPwmCtrl[i], s.ctrl);
    if (i < 3) {
      bool valid = false;
      const uint8_t v = Read(kMainCtrl, valid);
      if (valid && (((v >> i) & 1) != 0) != s.main_on) {
        Write(kMainCtrl, static_cast<uint8_t>(v ^ (1 << i)));
      }
    }
    Write(kPwmExt[i], s.ext);
    s.held = false;
  }

 private:
  struct Saved {
    bool held = false;
    uint8_t ctrl = 0, ext = 0;
    bool main_on = false;
  };

  static constexpr uint16_t kConfigPort = 0x2E;
  static constexpr uint8_t kMainCtrl = 0x13;
  static constexpr uint8_t kTach[] = {0x0d, 0x0e, 0x0f, 0x80, 0x82, 0x4c};
  static constexpr uint8_t kTachExt[] = {0x18, 0x19, 0x1a, 0x81, 0x83, 0x4d};
  static constexpr uint8_t kPwmCtrl[] = {0x15, 0x16, 0x17, 0x7f, 0xa7, 0xaf};
  static constexpr uint8_t kPwmExt[] = {0x63, 0x6b, 0x73, 0x7b, 0xa3, 0xab};

  void PioOut(uint16_t port, uint8_t value) {
    const ULONG64 in[2] = {port, value};
    io_.Execute("ioctl_pio_outb", in, 2, nullptr, 0);
  }
  uint8_t PioIn(uint16_t port) {
    const ULONG64 in = port;
    ULONG64 out = 0xFF;
    io_.Execute("ioctl_pio_inb", &in, 1, &out, 1);
    return static_cast<uint8_t>(out);
  }
  uint16_t SuperIoWord(uint8_t reg) {
    const ULONG64 in = reg;
    ULONG64 out = 0xFFFF;
    io_.Execute("ioctl_superio_inw", &in, 1, &out, 1);
    return static_cast<uint16_t>(out);
  }
  void SuperIoOut(uint8_t reg, uint8_t value) {
    const ULONG64 in[2] = {reg, value};
    io_.Execute("ioctl_superio_outb", in, 2, nullptr, 0);
  }
  void ExitConfig() {
    PioOut(kConfigPort, 0x02);
    PioOut(static_cast<uint16_t>(kConfigPort + 1), 0x02);
  }

  uint16_t AddressPort() const { return static_cast<uint16_t>(address_ + 5); }
  uint16_t DataPort() const { return static_cast<uint16_t>(address_ + 6); }

  uint8_t Read(uint8_t reg, bool& valid) {
    PioOut(AddressPort(), reg);
    const uint8_t v = PioIn(DataPort());
    // The IT8688E does not echo the address register.
    valid = model->id == 0x8688 || PioIn(AddressPort()) == reg;
    return v;
  }
  void Write(uint8_t reg, uint8_t value) {
    PioOut(AddressPort(), reg);
    PioOut(DataPort(), value);
    PioIn(AddressPort());
  }

  oc::PawnIo io_;
  uint16_t address_ = 0;
  std::vector<bool> disabled_;
  std::vector<Saved> saved_;
};

// ---------------------------------------------------------------- NVIDIA

// Private NvAPI client fan cooler structures (version 1); layouts as in
// NvAPIWrapper's PrivateFanCoolers*V1.
struct NvCoolerStatusEntry {
  uint32_t cooler_id, rpm, min_level, max_level, level;
  uint32_t reserved[8];
};
struct NvCoolerStatus {
  uint32_t version, count;
  uint32_t reserved[8];
  NvCoolerStatusEntry entries[32];
};
struct NvCoolerControlEntry {
  uint32_t cooler_id, level, mode;  // mode: 0 auto, 1 manual
  uint32_t reserved[8];
};
struct NvCoolerControl {
  uint32_t version, unknown, count;
  uint32_t reserved[8];
  NvCoolerControlEntry entries[32];
};
static_assert(sizeof(NvCoolerStatus) == 1704);
static_assert(sizeof(NvCoolerControl) == 1452);

template <typename T>
constexpr uint32_t NvVersion() {
  return static_cast<uint32_t>(sizeof(T)) | (1u << 16);
}

class NvCoolers {
 public:
  struct Gpu {
    void* handle;
    std::string name;
    std::vector<uint32_t> coolers;
  };
  std::vector<Gpu> gpus;

  // "ok", "none" or "failed".
  const char* Init() {
    HMODULE lib = LoadLibraryW(L"nvapi64.dll");
    if (!lib) return "none";
    auto query = reinterpret_cast<void* (*)(uint32_t)>(
        GetProcAddress(lib, "nvapi_QueryInterface"));
    if (!query) return "failed";
    auto init = reinterpret_cast<int (*)()>(query(0x0150E828));
    auto enumerate =
        reinterpret_cast<int (*)(void**, uint32_t*)>(query(0xE5AC921F));
    auto full_name = reinterpret_cast<int (*)(void*, char*)>(query(0xCEEE8E9F));
    status_ = reinterpret_cast<StatusFn>(query(0x35AED5E8));
    get_control_ = reinterpret_cast<ControlFn>(query(0x814B209F));
    set_control_ = reinterpret_cast<ControlFn>(query(0xA58971A5));
    if (!init || !enumerate || !status_ || init() != 0) return "failed";
    void* handles[64] = {};
    uint32_t count = 0;
    if (enumerate(handles, &count) != 0) return "failed";
    for (uint32_t i = 0; i < count; i++) {
      Gpu g{handles[i], "NVIDIA", {}};
      char name[64] = {};
      if (full_name && full_name(handles[i], name) == 0) g.name = name;
      NvCoolerStatus s{};
      s.version = NvVersion<NvCoolerStatus>();
      if (status_(handles[i], &s) != 0) continue;
      for (uint32_t c = 0; c < s.count && c < 32; c++) {
        g.coolers.push_back(s.entries[c].cooler_id);
      }
      if (!g.coolers.empty()) gpus.push_back(g);
    }
    return gpus.empty() ? "none" : "ok";
  }

  bool CanControl() const { return get_control_ && set_control_; }

  // Per cooler: RPM and level in percent (-1 when unreadable).
  void Sample(const Gpu& g, std::vector<double>& rpm, std::vector<double>& duty) {
    rpm.assign(g.coolers.size(), -1);
    duty.assign(g.coolers.size(), -1);
    NvCoolerStatus s{};
    s.version = NvVersion<NvCoolerStatus>();
    if (status_(g.handle, &s) != 0) return;
    for (size_t c = 0; c < g.coolers.size(); c++) {
      for (uint32_t e = 0; e < s.count && e < 32; e++) {
        if (s.entries[e].cooler_id != g.coolers[c]) continue;
        rpm[c] = s.entries[e].rpm;
        duty[c] = s.entries[e].level;
      }
    }
  }

  // [percent] < 0 hands the cooler back to the driver.
  bool Set(const Gpu& g, size_t cooler, int percent) {
    if (!CanControl()) return false;
    NvCoolerControl c{};
    c.version = NvVersion<NvCoolerControl>();
    if (get_control_(g.handle, &c) != 0) return false;
    bool found = false;
    for (uint32_t e = 0; e < c.count && e < 32; e++) {
      if (c.entries[e].cooler_id != g.coolers[cooler]) continue;
      c.entries[e].mode = percent < 0 ? 0 : 1;
      c.entries[e].level = percent < 0 ? 0 : static_cast<uint32_t>(percent);
      found = true;
    }
    return found && set_control_(g.handle, &c) == 0;
  }

 private:
  using StatusFn = int (*)(void*, NvCoolerStatus*);
  using ControlFn = int (*)(void*, NvCoolerControl*);
  StatusFn status_ = nullptr;
  ControlFn get_control_ = nullptr;
  ControlFn set_control_ = nullptr;
};

// ---------------------------------------------------------------- Others

// Another running fan program would fight over the same registers.
std::string FindConflict() {
  static const std::pair<const wchar_t*, const char*> kApps[] = {
      {L"fancontrol.exe", "Fan Control"},
      {L"argusmonitor.exe", "Argus Monitor"},
      {L"speedfan.exe", "SpeedFan"},
  };
  HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snap == INVALID_HANDLE_VALUE) return {};
  std::string found;
  PROCESSENTRY32W e{sizeof(e)};
  for (BOOL ok = Process32FirstW(snap, &e); ok && found.empty();
       ok = Process32NextW(snap, &e)) {
    for (const auto& [exe, name] : kApps) {
      if (_wcsicmp(e.szExeFile, exe) == 0) found = name;
    }
  }
  CloseHandle(snap);
  return found;
}

std::string Lower(std::string s) {
  for (auto& c : s) c = static_cast<char>(tolower(static_cast<unsigned char>(c)));
  return s;
}

// ---------------------------------------------------------------- Service

struct Channel {
  std::string id;
  std::string group;   // "motherboard" or "gpu"
  std::string device;  // Chip or GPU name
  int index = 0;       // Header / cooler number on that device
  int gpu = -1;        // Index into NvCoolers::gpus for GPU coolers
  bool controllable = false;
  double rpm = -1, duty = -1;
  int applied = -1;  // Duty we set and still hold; -1 firmware control
};

class FanService {
 public:
  void Start() {
    std::lock_guard<std::mutex> lock(control_);
    if (started_) return;
    started_ = true;
    std::atexit([] { Instance().ReleaseAll(); });
    std::thread([this] { Run(); }).detach();
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

  void Set(const std::string& id, int percent) {
    if (closed_) return;
    percent = std::clamp(percent, -1, 100);
    bool changed = false;
    {
      std::lock_guard<std::mutex> lock(commands_mutex_);
      auto& c = commands_[id];
      changed = c.at == 0 || c.percent != percent;
      c = {percent, GetTickCount64()};
    }
    // Repeats only refresh the watchdog; a new value applies right away.
    if (changed) wake_.notify_one();
  }

  // Hands every channel back to firmware control, now, and ignores
  // commands from then on: the app is exiting.
  void ReleaseAll() {
    closed_ = true;
    {
      std::lock_guard<std::mutex> lock(commands_mutex_);
      commands_.clear();
    }
    std::unique_lock<std::timed_mutex> hw(hw_, std::chrono::milliseconds(800));
    if (!hw.owns_lock()) return;
    for (auto& c : channels_) Release(c);
  }

  static FanService& Instance() {
    static FanService* s = new FanService();  // Outlives the detached thread.
    return *s;
  }

 private:
  struct Command {
    int percent = -1;
    ULONGLONG at = 0;
  };

  void Init() {
    std::lock_guard<std::timed_mutex> hw(hw_);
    superio_status_ = ite_.Probe();
    if (ite_.model) {
      const std::string lower = Lower(ite_.model->name);
      for (int i = 0; i < std::max(ite_.model->fans, ite_.model->controls); i++) {
        Channel c;
        c.id = lower + "/" + std::to_string(i);
        c.group = "motherboard";
        c.device = ite_.model->name;
        c.index = i;
        c.controllable = ite_.model->control && i < ite_.model->controls;
        channels_.push_back(c);
      }
    }
    nvidia_status_ = nv_.Init();
    for (size_t g = 0; g < nv_.gpus.size(); g++) {
      for (size_t i = 0; i < nv_.gpus[g].coolers.size(); i++) {
        Channel c;
        c.id = "nvidia" + std::to_string(g) + "/" + std::to_string(i);
        c.group = "gpu";
        c.device = nv_.gpus[g].name;
        c.index = static_cast<int>(i);
        c.gpu = static_cast<int>(g);
        // NvAPI refuses SetControl (NVAPI_INVALID_USER_PRIVILEGE) unless
        // the process is elevated.
        c.controllable = nv_.CanControl() && oc::IsElevated();
        channels_.push_back(c);
      }
    }
  }

  void Run() {
    Init();
    for (unsigned tick = 0;; tick++) {
      if (tick % 3 == 0) conflict_ = FindConflict();
      {
        std::lock_guard<std::timed_mutex> hw(hw_);
        Sample();
        Apply();
      }
      Publish();
      std::unique_lock<std::mutex> lock(commands_mutex_);
      wake_.wait_for(lock, std::chrono::milliseconds(1000));
    }
  }

  void Sample() {
    if (ite_.model) {
      std::vector<double> rpm, duty;
      ite_.Sample(rpm, duty, ite_temps_);
      for (auto& c : channels_) {
        if (c.group != "motherboard") continue;
        c.rpm = c.index < static_cast<int>(rpm.size()) ? rpm[c.index] : -1;
        c.duty = c.index < static_cast<int>(duty.size()) ? duty[c.index] : -1;
      }
    }
    for (size_t g = 0; g < nv_.gpus.size(); g++) {
      std::vector<double> rpm, duty;
      nv_.Sample(nv_.gpus[g], rpm, duty);
      for (auto& c : channels_) {
        if (c.gpu != static_cast<int>(g)) continue;
        c.rpm = rpm[c.index];
        c.duty = duty[c.index];
      }
    }
  }

  void Apply() {
    std::map<std::string, Command> commands;
    {
      std::lock_guard<std::mutex> lock(commands_mutex_);
      commands = commands_;
    }
    const ULONGLONG now = GetTickCount64();
    for (auto& c : channels_) {
      const auto it = commands.find(c.id);
      const bool live = it != commands.end() && it->second.percent >= 0 &&
                        now - it->second.at < kWatchdogMs;
      if (!c.controllable || !conflict_.empty() || !live) {
        Release(c);
        continue;
      }
      const int want = it->second.percent;
      // Re-apply when the firmware took the channel back or changed it.
      if (c.applied == want && c.duty >= 0 && std::abs(c.duty - want) <= 2) {
        continue;
      }
      const bool ok = c.gpu >= 0 ? nv_.Set(nv_.gpus[c.gpu], c.index, want)
                                 : ite_.Set(c.index, want);
      if (ok) {
        c.applied = want;
        c.duty = want;
      }
    }
  }

  void Release(Channel& c) {
    if (c.applied < 0) return;
    if (c.gpu >= 0) {
      nv_.Set(nv_.gpus[c.gpu], c.index, -1);
    } else {
      ite_.Restore(c.index);
    }
    c.applied = -1;
  }

  void Publish() {
    Json j;
    j.Obj();
    j.Key("time").Int(static_cast<long long>(GetTickCount64()));
    j.Key("elevated").Bool(oc::IsElevated());
    j.Key("superio").Str(superio_status_);
    j.Key("chip").Str(ite_.model ? ite_.model->name : "");
    j.Key("nvidia").Str(nvidia_status_);
    j.Key("conflict").Str(conflict_);
    j.Key("fans").Arr();
    for (const auto& c : channels_) {
      j.Obj();
      j.Key("id").Str(c.id);
      j.Key("group").Str(c.group);
      j.Key("device").Str(c.device);
      j.Key("index").Int(c.index);
      j.Key("rpm").Opt(c.rpm);
      j.Key("duty").Opt(c.duty);
      j.Key("controllable").Bool(c.controllable);
      j.Key("controlled").Bool(c.applied >= 0);
      j.EndObj();
    }
    j.EndArr();
    j.Key("temps").Arr();
    for (size_t i = 0; i < ite_temps_.size(); i++) {
      j.Opt(ite_temps_[i]);
    }
    j.EndArr();
    j.EndObj();
    std::lock_guard<std::mutex> lock(snapshot_mutex_);
    snapshot_ = std::move(j.str);
  }

  std::mutex control_;
  bool started_ = false;
  std::atomic<bool> closed_{false};

  std::timed_mutex hw_;  // Guards the chips and channels_.
  IteChip ite_;
  NvCoolers nv_;
  std::vector<Channel> channels_;
  std::vector<double> ite_temps_;
  const char* superio_status_ = "pending";
  const char* nvidia_status_ = "pending";
  std::string conflict_;

  std::mutex commands_mutex_;
  std::condition_variable wake_;
  std::map<std::string, Command> commands_;

  std::mutex snapshot_mutex_;
  std::string snapshot_;
};

}  // namespace

extern "C" {

__declspec(dllexport) void OcFansStart() { FanService::Instance().Start(); }

// Copies the latest snapshot (JSON, UTF-8, NUL-terminated) into [buf] when
// it fits in [cap] bytes; returns its length either way (0 before the first
// sample).
__declspec(dllexport) int OcFansRead(char* buf, int cap) {
  return FanService::Instance().Read(buf, cap);
}

// Holds fan [id] at [percent] (0-100), or hands it back to the firmware
// with -1. Repeat it at least every 15 s or the channel is released.
__declspec(dllexport) void OcFansSet(const char* id, int percent) {
  if (id) FanService::Instance().Set(id, percent);
}

// Releases every fan for good; call when the app exits.
__declspec(dllexport) void OcFansReleaseAll() {
  FanService::Instance().ReleaseAll();
}

}  // extern "C"
