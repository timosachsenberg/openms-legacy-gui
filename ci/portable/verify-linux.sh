#!/usr/bin/env bash
# Fail-closed Linux package verification.
# Required: GUI_STAGE OPENMS_SOURCE OPENMS_INSTALL RUNNER_TEMP THERMO_TEST_DATA
#           DOTNET_FXR_VERSION DOTNET_RUNTIME_VERSION
set -eo pipefail

bin="$GUI_STAGE/bin"
lib="$GUI_STAGE/lib"
for app in TOPPView TOPPAS INIFileEditor ExecutePipeline ImageCreator; do
  test -x "$bin/$app"
done
test -x "$bin/FileInfo"
test -x "$bin/openms-legacy-gui-thermo-smoke"
test -f "$bin/platforms/libqxcb.so"
compgen -G "$lib/libOpenMS.so*" >/dev/null
compgen -G "$lib/libOpenMSLegacyGUI.so*" >/dev/null
compgen -G "$lib/libopenms_thermo_bridge.so*" >/dev/null
test -f "$lib/managed/ThermoWrapperManaged.dll"
test -x "$GUI_STAGE/dotnet/dotnet"
test -f "$GUI_STAGE/dotnet/host/fxr/$DOTNET_FXR_VERSION/libhostfxr.so"
test -f "$GUI_STAGE/dotnet/shared/Microsoft.NETCore.App/$DOTNET_RUNTIME_VERSION/System.Private.CoreLib.dll"
test -f "$GUI_STAGE/share/OpenMS/CHEMISTRY/unimod.xml"
test -f "$GUI_STAGE/share/OpenMS/GUISTYLE/qtStyleSheet.qss"

while IFS= read -r binary; do
  if file "$binary" | grep -q ELF; then
    dependencies=$(ldd "$binary" 2>&1) || {
      echo "$dependencies" >&2
      exit 1
    }
    if grep -q 'not found' <<< "$dependencies"; then
      echo "Unresolved dependency in $binary:" >&2
      echo "$dependencies" >&2
      exit 1
    fi
  fi
done < <(find "$bin" "$lib" -type f -print)

mkdir -p "$RUNNER_TEMP/openms-legacy-gui-home"

# OpenMS resolves its share directory by probing, in order: the compiled-in
# install path (CMAKE_INSTALL_PREFIX/share/OpenMS), the compiled-in build path
# (the OpenMS source share tree), then paths relative to the executable, and
# only last OPENMS_DATA_PATH. Both compiled-in paths still exist on this runner,
# so leaving them in place lets a package that cannot find its own data still
# pass here and then break on a user machine. Hide them so the executables have
# nothing to fall back on but the archive itself.
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
    # A leftover backup from a killed run would turn the mv into a *nested* move
    # ("<backup>/OpenMS"), and the restore would then produce share/OpenMS/OpenMS.
    if [[ -e "$tree.hidden-for-verify" ]]; then
      echo "Stale backup from an interrupted run: $tree.hidden-for-verify" >&2
      exit 1
    fi
    mv "$tree" "$tree.hidden-for-verify"
    hidden_data_trees+=("$tree")
  fi
done
test "${#hidden_data_trees[@]}" -eq 2

for app in TOPPView TOPPAS INIFileEditor ExecutePipeline ImageCreator FileInfo; do
  # A stale OPENMS_DATA_PATH must not be needed *or* consulted: resolution has to
  # come from bin/../share/OpenMS inside the archive.
  env -i \
    HOME="$RUNNER_TEMP/openms-legacy-gui-home" \
    PATH="$bin:/usr/bin:/bin" \
    OPENMS_DATA_PATH="$RUNNER_TEMP/nonexistent-openms-data" \
    QT_QPA_PLATFORM=offscreen \
    OMP_NUM_THREADS=2 \
    timeout 60 "$bin/$app" --help >/dev/null
done

restore_data_trees
hidden_data_trees=()
trap - EXIT

env -i \
  HOME="$RUNNER_TEMP/openms-legacy-gui-home" \
  PATH=/usr/bin:/bin \
  DOTNET_ROOT="$GUI_STAGE/dotnet" \
  OPENMS_DATA_PATH="$GUI_STAGE/share/OpenMS" \
  OMP_NUM_THREADS=2 \
  timeout 300 "$bin/openms-legacy-gui-thermo-smoke" "$THERMO_TEST_DATA"
rm "$bin/openms-legacy-gui-thermo-smoke"
