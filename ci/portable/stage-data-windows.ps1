# Merge TOPP tools, OpenMS data, managed Thermo support, licenses, and provenance.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$bin = Join-Path $env:GUI_STAGE "bin"
New-Item -ItemType Directory -Path $bin -Force | Out-Null
Copy-Item (Join-Path $env:OPENMS_INSTALL "bin/*") $bin -Recurse -Force

$shareDestination = Join-Path $env:GUI_STAGE "share/OpenMS"
New-Item -ItemType Directory -Path $shareDestination -Force | Out-Null
Copy-Item (Join-Path $env:OPENMS_INSTALL "share/OpenMS/*") `
  $shareDestination -Recurse -Force

$managedSource = Join-Path $env:OPENMS_INSTALL "lib/openms_thermo_bridge/managed"
$managedDestination = Join-Path $bin "managed"
if (-not (Test-Path $managedSource)) {
  throw "The installed OpenMS Thermo managed bridge was not found."
}
Copy-Item $managedSource $managedDestination -Recurse -Force

$licenseRoot = Join-Path $env:GUI_STAGE "share/licenses"
New-Item -ItemType Directory -Path $licenseRoot -Force | Out-Null
Copy-Item (Join-Path $env:OPENMS_INSTALL "share/OpenMS/LICENSES/OpenMS-BSD-3-Clause.txt") `
  (Join-Path $licenseRoot "OpenMS-BSD-3-Clause.txt")
Copy-Item (Join-Path $env:OPENMS_CONTRIB_SOURCE "LICENSE.md") `
  (Join-Path $licenseRoot "OpenMS-contrib.md")
Copy-Item (Join-Path $env:OPENMS_CONTRIB_SOURCE "licensetexts") `
  (Join-Path $licenseRoot "OpenMS-contrib-licenses") -Recurse
$thermoLicense = Join-Path $env:OPENMS_INSTALL "share/OpenMS/LICENSES/ThermoRawFileReader-License.doc"
if (Test-Path $thermoLicense) { Copy-Item $thermoLicense $licenseRoot }
if (Test-Path (Join-Path $env:QT_ROOT_DIR "LICENSES")) {
  Copy-Item (Join-Path $env:QT_ROOT_DIR "LICENSES") `
    (Join-Path $licenseRoot "Qt") -Recurse
}

$buildInfo = @"
OpenMS Legacy GUI portable Windows build
GUI commit: $env:GUI_SHA
OpenMS ref: $env:OPENMS_REF (pinned)
OpenMS commit: $env:OPENMS_SHA
OpenMS contrib release: $env:CONTRIB_TAG
OpenMS WITH_GUI: OFF
OpenMS BUILD_TOPP_TOOLS: ON
OpenMS WITH_THERMO_RAW: ON
OpenMS WITH_OPENTIMS: ON
OpenMS OpenMP: ON
Qt: $env:QT_VERSION (win64_msvc2022_64)
.NET runtime: $env:DOTNET_RUNTIME_VERSION (hostfxr $env:DOTNET_FXR_VERSION, x64, app-local)
Architecture: x64
Built at: $((Get-Date).ToUniversalTime().ToString("o"))
"@
$buildInfo.Trim() | Set-Content `
  (Join-Path $env:GUI_STAGE "BUILD-INFO.txt") -Encoding utf8
"Run bin\TOPPView.exe, bin\TOPPAS.exe, or bin\INIFileEditor.exe. No installation is required." | `
  Set-Content (Join-Path $env:GUI_STAGE "README-WINDOWS.txt") -Encoding utf8
