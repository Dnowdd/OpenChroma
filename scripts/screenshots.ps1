param([string[]] $TestArgs = @())

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path ([IO.Path]::GetTempPath()) ('openchroma-shots-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $data | Out-Null
$oldAppData = $env:APPDATA
$oldScreenshots = $env:OC_SCREENSHOTS
try {
  $env:APPDATA = $data
  $env:OC_SCREENSHOTS = '1'
  Push-Location $root
  flutter test test/screenshots --dart-define=OC_VERSION=0.9.0 @TestArgs
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
  $env:APPDATA = $oldAppData
  $env:OC_SCREENSHOTS = $oldScreenshots
  Remove-Item $data -Recurse -Force -ErrorAction SilentlyContinue
}
