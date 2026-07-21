# Fail-closed Windows package verification against app-local dependencies only.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$bin = Join-Path $env:GUI_STAGE "bin"
$requiredPaths = @(
  "TOPPView.exe", "TOPPAS.exe", "INIFileEditor.exe", "ExecutePipeline.exe",
  "ImageCreator.exe", "FileInfo.exe", "OpenMS.dll", "OpenMSLegacyGUI.dll",
  "Qt6Core.dll", "Qt6Gui.dll", "Qt6Widgets.dll", "Qt6Svg.dll",
  "Qt6OpenGLWidgets.dll", "vcruntime140.dll", "msvcp140.dll", "vcomp140.dll",
  "openms_thermo_bridge.dll", "nethost.dll", "platforms/qwindows.dll",
  "managed/ThermoWrapperManaged.dll",
  "managed/ThermoWrapperManaged.runtimeconfig.json"
) | ForEach-Object { Join-Path $bin $_ }
$requiredPaths += @(
  (Join-Path $env:GUI_STAGE "dotnet/dotnet.exe"),
  (Join-Path $env:GUI_STAGE "dotnet/host/fxr/$env:DOTNET_FXR_VERSION/hostfxr.dll"),
  (Join-Path $env:GUI_STAGE "dotnet/shared/Microsoft.NETCore.App/$env:DOTNET_RUNTIME_VERSION/System.Private.CoreLib.dll"),
  (Join-Path $env:GUI_STAGE "share/OpenMS/CHEMISTRY/unimod.xml"),
  (Join-Path $env:GUI_STAGE "share/OpenMS/GUISTYLE/qtStyleSheet.qss")
)
foreach ($path in $requiredPaths) {
  if (-not (Test-Path $path)) { throw "Portable package is missing: $path" }
}

$savedPath = $env:PATH
$savedDotnetRoot = $env:DOTNET_ROOT
$savedOpenmsDataPath = $env:OPENMS_DATA_PATH
$savedParserMode = $env:QT_COMMAND_LINE_PARSER_NO_GUI_MESSAGE_BOXES

# OpenMS probes compiled-in data directories before anything executable-relative.
# On Windows the compiled-in *install* path is skipped, but the compiled-in build
# path ($OPENMS_SOURCE/share/OpenMS) still exists on this runner and would win over
# the packaged tree -- masking a package that cannot find its own data, and
# tripping the bundled-tree check in configurePortableEnvironment(). Hide both so
# the executables have nothing to fall back on but the archive itself.
$hiddenDataTrees = @()
function Restore-DataTrees {
  foreach ($tree in $script:hiddenDataTrees) {
    $hidden = "$tree.hidden-for-verify"
    if (Test-Path $hidden) { Move-Item -LiteralPath $hidden -Destination $tree -Force }
  }
  $script:hiddenDataTrees = @()
}

try {
  foreach ($tree in @((Join-Path $env:OPENMS_INSTALL "share/OpenMS"),
                      (Join-Path $env:OPENMS_SOURCE "share/OpenMS"))) {
    if (Test-Path $tree) {
      Move-Item -LiteralPath $tree -Destination "$tree.hidden-for-verify" -Force
      $hiddenDataTrees += $tree
    }
  }
  if ($hiddenDataTrees.Count -ne 2) {
    throw "Expected to hide 2 compiled-in OpenMS data trees, hid $($hiddenDataTrees.Count)."
  }

  $env:PATH = "$bin;$env:SystemRoot/System32;$env:SystemRoot"
  $env:DOTNET_ROOT = Join-Path $env:GUI_STAGE "dotnet"
  $env:OPENMS_DATA_PATH = Join-Path $env:RUNNER_TEMP "nonexistent-openms-data"
  $env:QT_COMMAND_LINE_PARSER_NO_GUI_MESSAGE_BOXES = "1"
  foreach ($app in @("TOPPView", "TOPPAS", "INIFileEditor", "ExecutePipeline", "ImageCreator")) {
    $process = Start-Process -FilePath (Join-Path $bin "$app.exe") `
      -ArgumentList "--help" -PassThru
    if (-not $process.WaitForExit(60000)) {
      Stop-Process -Id $process.Id -Force
      throw "$app portable smoke test timed out."
    }
    if ($process.ExitCode -ne 0) {
      throw "$app portable smoke test exited with $($process.ExitCode)."
    }
  }

  Restore-DataTrees

  # FileInfo comes from the headless OpenMS build and does not contain the GUI
  # package bootstrap, so verify it against the explicit staged data path.
  $env:OPENMS_DATA_PATH = Join-Path $env:GUI_STAGE "share/OpenMS"
  $fileInfoProcess = Start-Process -FilePath (Join-Path $bin "FileInfo.exe") `
    -ArgumentList "--help" -PassThru
  if (-not $fileInfoProcess.WaitForExit(60000)) {
    Stop-Process -Id $fileInfoProcess.Id -Force
    throw "FileInfo portable smoke test timed out."
  }
  if ($fileInfoProcess.ExitCode -ne 0) {
    throw "FileInfo portable smoke test exited with $($fileInfoProcess.ExitCode)."
  }

  $smokeExecutable = Join-Path $bin "openms-legacy-gui-thermo-smoke.exe"
  $smokeProcess = Start-Process -FilePath $smokeExecutable `
    -ArgumentList $env:THERMO_TEST_DATA -NoNewWindow -PassThru
  if (-not $smokeProcess.WaitForExit(300000)) {
    Stop-Process -Id $smokeProcess.Id -Force
    throw "Packaged Thermo RAW smoke test timed out."
  }
  if ($smokeProcess.ExitCode -ne 0) {
    throw "Packaged Thermo RAW smoke test exited with $($smokeProcess.ExitCode)."
  }
  Remove-Item $smokeExecutable -Force
}
finally {
  Restore-DataTrees
  $env:PATH = $savedPath
  $env:DOTNET_ROOT = $savedDotnetRoot
  $env:OPENMS_DATA_PATH = $savedOpenmsDataPath
  $env:QT_COMMAND_LINE_PARSER_NO_GUI_MESSAGE_BOXES = $savedParserMode
}
