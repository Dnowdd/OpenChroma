# Licenças

O OpenChroma é software livre sob a **GNU General Public License, versão 2
ou (a seu critério) qualquer versão posterior** (GPL-2.0-or-later). O texto
está em [LICENSE](LICENSE).

Como parte do código incluído é GPL-2.0-only (veja abaixo), o programa
distribuído como um todo segue a GPL-2.0.

## Código de terceiros incluído

| Componente | Onde | Licença |
|---|---|---|
| [OpenRGB](https://gitlab.com/CalcProgrammer1/OpenRGB): drivers de dispositivos e o framework deles | `third_party/openrgb` (commit em `UPSTREAM_COMMIT`) | GPL-2.0-or-later; alguns arquivos GPL-2.0-only (Gigabyte Fusion2 USB, HID LampArray, Lian Li Uni Hub SL, Mountain 60) |
| Plugins em `assets/plugins` (DualShock 4, ROYUAN, Logitech G403 HERO), baseados nos drivers do OpenRGB | `assets/plugins` | GPL-2.0-or-later |
| QuickJS (via flutter_js), que roda os plugins | pacote `flutter_js` | MIT |
| hidapi (build do OpenRGB com hotplug) | `third_party/openrgb/dependencies/hidapi-hotplug-win` | BSD (uma das licenças oferecidas pelo hidapi) |
| libusb 1.0.27 | `third_party/openrgb/dependencies/libusb-1.0.27` | LGPL-2.1-or-later |
| PawnIOLib e módulos PawnIO | `third_party/openrgb/dependencies/PawnIO`, `assets/pawnio` | LGPL-2.1-or-later |
| nlohmann/json | `third_party/openrgb/dependencies/json` | MIT |
| CRCpp | `third_party/openrgb/dependencies/CRCpp` | BSD-3-Clause |
| stb_image_write | `third_party/openrgb/dependencies/stb` | MIT / domínio público |
| AMD Display Library SDK (headers) | `third_party/openrgb/dependencies/display-library` | MIT |
| NVIDIA API (declarações usadas pelo OpenRGB) | `third_party/openrgb/dependencies/NVFC` | GPL-2.0-or-later (parte do OpenRGB) |

O que **não** foi incluído de propósito: o driver E1.31 do OpenRGB (a
`libe131` é Apache-2.0, incompatível com a GPL-2.0-only), os drivers Philips
Hue e Nanoleaf (dependem de bibliotecas de rede que não distribuímos) e os
drivers QMK (dependem do Qt).

As mudanças do OpenChroma no código do OpenRGB ficam em
`scripts/update-openrgb.py` (lista `PATCHES`) e estão marcadas com
`OpenChroma:` nos arquivos.

O OpenChroma não usa nem distribui código do SignalRGB.
