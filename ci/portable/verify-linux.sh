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
for app in TOPPView TOPPAS INIFileEditor ExecutePipeline ImageCreator FileInfo; do
  data_path="$RUNNER_TEMP/nonexistent-openms-data"
  [[ "$app" == FileInfo ]] && data_path="$GUI_STAGE/share/OpenMS"
  env -i \
    HOME="$RUNNER_TEMP/openms-legacy-gui-home" \
    PATH="$bin:/usr/bin:/bin" \
    OPENMS_DATA_PATH="$data_path" \
    QT_QPA_PLATFORM=offscreen \
    OMP_NUM_THREADS=2 \
    timeout 60 "$bin/$app" --help >/dev/null
done

env -i \
  HOME="$RUNNER_TEMP/openms-legacy-gui-home" \
  PATH=/usr/bin:/bin \
  DOTNET_ROOT="$GUI_STAGE/dotnet" \
  OPENMS_DATA_PATH="$GUI_STAGE/share/OpenMS" \
  OMP_NUM_THREADS=2 \
  timeout 300 "$bin/openms-legacy-gui-thermo-smoke" "$THERMO_TEST_DATA"
rm "$bin/openms-legacy-gui-thermo-smoke"
