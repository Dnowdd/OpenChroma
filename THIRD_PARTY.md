# Licenses

OpenChroma is free software under the **GNU General Public License, version
2 or (at your option) any later version** (GPL-2.0-or-later). The text is in
[LICENSE](LICENSE).

Since some of the bundled code is GPL-2.0-only (see below), the program
distributed as a whole follows the GPL-2.0.

## Bundled third-party code

| Component | Where | License |
|---|---|---|
| [OpenRGB](https://gitlab.com/CalcProgrammer1/OpenRGB): device drivers and their framework | `third_party/openrgb` (commit in `UPSTREAM_COMMIT`) | GPL-2.0-or-later; some files GPL-2.0-only (Gigabyte Fusion2 USB, HID LampArray, Lian Li Uni Hub SL, Mountain 60) |
| Plugins in `assets/plugins` (DualShock 4, ROYUAN, Logitech G403 HERO), based on the OpenRGB drivers | `assets/plugins` | GPL-2.0-or-later |
| QuickJS (via flutter_js), which runs the plugins | `flutter_js` package | MIT |
| hidapi (OpenRGB's build with hotplug) | `third_party/openrgb/dependencies/hidapi-hotplug-win` | BSD (one of the licenses offered by hidapi) |
| libusb 1.0.27 | `third_party/openrgb/dependencies/libusb-1.0.27` | LGPL-2.1-or-later |
| PawnIOLib and PawnIO modules | `third_party/openrgb/dependencies/PawnIO`, `assets/pawnio` | LGPL-2.1-or-later |
| Official PawnIO driver installer (`PawnIO_setup.exe`, unmodified), inside the OpenChroma installer | downloaded by `scripts/build-release.ps1` into `installer/redist` | © namazso; "This installer can be redistributed unmodified." |
| nlohmann/json | `third_party/openrgb/dependencies/json` | MIT |
| CRCpp | `third_party/openrgb/dependencies/CRCpp` | BSD-3-Clause |
| stb_image_write | `third_party/openrgb/dependencies/stb` | MIT / public domain |
| AMD Display Library SDK (headers) | `third_party/openrgb/dependencies/display-library` | MIT |
| NVIDIA API (declarations used by OpenRGB) | `third_party/openrgb/dependencies/NVFC` | GPL-2.0-or-later (part of OpenRGB) |

What was **intentionally left out**: OpenRGB's E1.31 driver (`libe131` is
Apache-2.0, incompatible with GPL-2.0-only), the Philips Hue and Nanoleaf
drivers (they depend on networking libraries we don't distribute) and the
QMK drivers (they depend on Qt).

OpenChroma's changes to the OpenRGB code live in
`scripts/update-openrgb.py` (the `PATCHES` list) and are marked with
`OpenChroma:` in the files.

OpenChroma doesn't use or distribute any SignalRGB code.

## Prebuilt binaries

These binaries are committed or pulled in prebuilt and ship with the app.
They come unchanged from the OpenRGB tree at the commit in
`third_party/openrgb/UPSTREAM_COMMIT` (or from the pub package named).
Check the hashes after updating any of them.

| File | Source | SHA-256 |
|---|---|---|
| `third_party/openrgb/dependencies/PawnIO/PawnIOLib.dll` | OpenRGB tree ([PawnIO](https://github.com/namazso/PawnIO)) | `c6e7c2f54643ef9cb51b9a3ec7b0efc9e204803c206f33014e39f281546ea9b4` |
| `third_party/openrgb/dependencies/hidapi-hotplug-win/x64/hidapi-hotplug.dll` | OpenRGB tree (hidapi 0.15.0 with hotplug) | `263a662b014a7082871bb3e46f4d3c4790d7ed253768dcd585264fd598892dfb` |
| `third_party/openrgb/dependencies/libusb-1.0.27/VS2019/MS64/dll/libusb-1.0.dll` | OpenRGB tree ([libusb 1.0.27](https://github.com/libusb/libusb/releases/tag/v1.0.27)) | `a8c91f0ff68fb7802a9f4416728f0eeb4d99af4ceaa4ef7dfe9374e76e375018` |
| `quickjs_c_bridge.dll` | pub package [`flutter_js` 0.8.7](https://pub.dev/packages/flutter_js) (`windows/shared`) | `e2051274a1d7599d131d45b96c7cc53519a9009bf43a802b922f73031d3d3b4b` |
| `PawnIO_setup.exe` (inside the installer only) | [PawnIO.Setup 2.2.0](https://github.com/namazso/PawnIO.Setup/releases/tag/2.2.0), pinned in `scripts/build-release.ps1` | `1f519a22e47187f70a1379a48ca604981c4fcf694f4e65b734aaa74a9fba3032` |
