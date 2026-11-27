# Changelog

All notable changes to OpenChroma are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - Unreleased

First public beta.

### Added

- English UI with a Portuguese (Brazil) translation, selectable in
  Settings › General › Language.
- Update notifications (daily GitHub releases check, can be turned off) and
  "Copy diagnostics" for bug reports, in Settings › About.
- **Lighting**
  - 25 original effects (Aurora, Plasma, Lava, Campfire, Digital Rain,
    Starry Sky, Rainbow, Solid Color, Heartbeat, Siren and more), each with
    color and speed settings.
  - Sound-reactive effects driven by system audio or the microphone.
  - The `.ocfx` effect format, drawn natively in Dart, plus import of `.ocfx`
    files and HTML canvas effects (WebView2), favorites and rendered covers.
  - Device layout canvas so effects flow across all devices, with automatic
    layout (preview and undo) and zones that can be rotated, flipped and
    identified.
  - Profiles (Gaming, Work, Night, Off) that can turn on automatically while
    a chosen program runs.
  - Reactive light that shows CPU or GPU temperature on the LEDs.
  - Per-device brightness and pausing effects.
- **Devices and drivers**
  - Native drivers built from OpenRGB into `oc_drivers.dll` (~2,160 models
    from 189 families), each controller written on its own thread.
  - JavaScript device plugins (QuickJS) with priority over the built-in
    drivers, live reload, settings, hardware effects (speed, brightness and
    colors), battery levels, USB serial ports, and images, GIFs and live
    sensor values on device screens.
  - Bundled plugins: Sony DualShock 4, ROYUAN keyboards / Attack Shark K86
    (per-key lighting, screen and clock), Logitech G403 HERO, Attack Shark
    X11 and SmartMonitor water cooler screens.
  - Hardware effects picker for built-in drivers and plugins.
  - ARGB helpers: count LEDs by lighting them one by one and find the color
    order with two questions.
  - Battery levels reported by Windows for Bluetooth devices.
  - Screen editor for device screens: edit images and texts before sending.
- **Fans**: motherboard (ITE) and NVIDIA GPU fan control with Silent,
  Balanced and Turbo profiles or custom curves, and pump protection.
- **Monitor**: real-time CPU, GPU, memory, disk and network monitor with
  sortable processes and inspection of past samples from the charts.
- **Diagnostics**: verified CPU, memory, GPU and disk stress tests, hardware
  inventory, blue screen history and recommendations.
- **Alerts**: Windows notifications for overheating, full memory or disks
  and stopped pumps, with an optional red LED flash.
- **AI assistant** for Anthropic, OpenAI and OpenAI-compatible APIs that
  answers with real PC readings, creates effects and explains diagnostics;
  API keys stored with DPAPI.
- **App**: custom title bar, icon rail and dashboard with a live accent
  color, tray mode with low memory use, single instance, start with Windows
  and run as administrator at logon (only for installs in Program Files).
- **Distribution**: Inno Setup installer (per-user, dark branded wizard) that
  installs WebView2 and the PawnIO driver silently, a portable `.zip`,
  bundled Visual C++ runtime and SHA-256 checksums.
- Native crash reports in `%APPDATA%\OpenChroma\crash.log`.

### Security

- Starting as administrator at logon is only offered when the app folder can't
  be modified by non-admin users (Program Files install); the task is
  registered through the Task Scheduler API instead of a temporary XML file.
- User plugins only run after you approve them (SHA-256 per file; changes
  need a new approval while running as administrator). Built-in plugins load
  straight from the app, a stuck plugin is cut off after a timeout, and
  plugins can't open FIDO security keys.
- Diagnostics no longer run PowerShell with names read from crash dumps, and
  only read dumps owned by the system.
- DLLs load only from the app folder and System32; system tools run from
  their absolute paths.
- The disk test uses a random temporary file that can't be redirected.
- Imported HTML effects can't navigate away from their own page, and `.ocfx`
  effects with huge or invalid numbers can't freeze the app.
- The AI assistant refuses plain HTTP except for servers on this PC, doesn't
  follow redirects, and forgets the key when the server address changes.
- The release build pins the PawnIO setup by version and SHA-256 and checks
  the publisher of every bundled installer.

[0.9.0]: https://github.com/Dnowdd/OpenChroma/releases/tag/v0.9.0
