#!/usr/bin/env bash
# Fail-closed macOS package verification.
# Required: GUI_STAGE OPENMS_SOURCE OPENMS_INSTALL RUNNER_TEMP THERMO_TEST_DATA
#           DOTNET_FXR_VERSION DOTNET_RUNTIME_VERSION
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

# OpenMS resolves its share directory by probing, in order: the compiled-in
# install path (CMAKE_INSTALL_PREFIX/share/OpenMS), the compiled-in build path
# (the OpenMS source share tree), then paths relative to the executable
# (../../../share/OpenMS from inside a bundle, ../share/OpenMS for bin/ tools),
# and only last OPENMS_DATA_PATH. Both compiled-in paths still exist on this
# runner, so leaving them in place lets a package that cannot find its own data
# still pass here and then break on a user machine. Hide them so the executables
# have nothing to fall back on but the archive itself.
hidden_data_trees=()
restore_data_trees() {
  local tree
  for tree in "${hidden_data_trees[@]}"; do
    [[ -d "$tree.hidden-for-verify" ]] && mv "$tree.hidden-for-verify" "$tree"
  done
}
trap restore_data_trees EXIT

for tree in "$OPENMS_INSTALL/share/OpenMS" "$OPENMS_SOURCE/share/OpenMS"; do
  if [[ -d "$tree" ]]; then
    mv "$tree" "$tree.hidden-for-verify"
    hidden_data_trees+=("$tree")
  fi
done
test "${#hidden_data_trees[@]}" -eq 2

# A stale OPENMS_DATA_PATH must not be needed *or* consulted: resolution has to
# come from the share/OpenMS shipped alongside the bundles.
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
  OPENMS_DATA_PATH="$RUNNER_TEMP/nonexistent-openms-data" \
  OMP_NUM_THREADS=2 \
  "$bin/FileInfo" --help >/dev/null

restore_data_trees
hidden_data_trees=()
trap - EXIT

env -i \
  HOME="$RUNNER_TEMP/openms-legacy-gui-home" \
  PATH=/usr/bin:/bin \
  DOTNET_ROOT="$GUI_STAGE/dotnet" \
  OPENMS_DATA_PATH="$GUI_STAGE/share/OpenMS" \
  OMP_NUM_THREADS=2 \
  "$bin/openms-legacy-gui-thermo-smoke" "$THERMO_TEST_DATA"
rm "$bin/openms-legacy-gui-thermo-smoke"
