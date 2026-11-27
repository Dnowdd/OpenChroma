# What's missing in OpenChroma

A list of what doesn't exist yet or is incomplete, roughly in priority order.
Update it when something gets done.

## 1. Drivers

The drivers come from OpenRGB, compiled into the app (`windows/drivers` and
`third_party/openrgb`), plus OpenChroma's JavaScript plugins
([docs/PLUGINS.md](docs/PLUGINS.md)). OpenChroma doesn't depend on or talk
to SignalRGB or an installed OpenRGB.

- [x] Native core with the OpenRGB drivers and our own API
      (`oc_drivers.dll`).
- [x] Remove everything from SignalRGB.
- [x] GPL-2.0-or-later license.
- [x] Our own JavaScript plugin format, with priority over the built-in
      drivers.
- [x] First plugins migrated and improved: DualShock 4 (with battery),
      ROYUAN keyboards (with a write limit) and Logitech G403 HERO (without
      writing to the mouse's memory).
- [x] Battery of wireless devices (plugins).
- [x] Pick one of the hardware's own effects instead of the app's colors.
- [x] Adjust speed, brightness, direction and colors of hardware effects
      (built-in drivers and plugins).
- [x] OpenRGB update routine (`scripts/update-openrgb.ps1`).
- [x] Reload plugins without restarting the app (automatically when the
      `.js` is saved).
- [x] ROYUAN keyboard with live color, without flickering (tested on the
      Attack Shark K86, at 30 updates per second).
- [x] Battery that Windows already knows about (Bluetooth): shown on the
      device when it also has lighting, and in an "Other wireless" list when
      it doesn't.
- [x] New plugin: Attack Shark X11 (lighting, mouse effects and battery,
      wired and through the 2.4 GHz receiver), protocol learned from the
      official app and tested on the mouse.
- [x] All of OpenRGB's Windows drivers built in (~2,160 models from 189
      families, including Razer, Corsair, SteelSeries, Logitech and HyperX),
      except the 4 in section 2.
- [ ] Battery of Razer, Corsair, SteelSeries and HyperX wireless mice and
      headsets (lighting already works through the built-in drivers;
      OpenRGB doesn't read the battery). **Needs the device to test.**
- [x] Attack Shark K86 key by key, with the real position of each key:
      static effects show key by key (written to the keyboard's image 3) and
      moving ones go as a single color, because the keyboard doesn't take
      live per-key color (not even the official app does that). The
      keyboard's 3 images also show up as its effects.
- [x] K86 screen: send an image or GIF (Screen tab on the device), and the
      keyboard clock set automatically.

## 2. Devices that don't work yet

- [ ] Network drivers that were left out: Philips Hue, Nanoleaf (they need
      TLS/mDNS) and E1.31 (`libe131` is Apache-2.0, incompatible with
      GPL-2.0). E1.31 is a simple protocol and could be rewritten.
- [ ] QMK/VIA keyboards (the OpenRGB driver depends on Qt).
- [ ] LCD screens of liquid coolers and cases (beyond the ones plugins
      already drive, such as the SmartMonitor cooler).

## 3. Lighting

- [ ] Effect that copies the screen colors (ambilight).
- [ ] Visual `.ocfx` effect editor, without writing JSON.
- [x] Rotation in the layout (zones can be rotated and flipped).
- [ ] ARGB component library: pick "120 mm fan with 16 LEDs" instead of
      typing the LED count.
- [x] Switch profiles automatically when a game or program opens (and
      switch back when it closes).
- [ ] More original effects (every OpenChroma effect is exclusive; never
      copy effects from other apps).

## 4. Fans and sensors

- [ ] More motherboard chips beyond ITE (Nuvoton, Fintek).
- [ ] AMD and Intel graphics card fans (only NVIDIA today).
- [ ] Use the liquid cooler's coolant temperature in fan curves.

## 5. App

- [ ] **Universal macros**: record and trigger keyboard and mouse macros from
      the app itself, for any brand, without relying on each device's memory.
- [x] Update notifications: a daily check of the GitHub releases (can be
      turned off) with a banner and a download link.
- [ ] **Automatic updates**: download and install the new version from the
      app itself.
- [ ] **Code signing** of the `.exe` and the installer, so Windows doesn't
      show the SmartScreen warning ("Windows protected your PC").
- [x] App in English (default), with Portuguese (Brazil) as an option.
- [x] Automatic build on GitHub Actions: compile, run the tests and attach
      the files to the release when a tag is created.
- [ ] Windows ARM64 version.
- [x] "Copy diagnostics" in Settings › About, to paste into an issue.
- [ ] Optional error reporting (today crashes only go to
      `%APPDATA%\OpenChroma\crash.log`).
