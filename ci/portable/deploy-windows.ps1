# Deploy all executable dependency roots, Qt plugins, the MSVC CRT, and OpenMP.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$bin = Join-Path $env:GUI_STAGE "bin"
$smoke = Get-ChildItem $env:GUI_BUILD -Filter "openms-legacy-gui-thermo-smoke.exe" `
  -File -Recurse | Select-Object -First 1
if (-not $smoke) { throw "Thermo RAW smoke probe was not built." }
Copy-Item $smoke.FullName (Join-Path $bin "openms-legacy-gui-thermo-smoke.exe") -Force

$hostPackRoot = Join-Path ${env:ProgramFiles} `
  "dotnet/packs/Microsoft.NETCore.App.Host.win-x64"
$nethostDirectory = $null
if (Test-Path $hostPackRoot) {
  $nethostDirectory = Get-ChildItem $hostPackRoot -Directory |
    Sort-Object { [version]$_.Name } -Descending |
    ForEach-Object { Join-Path $_.FullName "runtimes/win-x64/native" } |
    Where-Object { Test-Path (Join-Path $_ "nethost.dll") } |
    Select-Object -First 1
}
if (-not $nethostDirectory) {
  throw "No .NET host pack with nethost.dll was found under $hostPackRoot"
}

$executables = Get-ChildItem $bin -Filter "*.exe" -File |
  ForEach-Object { $_.FullName }
$searchDirectories = @(
  $bin,
  (Join-Path $env:OPENMS_INSTALL "bin"),
  (Join-Path $env:OPENMS_INSTALL "lib"),
  $nethostDirectory,
  (Join-Path $env:OPENMS_CONTRIB "bin"),
  (Join-Path $env:OPENMS_CONTRIB "lib"),
  (Join-Path $env:QT_ROOT_DIR "bin")
) | Where-Object { Test-Path $_ }

$deployArguments = @(
  "-DEXECUTABLES=$($executables -join ';')",
  "-DDESTINATION=$bin",
  "-DSEARCH_DIRECTORIES=$($searchDirectories -join ';')",
  "-P",
  (Join-Path $env:GITHUB_WORKSPACE "cmake/DeployRuntimeDependencies.cmake")
)
& cmake @deployArguments
if ($LASTEXITCODE -ne 0) { throw "Runtime dependency collection failed." }

$windeployqt = Join-Path $env:QT_ROOT_DIR "bin/windeployqt.exe"
foreach ($app in @("TOPPView", "TOPPAS", "INIFileEditor", "ExecutePipeline", "ImageCreator")) {
  & $windeployqt --release --no-translations --no-compiler-runtime `
    (Join-Path $bin "$app.exe")
  if ($LASTEXITCODE -ne 0) { throw "windeployqt failed for $app." }
}

$redistRoots = [System.Collections.Generic.List[string]]::new()
if ($env:VCToolsRedistDir -and (Test-Path $env:VCToolsRedistDir)) {
  $redistRoots.Add($env:VCToolsRedistDir)
}
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio/Installer/vswhere.exe"
if (Test-Path $vswhere) {
  $vsInstall = (& $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath).Trim()
  if ($vsInstall) {
    Get-ChildItem (Join-Path $vsInstall "VC/Redist/MSVC") -Directory |
      Sort-Object Name -Descending |
      ForEach-Object { $redistRoots.Add($_.FullName) }
  }
}

$crtDirectory = $null
$openmpDirectory = $null
foreach ($root in $redistRoots) {
  $x64Root = Join-Path $root "x64"
  if (-not (Test-Path $x64Root)) { continue }
  $crt = Get-ChildItem $x64Root -Directory -Filter "Microsoft.VC*.CRT" |
    Sort-Object Name -Descending | Select-Object -First 1
  $openmp = Get-ChildItem $x64Root -Directory -Filter "Microsoft.VC*.OpenMP" |
    Sort-Object Name -Descending | Select-Object -First 1
  if ($crt -and $openmp) {
    $crtDirectory = $crt
    $openmpDirectory = $openmp
    break
  }
}
if (-not $crtDirectory) { throw "Could not locate the Visual C++ x64 redistributable DLLs." }
if (-not $openmpDirectory) { throw "Could not locate the Visual C++ x64 OpenMP runtime DLLs." }
Copy-Item (Join-Path $crtDirectory.FullName "*.dll") $bin -Force
Copy-Item (Join-Path $openmpDirectory.FullName "*.dll") $bin -Force
