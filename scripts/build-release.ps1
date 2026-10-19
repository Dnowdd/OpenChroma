<#
.SYNOPSIS
  Builds an OpenChroma release: the portable .zip and the Windows installer.

.DESCRIPTION
  1. Builds the Flutter app in release mode with the version from
     pubspec.yaml (or -Version).
  2. Copies the files the app needs into dist\OpenChroma-<version>\ and zips
     them as dist\OpenChroma-<version>-portable.zip.
  3. Compiles installer\openchroma.iss with Inno Setup into
     dist\OpenChroma-<version>-setup.exe (skipped with -NoInstaller, or when
     Inno Setup is not installed).
  4. Writes dist\SHA256SUMS.txt.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1
  powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1 -Version 1.2.0
#>
param(
  [string]$Version,
  [switch]$NoInstaller,
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

# ------------------------------------------------------------------ version
$pubspec = Get-Content (Join-Path $root 'pubspec.yaml') -Raw
if (-not $Version) {
  if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(\+([0-9]+))?') {
    throw 'Could not read the version from pubspec.yaml.'
  }
  $Version = $Matches[1]
}
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
  throw "Version must look like 1.2.3 (got '$Version')."
}
Write-Host "OpenChroma $Version" -ForegroundColor Green

$dist = Join-Path $root 'dist'
$app = Join-Path $dist "OpenChroma-$Version"
$release = Join-Path $root 'build\windows\x64\runner\Release'

# -------------------------------------------------------------------- build
if (-not $SkipBuild) {
  Step 'Checking the code'
  flutter pub get | Out-Null
  flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze found problems.' }
  flutter test
  if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }

  Step 'Building the app (release)'
  flutter build windows --release --build-name=$Version "--dart-define=OC_VERSION=$Version"
  if ($LASTEXITCODE -ne 0) { throw 'flutter build failed.' }
}
if (-not (Test-Path (Join-Path $release 'openchroma.exe'))) {
  throw "No build found in $release."
}

# ------------------------------------------------------------------ package
Step 'Collecting files'
if (Test-Path $app) { Remove-Item $app -Recurse -Force }
New-Item -ItemType Directory -Force $app | Out-Null
# Linker leftovers are not needed to run.
Copy-Item (Join-Path $release '*') $app -Recurse -Exclude '*.exp', '*.lib', '*.pdb'
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  if (-not (Test-Path (Join-Path $app $dll))) {
    throw "$dll is missing from the build; see windows/CMakeLists.txt."
  }
}
Copy-Item (Join-Path $root 'LICENSE') $app -ErrorAction SilentlyContinue
Copy-Item (Join-Path $root 'assets\pawnio\COPYING.txt') (Join-Path $app 'PawnIO-modules-COPYING.txt')

Step 'Creating the portable .zip'
$zip = Join-Path $dist "OpenChroma-$Version-portable.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $app '*') -DestinationPath $zip -CompressionLevel Optimal
Write-Host "  $zip"

# ---------------------------------------------------------------- installer
$setup = $null
if (-not $NoInstaller) {
  Step 'Building the installer'
  $iscc = @(
    (Get-Command iscc.exe -ErrorAction SilentlyContinue).Source,
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
  ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

  if (-not $iscc) {
    Write-Host '  Inno Setup 6 not found, so no installer this time.' -ForegroundColor Yellow
    Write-Host '  Install it with:  winget install JRSoftware.InnoSetup' -ForegroundColor Yellow
  } else {
    # The WebView2 bootstrapper (redistributable, ~2 MB) installs the runtime
    # on PCs that lack it.
    $redist = Join-Path $root 'installer\redist'
    $webview = Join-Path $redist 'MicrosoftEdgeWebview2Setup.exe'
    if (-not (Test-Path $webview)) {
      New-Item -ItemType Directory -Force $redist | Out-Null
      Write-Host '  Downloading the WebView2 bootstrapper'
      Invoke-WebRequest 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $webview -UseBasicParsing
    }
    & $iscc /Q "/DAppVersion=$Version" "/DSourceDir=$app" "/DOutputDir=$dist" (Join-Path $root 'installer\openchroma.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Inno Setup failed.' }
    $setup = Join-Path $dist "OpenChroma-$Version-setup.exe"
    Write-Host "  $setup"
  }
}

# ---------------------------------------------------------------- checksums
Step 'Writing checksums'
$sums = foreach ($f in @($zip, $setup) | Where-Object { $_ }) {
  '{0}  {1}' -f (Get-FileHash $f -Algorithm SHA256).Hash.ToLower(), (Split-Path $f -Leaf)
}
$sums | Set-Content (Join-Path $dist 'SHA256SUMS.txt') -Encoding ascii
$sums | ForEach-Object { Write-Host "  $_" }

Write-Host "`nDone. Upload the files in dist\ to the GitHub release v$Version." -ForegroundColor Green
