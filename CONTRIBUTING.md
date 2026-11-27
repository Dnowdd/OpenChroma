# Contributing to OpenChroma

Thanks for helping! Bug reports, device reports, translations, plugins and
code are all welcome. This is a hobby project maintained in spare time, so
reviews can take a while.

By contributing, you agree that your contribution is licensed under the
project's license, GPL-2.0-or-later ([LICENSE](LICENSE)), and you follow the
[Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

- **Bugs and ideas:** open an [issue](https://github.com/Dnowdd/OpenChroma/issues/new/choose)
  using one of the forms. Search first to avoid duplicates.
- **Security problems:** don't open a public issue; see [SECURITY.md](SECURITY.md).
- **Bigger changes** (new features, refactors, new dependencies): open an
  issue or a discussion first so we can agree on the approach before you
  spend time on it.

## Development setup

You need:

- Windows 10 or 11, 64-bit (OpenChroma is Windows-only).
- [Flutter](https://docs.flutter.dev/get-started/install/windows) **3.47 or
  newer** (stable channel). Check with `flutter doctor`.
- **Visual Studio 2022** (or newer) with the **"Desktop development with
  C++"** workload.
- **Python 3**, for the translation and OpenRGB scripts.
- Optional: [Inno Setup 6](https://jrsoftware.org/isinfo.php) to build the
  installer (see [docs/BUILDING.md](docs/BUILDING.md)).

```powershell
git clone https://github.com/Dnowdd/OpenChroma.git
cd OpenChroma
flutter pub get
flutter run -d windows
```

The first build takes 10 to 20 minutes because it compiles the ~900 OpenRGB
driver files into `oc_drivers.dll`. Later builds are incremental.

Features that touch the SMBus, CPU temperature or motherboard fans need the
[PawnIO](https://pawnio.eu) driver and administrator mode.

## Project layout

See [How it works](README.md#how-it-works) in the README for a map of
`lib/src`, `windows/` and `third_party/`. In short:

- `lib/src/` — the Dart app (engine, drivers bridge, plugins, effects, fans,
  monitor, UI…).
- `lib/l10n/` — translations.
- `windows/runner/` — native code (monitor, fans, stress tests, tray,
  elevation).
- `windows/drivers/` and `third_party/openrgb/` — the native drivers DLL.
- `assets/plugins/` and `assets/effects/` — bundled plugins and effects.
- `test/` — tests.

## Running the tests

```powershell
flutter analyze
flutter test
```

The plugin tests (`test/plugins_test.dart`) need the QuickJS DLL from a
release build, so they are skipped unless you enable them:

```powershell
flutter build windows --release
$env:PATH = "$PWD\build\windows\x64\runner\Release;$env:PATH"
$env:OC_PLUGIN_TEST = "1"
flutter test
```

CI runs all of the above on every pull request, including the plugin tests.

## Code style

- Format with `dart format lib test`. CI fails if the code isn't formatted.
- `flutter analyze` must report no issues.
- **No comments, except critical, non-obvious ones.** Write code that
  explains itself through names and structure. A comment is only acceptable
  when someone would otherwise break something: a workaround for an external
  bug, a security invariant, a mandatory ordering. Keep it to one short line.
  No commented-out code, no `TODO`s, no docstrings that restate the code.
- Code, identifiers and commit messages are in English.
- UI text never goes straight into widgets: add it to the translation files
  (see below).
- Add or update tests for the behavior you change.

## Adding a device plugin

Most new devices can be supported with a JavaScript plugin, without touching
native code. Read [docs/PLUGINS.md](docs/PLUGINS.md), look at the bundled
plugins in [`assets/plugins`](assets/plugins) and add a test to
`test/plugins_test.dart` that checks the bytes your plugin sends.

Don't have the code but have the device? Open a
[device request](https://github.com/Dnowdd/OpenChroma/issues/new?template=device_request.yml).

## Adding or changing translations

The app is in English (the source language) and Portuguese (Brazil).
Strings live in ARB files split by feature group:

```
lib/l10n/parts/<group>_en.arb   English (source)
lib/l10n/parts/<group>_pt.arb   Portuguese
```

After editing them, merge the parts and regenerate the Dart code:

```powershell
python scripts/merge-l10n.py
flutter gen-l10n
```

Commit the parts **and** the generated files (`lib/l10n/app_*.arb` and
`lib/l10n/gen/`); CI checks that they are up to date. Every key must exist
in English; `merge-l10n.py` lists Portuguese keys that are still missing.

To add a new language, create `<group>_<locale>.arb` files for every group,
add the locale to `scripts/merge-l10n.py`, and open a pull request so the
language can be added to the selector in Settings.

## Updating the OpenRGB drivers

```powershell
powershell -ExecutionPolicy Bypass -File scripts\update-openrgb.ps1
```

The script pulls the latest OpenRGB, re-applies OpenChroma's patches (the
`PATCHES` list in `scripts/update-openrgb.py`), reports license changes and
added or removed drivers, builds, and runs every test. Review
`git diff --stat third_party`, check [THIRD_PARTY.md](THIRD_PARTY.md), try
the app with your devices, and then open a pull request. Details are in
[docs/BUILDING.md](docs/BUILDING.md).

## Hardware safety

OpenChroma writes to real hardware: USB devices, the SMBus, fan
controllers. A bad write can, in rare cases, damage a device. When you work
on anything that writes to hardware:

- Test carefully, on hardware you own, and start with the smallest change.
- Never bypass a limit that protects a device (upload sizes, frame counts,
  write rates, minimum fan or pump speeds), even if it seems too strict.
- Don't write to a device's persistent memory every frame.
- Don't send bytes whose meaning you don't know; prefer known values.
- Say in the pull request which hardware you tested on.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/), like the
existing history:

```
feat(lighting): rotate, flip and identify layout zones
fix(drivers): write the latest pending frame after waiting for the bus
perf(plugins): store shared live value glyphs once in cooler themes
docs: document the plugin format and the openrgb update routine
```

- Types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`,
  `chore`, `style`.
- Scope: the area you touched (`lighting`, `devices`, `plugins`, `drivers`,
  `monitor`, `fans`, `ui`, `installer`…).
- Lowercase, imperative mood, no trailing period, describe the effect.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Make focused changes: one topic per pull request.
3. Run `dart format lib test`, `flutter analyze` and `flutter test` (and the
   plugin tests if you touched plugins or drivers).
4. Update the docs and [CHANGELOG.md](CHANGELOG.md) (in the topmost, unreleased section) when
   users would notice the change.
5. Open the pull request and fill in the template. Include screenshots for UI
   changes and the hardware you tested on for device changes.

CI must pass before a pull request is merged.
