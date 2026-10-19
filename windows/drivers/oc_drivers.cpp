// OpenChroma device drivers: the OpenRGB driver collection (third_party/
// openrgb), built into oc_drivers.dll, behind a small C API for Dart FFI.
//
// Detection runs on OpenRGB's own threads. Dart polls OcdState() for the
// device list (JSON) and pushes colors with OcdSetLeds(); each controller
// writes to its hardware on its own thread, so no call here blocks on I/O.
//
// SPDX-License-Identifier: GPL-2.0-or-later

#include <windows.h>

#include <atomic>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <set>
#include <string>
#include <thread>

#include "ResourceManager.h"
#include "RGBController.h"

#define OCD_API extern "C" __declspec(dllexport)

namespace {

std::atomic<bool> g_started{false};
std::atomic<bool> g_initialized{false};
std::mutex g_mutex;
// Controllers already switched to their direct (per-LED) mode.
std::set<RGBController*> g_direct;

const char* TypeName(device_type t) {
  switch (t) {
    case DEVICE_TYPE_MOTHERBOARD: return "motherboard";
    case DEVICE_TYPE_DRAM: return "ram";
    case DEVICE_TYPE_GPU: return "gpu";
    case DEVICE_TYPE_COOLER: return "cooler";
    case DEVICE_TYPE_LEDSTRIP: return "ledstrip";
    case DEVICE_TYPE_KEYBOARD: return "keyboard";
    case DEVICE_TYPE_MOUSE: return "mouse";
    case DEVICE_TYPE_MOUSEMAT: return "mousepad";
    case DEVICE_TYPE_HEADSET: return "headset";
    case DEVICE_TYPE_HEADSET_STAND: return "headsetstand";
    case DEVICE_TYPE_GAMEPAD: return "gamepad";
    case DEVICE_TYPE_LIGHT: return "light";
    case DEVICE_TYPE_SPEAKER: return "speakers";
    case DEVICE_TYPE_STORAGE: return "storage";
    case DEVICE_TYPE_CASE: return "case";
    case DEVICE_TYPE_MICROPHONE: return "microphone";
    case DEVICE_TYPE_ACCESSORY: return "accessory";
    case DEVICE_TYPE_KEYPAD: return "keypad";
    case DEVICE_TYPE_LAPTOP: return "laptop";
    case DEVICE_TYPE_MONITOR: return "monitor";
    default: return "other";
  }
}

bool Known(RGBController* c) {
  for (RGBController* x : ResourceManager::get()->GetRGBControllers()) {
    if (x == c) return true;
  }
  return false;
}

// Picks the mode that takes per-LED colors from the host ("Direct" in most
// drivers), the way OpenRGB's own UI does for custom colors.
void EnsureDirect(RGBController* c) {
  if (g_direct.count(c)) return;
  g_direct.insert(c);
  c->SetCustomMode();
}

nlohmann::json Describe(RGBController* c) {
  nlohmann::json j;
  j["id"] = reinterpret_cast<std::uintptr_t>(c);
  j["name"] = c->GetName();
  j["vendor"] = c->GetVendor();
  j["description"] = c->GetDescription();
  j["location"] = c->GetLocation();
  j["serial"] = c->GetSerial();
  j["version"] = c->GetVersion();
  j["type"] = TypeName(c->GetDeviceType());
  j["leds"] = c->GetLEDCount();
  nlohmann::json zones = nlohmann::json::array();
  for (unsigned int z = 0; z < c->GetZoneCount(); z++) {
    nlohmann::json zj;
    zj["name"] = c->GetZoneName(z);
    zj["type"] = c->GetZoneType(z);
    zj["count"] = c->GetZoneLEDsCount(z);
    zj["min"] = c->GetZoneLEDsMin(z);
    zj["max"] = c->GetZoneLEDsMax(z);
    const unsigned int w = c->GetZoneMatrixMapWidth(z);
    const unsigned int h = c->GetZoneMatrixMapHeight(z);
    const unsigned int* map = c->GetZoneMatrixMapData(z);
    if (w > 0 && h > 0 && map) {
      zj["width"] = w;
      zj["height"] = h;
      zj["map"] = std::vector<unsigned int>(map, map + w * h);
    }
    zones.push_back(zj);
  }
  j["zones"] = zones;
  nlohmann::json modes = nlohmann::json::array();
  for (unsigned int m = 0; m < c->GetModeCount(); m++) {
    modes.push_back(c->GetModeName(m));
  }
  j["modes"] = modes;
  j["activeMode"] = c->GetActiveMode();
  return j;
}

}  // namespace

