#!/usr/bin/env bash
# Fail-closed macOS package verification.
# Required: GUI_STAGE RUNNER_TEMP THERMO_TEST_DATA DOTNET_FXR_VERSION
#           DOTNET_RUNTIME_VERSION
set -eo pipefail

bin="$GUI_STAGE/bin"
for app in TOPPView TOPPAS INIFileEditor ExecutePipeline ImageCreator; do
  test -x "$GUI_STAGE/$app.app/Contents/MacOS/$app"
  codesign --verify --deep --strict "$GUI_STAGE/$app.app"
done
test -x "$bin/FileInfo"
test -x "$bin/openms-legacy-gui-thermo-smoke"
test -f "$GUI_STAGE/lib/managed/ThermoWrapperManaged.dll"
test -x "$GUI_STAGE/dotnet/dotnet"
test -f "$GUI_STAGE/dotnet/host/fxr/$DOTNET_FXR_VERSION/libhostfxr.dylib"
test -f "$GUI_STAGE/dotnet/shared/Microsoft.NETCore.App/$DOTNET_RUNTIME_VERSION/System.Private.CoreLib.dll"
test -f "$GUI_STAGE/share/OpenMS/CHEMISTRY/unimod.xml"
test -f "$GUI_STAGE/share/OpenMS/GUISTYLE/qtStyleSheet.qss"

mkdir -p "$RUNNER_TEMP/openms-legacy-gui-home"
for app in TOPPView TOPPAS INIFileEditor ExecutePipeline ImageCreator; do
  env -i \
    HOME="$RUNNER_TEMP/openms-legacy-gui-home" \
    PATH="$bin:/usr/bin:/bin" \
    OPENMS_DATA_PATH="$RUNNER_TEMP/nonexistent-openms-data" \
    QT_QPA_PLATFORM=offscreen \
    OMP_NUM_THREADS=2 \
    "$GUI_STAGE/$app.app/Contents/MacOS/$app" --help >/dev/null
done
env -i \
  HOME="$RUNNER_TEMP/openms-legacy-gui-home" \
  PATH="$bin:/usr/bin:/bin" \
  OPENMS_DATA_PATH="$GUI_STAGE/share/OpenMS" \
  OMP_NUM_THREADS=2 \
  "$bin/FileInfo" --help >/dev/null

env -i \
  HOME="$RUNNER_TEMP/openms-legacy-gui-home" \
  PATH=/usr/bin:/bin \
  DOTNET_ROOT="$GUI_STAGE/dotnet" \
  OPENMS_DATA_PATH="$GUI_STAGE/share/OpenMS" \
  OMP_NUM_THREADS=2 \
  "$bin/openms-legacy-gui-thermo-smoke" "$THERMO_TEST_DATA"
rm "$bin/openms-legacy-gui-thermo-smoke"
