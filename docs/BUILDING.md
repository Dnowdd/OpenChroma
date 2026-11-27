# Building the .exe and publishing a release

## One time: set up the PC

1. **Flutter** 3.47 or newer:
   <https://docs.flutter.dev/get-started/install/windows>. Check it with
   `flutter doctor`.
2. **Visual Studio 2022 or newer** (Community is free) with the **"Desktop
   development with C++"** workload.
3. **Inno Setup 6**, which builds the installer:

   ```powershell
   winget install JRSoftware.InnoSetup
   ```

   Without it the script still creates the portable `.zip`; it just skips
   the installer.
4. **Python 3**, used by the translation and OpenRGB update scripts.

## Running during development

```powershell
flutter pub get
flutter run -d windows
```

The first build is slow (10 to 20 minutes) because it compiles the ~900
driver files in `third_party/openrgb` (`oc_drivers.dll`). Later builds only
recompile what changed.

If you change a translation in `lib/l10n/parts`, regenerate the merged files
and the Dart code:

```powershell
python scripts/merge-l10n.py
flutter gen-l10n
```

## Updating the OpenRGB drivers

The drivers are a copy of the OpenRGB code in `third_party/openrgb`. To bring
in the newest version:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\update-openrgb.ps1
```

The script downloads OpenRGB, copies only what OpenChroma compiles,
re-applies our changes (the `PATCHES` list in `scripts/update-openrgb.py`; if
one no longer applies, it stops and tells you), lists files under another
license and the drivers that were added or removed, builds and runs every
test, including the plugin tests. It doesn't commit: test with the devices
you have, check [THIRD_PARTY.md](../THIRD_PARTY.md) and then commit.

## Building the .exe (the version to publish)

1. Pick the version number in `pubspec.yaml`, on the `version:` line. The
   format is `1.2.3+4`: `1.2.3` is the version users see and `+4` is an
   internal counter that goes up with each build.
2. In PowerShell, in the project folder:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1
   ```

   The script:
   - runs `flutter analyze` and `flutter test` and stops if anything fails;
   - builds the app in release mode with the version from `pubspec.yaml`;
   - gathers the `.exe`, the DLLs (including the Visual C++ ones, so it runs
     on PCs that don't have them) and the data into
     `dist\OpenChroma-<version>\`;
   - downloads the WebView2 bootstrapper and the official PawnIO setup into
     `installer\redist` (once). PawnIO is pinned to a version and SHA-256 in
     the script (bump both together), and both files must carry a valid
     signature from their publisher (namazso.eu / Microsoft);
   - creates the portable `.zip` and the installer;
   - writes the SHA-256 checksums.

   Options: `-Version 1.2.3` uses another version without touching
   `pubspec.yaml`; `-NoInstaller` creates only the `.zip`; `-SkipBuild`
   reuses the last build.

3. The output goes to `dist\`:

   | File | What for |
   |---|---|
   | `OpenChroma-<version>-setup.exe` | Installer. Doesn't ask for administrator rights, creates a Start menu shortcut and installs WebView2 if it's missing. This is what most people should download. |
   | `OpenChroma-<version>-portable.zip` | Portable version: extract and open `openchroma.exe`. |
   | `SHA256SUMS.txt` | The checksums, for anyone who wants to verify the download. |

   The `dist\` folder isn't tracked by git.

Warnings that may show up and are harmless: `Nuget is not installed` and a
CMake warning about `CMP0175` in `webview_windows`.

## Publishing on GitHub

### Automatically (recommended)

The [release workflow](../.github/workflows/release.yml) builds and uploads
everything when a version tag is pushed:

1. Set the version in `pubspec.yaml` and add a `## [x.y.z] - YYYY-MM-DD`
   section to [CHANGELOG.md](../CHANGELOG.md).
2. Commit, then tag and push:

   ```powershell
   git tag v1.2.3
   git push origin main v1.2.3
   ```

3. The workflow checks that the tag matches the `pubspec.yaml` version, runs
   `scripts\build-release.ps1` and creates a **draft** release with the
   installer, the portable `.zip`, `SHA256SUMS.txt` and the CHANGELOG section
   as its notes.
4. Open **Releases** on GitHub, review the draft and click **Publish
   release**.

### Manually

1. Commit the version change and push it: `git push`.
2. On GitHub, open the repository and go to **Releases › Draft a new
   release**.
3. In **Choose a tag**, type `v1.2.3` (the same version) and click **Create
   new tag: v1.2.3 on publish**.
4. Title: `OpenChroma 1.2.3`. In the description, paste the CHANGELOG section
   and a link to the source code of the tag (the GPL requires the source to
   be available).
5. Drag the three files from `dist\` into the attachments area.
6. Click **Publish release**.

The link `https://github.com/Dnowdd/OpenChroma/releases/latest` always points
to the newest version.

## Testing before publishing

- **Portable:** extract the `.zip` into another folder and open
  `openchroma.exe`.
- **Installer, without touching your system:**

  ```powershell
  dist\OpenChroma-1.2.3-setup.exe /VERYSILENT /CURRENTUSER /DIR="$env:TEMP\oc-test"
  & "$env:TEMP\oc-test\unins000.exe" /VERYSILENT
  ```

  Careful: uninstalling deletes the "start with Windows" and "keep running in
  the background" options (`HKCU\Software\OpenChroma`), which are shared with
  your development copy. The settings in `%APPDATA%\OpenChroma` stay.
- **"Clean" PC:** the best test is Windows Sandbox (on Windows Pro). It has no
  Visual C++ or anything else installed, just like the PC of someone
  downloading the app.

## About the SmartScreen warning

Since the `.exe` isn't digitally signed, Windows shows "Windows protected
your PC" the first time. The user clicks **More info › Run anyway**. Getting
rid of the warning requires a code signing certificate (see the
[ROADMAP](../ROADMAP.md)).
