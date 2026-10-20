<#
.SYNOPSIS
  Brings third_party/openrgb up to the latest OpenRGB and checks the result.

.DESCRIPTION
  1. Clones OpenRGB (or uses -Source) and copies the drivers with
     scripts/update-openrgb.py, which re-applies OpenChroma's patches.
  2. Lists files whose license is not GPL-2.0-or-later / GPL-2.0-only, and
     drivers that are new or gone since the last update.
  3. Builds the app (drivers included) and runs every test, including the
     plugin tests.

  Nothing is committed: review `git diff --stat third_party`, try the app with
  the devices you have, then commit.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\update-openrgb.ps1
  powershell -ExecutionPolicy Bypass -File scripts\update-openrgb.ps1 -Source C:\src\OpenRGB
#>
param(
  [string]$Source,
  [string]$Branch = 'master'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

$vendor = Join-Path $root 'third_party\openrgb'
$before = Get-Content (Join-Path $vendor 'UPSTREAM_COMMIT') -ErrorAction SilentlyContinue
$driversBefore = @(Get-ChildItem (Join-Path $vendor 'Controllers') -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)

# ------------------------------------------------------------------ source
if (-not $Source) {
  Step "Downloading OpenRGB ($Branch)"
  $Source = Join-Path $env:TEMP 'openchroma-openrgb'
  if (Test-Path $Source) { Remove-Item $Source -Recurse -Force }
  git clone --depth 1 --branch $Branch https://gitlab.com/CalcProgrammer1/OpenRGB.git $Source
  if ($LASTEXITCODE -ne 0) { throw 'git clone failed.' }
}
$commit = (git -C $Source rev-parse HEAD).Trim()
Write-Host "  $before -> $commit"

Step 'Copying the drivers and applying our patches'
python -I scripts\update-openrgb.py $Source $commit
if ($LASTEXITCODE -ne 0) { throw 'update-openrgb.py failed (see the message above).' }

# ---------------------------------------------------------------- licenses
Step 'Checking licenses'
$odd = Get-ChildItem $vendor -Recurse -Include *.cpp, *.h, *.c, *.hpp |
  Where-Object { $_.FullName -notmatch '\\dependencies\\' } |
  ForEach-Object {
    $head = Get-Content $_.FullName -TotalCount 30 -ErrorAction SilentlyContinue | Out-String
    if ($head -match 'SPDX-License-Identifier:\s*([^\s*|]+)') {
      $id = $Matches[1]
      if ($id -ne 'GPL-2.0-or-later' -and $id -ne 'GPL-2.0-only') {
        '{0}  {1}' -f $id, $_.FullName.Substring($vendor.Length + 1)
      }
    }
  }
if ($odd) {
  Write-Host '  Files under another license (check THIRD_PARTY.md):' -ForegroundColor Yellow
  $odd | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
} else {
  Write-Host '  Every driver file is GPL-2.0-or-later or GPL-2.0-only.'
}

$driversAfter = @(Get-ChildItem (Join-Path $vendor 'Controllers') -Directory | ForEach-Object Name)
$added = $driversAfter | Where-Object { $driversBefore -notcontains $_ }
$removed = $driversBefore | Where-Object { $driversAfter -notcontains $_ }
if ($added) { Write-Host "  New drivers: $($added -join ', ')" }
if ($removed) { Write-Host "  Removed drivers: $($removed -join ', ')" -ForegroundColor Yellow }

# ------------------------------------------------------------- build + test
Step 'Building (the drivers take a while)'
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Build failed: a patch or a new driver needs attention.' }

Step 'Running the tests'
$env:PATH = "$root\build\windows\x64\runner\Release;$env:PATH"
$env:OC_PLUGIN_TEST = '1'
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }

Step 'Done'
git diff --stat --shortstat -- third_party
Write-Host "`nTry the app with your devices, then commit third_party and UPSTREAM_COMMIT." -ForegroundColor Green
