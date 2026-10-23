// Battery levels Windows already knows: Bluetooth devices report theirs
// through the PnP property Settings shows (headsets, controllers, mice).
// Exposed to Dart through OcBatteries(), looked up with
// DynamicLibrary.executable().
#include <windows.h>
#include <initguid.h>
#include <devpkey.h>
#include <setupapi.h>

#include <cstring>
#include <cwctype>
#include <map>
#include <string>
#include <vector>

#include "json_writer.h"

namespace {

// DEVPKEY_Bluetooth_Battery: the charge in percent, as a byte.
const DEVPROPKEY kBattery = {
    {0x104EA319, 0x6EE2, 0x4701, {0xBD, 0x47, 0x8D, 0xDB, 0xF4, 0x25, 0xBB, 0xE5}},
    2};

struct Node {
  std::wstring id;
  std::wstring name;
  GUID container{};
  int battery = -1;
};

std::wstring StringProperty(HDEVINFO set, SP_DEVINFO_DATA* info,
                            const DEVPROPKEY& key) {
  DEVPROPTYPE type = 0;
  wchar_t buf[512];
  if (!SetupDiGetDevicePropertyW(set, info, &key, &type,
                                 reinterpret_cast<PBYTE>(buf), sizeof(buf),
                                 nullptr, 0) ||
      type != DEVPROP_TYPE_STRING) {
    return {};
  }
  return buf;
}

// The hex digits after [tag] in [id] ("VID_" or "VID&0002" -> "054C").
int HexAfter(const std::wstring& id, const wchar_t* tag) {
  const auto at = id.find(tag);
  if (at == std::wstring::npos) return -1;
  size_t i = at + wcslen(tag);
  int v = 0, digits = 0;
  for (; i < id.size() && digits < 4 && iswxdigit(id[i]); i++, digits++) {
    v = v * 16 + (iswdigit(id[i]) ? id[i] - L'0' : (towupper(id[i]) - L'A' + 10));
  }
  return digits == 4 ? v : -1;
}

std::vector<Node> ReadNodes() {
  std::vector<Node> nodes;
  HDEVINFO set = SetupDiGetClassDevsW(nullptr, nullptr, nullptr,
                                      DIGCF_ALLCLASSES | DIGCF_PRESENT);
  if (set == INVALID_HANDLE_VALUE) return nodes;
  SP_DEVINFO_DATA info{sizeof(info)};
  for (DWORD i = 0; SetupDiEnumDeviceInfo(set, i, &info); i++) {
    Node n;
    wchar_t id[512];
    if (!SetupDiGetDeviceInstanceIdW(set, &info, id, 512, nullptr)) continue;
    n.id = id;
    DEVPROPTYPE type = 0;
    if (!SetupDiGetDevicePropertyW(set, &info, &DEVPKEY_Device_ContainerId,
                                   &type, reinterpret_cast<PBYTE>(&n.container),
                                   sizeof(n.container), nullptr, 0) ||
        type != DEVPROP_TYPE_GUID) {
      continue;
    }
    n.name = StringProperty(set, &info, DEVPKEY_Device_FriendlyName);
    if (n.name.empty()) {
      n.name = StringProperty(set, &info, DEVPKEY_Device_DeviceDesc);
    }
    BYTE level = 0;
    if (SetupDiGetDevicePropertyW(set, &info, &kBattery, &type, &level,
                                  sizeof(level), nullptr, 0) &&
        type == DEVPROP_TYPE_BYTE) {
      n.battery = level;
    }
    nodes.push_back(std::move(n));
  }
  SetupDiDestroyDeviceInfoList(set);
  return nodes;
}

struct GuidLess {
  bool operator()(const GUID& a, const GUID& b) const {
    return std::memcmp(&a, &b, sizeof(GUID)) < 0;
  }
};

}  // namespace

extern "C" {

// Writes [{"name", "battery", "vid", "pid"}] (UTF-8 JSON) into [buf]: one
// entry per physical device with a battery level. "name" is the device's
// own name (the shortest name among its nodes that starts the battery
// node's, e.g. "Fone" of "Fone Hands-Free AG"); vid/pid are -1 when no node
// carries them. Returns the length needed; nothing is written when it is
// >= [cap].
__declspec(dllexport) int OcBatteries(char* buf, int cap) {
  const auto nodes = ReadNodes();
  std::map<GUID, std::vector<const Node*>, GuidLess> containers;
  for (const auto& n : nodes) containers[n.container].push_back(&n);
  oc::Json j;
  j.Arr();
  for (const auto& [container, group] : containers) {
    const Node* charged = nullptr;
    for (const Node* n : group) {
      if (n->battery >= 0) {
        charged = n;
        break;
      }
    }
    if (!charged) continue;
    std::wstring name = charged->name;
    int vid = -1, pid = -1;
    for (const Node* n : group) {
      if (!n->name.empty() && n->name.size() < name.size() &&
          charged->name.compare(0, n->name.size(), n->name) == 0) {
        name = n->name;
      }
      if (vid < 0) {
        // HID over Bluetooth: "..._VID&0002054C_PID&09CC"; USB: "VID_054C".
        vid = HexAfter(n->id, L"VID&0002");
        pid = HexAfter(n->id, L"_PID&");
        if (vid < 0) {
          vid = HexAfter(n->id, L"VID_");
          pid = HexAfter(n->id, L"PID_");
        }
        if (pid < 0) vid = -1;
      }
    }
    j.Obj()
        .Key("name").Str(oc::Utf8(name))
        .Key("battery").Int(charged->battery)
        .Key("vid").Int(vid)
        .Key("pid").Int(pid)
        .EndObj();
  }
  j.EndArr();
  const int n = static_cast<int>(j.str.size());
  if (buf && n < cap) {
    std::memcpy(buf, j.str.data(), n);
    buf[n] = 0;
  }
  return n;
}

}  // extern "C"