// Starts device detection in the background. [config_dir] (UTF-8) is where
// the drivers keep their settings and logs.
OCD_API int OcdStart(const char* config_dir) {
  if (g_started.exchange(true)) return 1;
  openchroma_config_dir = filesystem::u8path(config_dir ? config_dir : "");
  std::thread([] {
    // No client connection, no SDK server, no GUI: only local detection.
    ResourceManager::get()->Initialize(false, true, false, false, false);
    g_initialized = true;
  }).detach();
  return 1;
}

// Writes {"detecting", "percent", "step", "devices": [...]} as UTF-8 JSON
// into [buf]. Returns the length needed; when it is >= [cap], nothing was
// written and the caller retries with a bigger buffer.
OCD_API int OcdState(char* buf, int cap) {
  nlohmann::json j;
  j["ready"] = g_initialized.load();
  nlohmann::json devices = nlohmann::json::array();
  if (g_initialized) {
    ResourceManager* rm = ResourceManager::get();
    const unsigned int percent = rm->GetDetectionPercent();
    j["percent"] = percent;
    j["step"] = rm->GetDetectionString();
    j["detecting"] = percent < 100;
    std::lock_guard<std::mutex> lock(g_mutex);
    for (RGBController* c : rm->GetRGBControllers()) {
      devices.push_back(Describe(c));
    }
  }
  j["devices"] = devices;
  const std::string s = j.dump(-1, ' ', false,
                               nlohmann::json::error_handler_t::replace);
  const int n = static_cast<int>(s.size());
  if (buf && n < cap) {
    std::memcpy(buf, s.data(), n);
    buf[n] = 0;
  }
  return n;
}

// Sets every LED of controller [id] from [rgb] (3 bytes per LED, in the
// controller's LED order) and queues the hardware update.
OCD_API void OcdSetLeds(std::uint64_t id, const std::uint8_t* rgb, int count) {
  if (!g_initialized || !rgb) return;
  std::lock_guard<std::mutex> lock(g_mutex);
  auto* c = reinterpret_cast<RGBController*>(static_cast<std::uintptr_t>(id));
  if (!Known(c)) return;
  EnsureDirect(c);
  const unsigned int leds = c->GetLEDCount();
  const unsigned int n = count < 0 ? 0 : static_cast<unsigned int>(count);
  for (unsigned int i = 0; i < leds && i < n; i++) {
    c->SetColor(i, ToRGBColor(rgb[i * 3], rgb[i * 3 + 1], rgb[i * 3 + 2]));
  }
  c->UpdateLEDs();
}

// Changes the LED count of a resizable zone (ARGB headers).
OCD_API void OcdResizeZone(std::uint64_t id, int zone, int count) {
  if (!g_initialized) return;
  std::lock_guard<std::mutex> lock(g_mutex);
  auto* c = reinterpret_cast<RGBController*>(static_cast<std::uintptr_t>(id));
  if (!Known(c) || zone < 0 || static_cast<unsigned int>(zone) >= c->GetZoneCount()) {
    return;
  }
  c->ResizeZone(zone, count);
}

// Detects again (devices plugged in or out).
OCD_API void OcdRescan() {
  if (!g_initialized) return;
  std::lock_guard<std::mutex> lock(g_mutex);
  g_direct.clear();
  ResourceManager::get()->RescanDevices();
}

// Applies [rgb] to every LED of every device and waits for the writes, so
// the hardware keeps that color after the app exits.
OCD_API void OcdShutdown(std::uint8_t r, std::uint8_t g, std::uint8_t b) {
  if (!g_initialized) return;
  std::lock_guard<std::mutex> lock(g_mutex);
  for (RGBController* c : ResourceManager::get()->GetRGBControllers()) {
    if (!g_direct.count(c)) continue;
    c->SetAllColors(ToRGBColor(r, g, b));
    c->UpdateLEDs();
    c->WaitForDeviceUpdate();
  }
}
