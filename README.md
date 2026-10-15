# OpenChroma

Open-source clone of SignalRGB for Windows, written in Flutter. It reuses the
plugins, effects and components of the existing SignalRGB installation
(`%LOCALAPPDATA%\VortxEngine\app-*\Signal-x64`) without modifying them.

## How it works

| SignalRGB (original)                      | OpenChroma                                                   |
|-------------------------------------------|--------------------------------------------------------------|
| HTML effects rendered in Ultralight       | WebView2 (`webview_windows`), canvas captured at 30 fps       |
| JS plugins (ES modules) in a JS engine    | QuickJS (`flutter_js`), one isolate per device               |
| `device.*` API in C++                     | JS shim in `lib/src/plugins/prelude.dart`                    |
| hidapi (`hid_write`, `hid_read_timeout`…) | Direct FFI to `hid.dll`/`setupapi`, same semantics           |
| WMI `Win32_BaseBoard`                     | Registry `HKLM\HARDWARE\DESCRIPTION\System\BIOS`             |

Flow: the effect draws onto a 320×200 canvas, which the page sends to Dart. The
engine samples the color at each LED position using the layout (position and
scale), sends it to the device isolate, and the plugin's `Render()` calls
`device.color(x, y)` and writes the HID packets.

```
lib/src/
  hid/hid_ffi.dart            enumeration and hidapi-style I/O
  plugins/js_transform.dart   ES module -> global script (imports, exports)
  plugins/prelude.dart        device/bus/systeminfo/Errors API for the plugins
  plugins/plugin_scanner.dart plugin metadata (cached in %APPDATA%\OpenChroma)
  engine/device_worker.dart   isolate: Validate -> Initialize -> Render loop -> Shutdown
  engine/engine.dart          discovery/hotplug, layout, sampling, persistence
  effects/                    reading <meta> tags and the WebView2 host
  ui/                         Effects, Devices, Layout, Settings
```

## Running

```
flutter run -d windows
```

Close SignalRGB first, because both apps fight over the same devices. Settings
are saved to `%APPDATA%\OpenChroma\settings.json`.

## Current limits

- USB HID devices only. SMBus (RAM/GPU), raw USB, serial and network
  plugins are recognized but not run.
- No fan control, LCD screens, screen capture (Screen Ambience) or audio
  (the `engine.audio`/`engine.zone` objects are zero-filled stubs).
- ARGB channels take a manual LED count, not SignalRGB's component library.
- Layout has position and scale only, no rotation.
- `collection` matching in `set_endpoint` uses the `&colNN` number from the
  path. SignalRGB's exact numbering has not been confirmed.
