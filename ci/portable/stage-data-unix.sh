#!/usr/bin/env bash
# Merge TOPP tools, OpenMS data, managed Thermo support, licenses, and provenance.
# Required: RUNNER_OS GUI_STAGE OPENMS_INSTALL OPENMS_CONTRIB_SOURCE QT_ROOT_DIR
#           PACKAGE_PLATFORM QT_ARCH ARCH GUI_SHA OPENMS_REF OPENMS_SHA CONTRIB_TAG
#           DEPLOYED_QT_VERSION DOTNET_RUNTIME_VERSION DOTNET_FXR_VERSION
set -eo pipefail

mkdir -p "$GUI_STAGE/bin" "$GUI_STAGE/lib" "$GUI_STAGE/share/OpenMS"
cp -a "$OPENMS_INSTALL/bin/." "$GUI_STAGE/bin/"
cp -a "$OPENMS_INSTALL/share/OpenMS/." "$GUI_STAGE/share/OpenMS/"

managed_source=$(find "$OPENMS_INSTALL" -type d \
  -path '*/openms_thermo_bridge/managed' -print -quit)
if [[ -z "$managed_source" ]]; then
  echo "The installed OpenMS Thermo managed bridge was not found." >&2
  exit 1
fi
mkdir -p "$GUI_STAGE/lib/managed"
cp -a "$managed_source/." "$GUI_STAGE/lib/managed/"

license_root="$GUI_STAGE/share/licenses"
mkdir -p "$license_root"
cp "$OPENMS_INSTALL/share/OpenMS/LICENSES/OpenMS-BSD-3-Clause.txt" \
  "$license_root/OpenMS-BSD-3-Clause.txt"
cp "$OPENMS_CONTRIB_SOURCE/LICENSE.md" "$license_root/OpenMS-contrib.md"
cp -a "$OPENMS_CONTRIB_SOURCE/licensetexts" \
  "$license_root/OpenMS-contrib-licenses"
thermo_license="$OPENMS_INSTALL/share/OpenMS/LICENSES/ThermoRawFileReader-License.doc"
if [[ -f "$thermo_license" ]]; then
  cp "$thermo_license" "$license_root/"
fi
if [[ -d "$QT_ROOT_DIR/LICENSES" ]]; then
  cp -a "$QT_ROOT_DIR/LICENSES" "$license_root/Qt"
fi

cat > "$GUI_STAGE/BUILD-INFO.txt" <<EOF
OpenMS Legacy GUI portable $PACKAGE_PLATFORM build
GUI commit: $GUI_SHA
OpenMS ref: $OPENMS_REF (pinned)
OpenMS commit: $OPENMS_SHA
OpenMS contrib release: $CONTRIB_TAG
OpenMS WITH_GUI: OFF
OpenMS BUILD_TOPP_TOOLS: ON
OpenMS WITH_THERMO_RAW: ON
OpenMS WITH_OPENTIMS: ON
OpenMS OpenMP: ON
Qt: $DEPLOYED_QT_VERSION ($QT_ARCH)
.NET runtime: $DOTNET_RUNTIME_VERSION (hostfxr $DOTNET_FXR_VERSION, $ARCH, app-local)
Architecture: $ARCH
Built at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

if [[ "$RUNNER_OS" == "macOS" ]]; then
  cat > "$GUI_STAGE/README-MACOS.txt" <<'EOF'
Open TOPPView.app, TOPPAS.app, or INIFileEditor.app. No installation is required.

This CI artifact is ad-hoc signed, not Apple-notarized. Depending on Gatekeeper
settings, the first launch may require Control-clicking the app and choosing Open.
EOF
else
  cat > "$GUI_STAGE/README-LINUX.txt" <<'EOF'
Run bin/TOPPView, bin/TOPPAS, or bin/INIFileEditor. No installation is required.

The package targets x64 Linux with the Ubuntu 24.04 glibc baseline. A desktop
X11 or Wayland session is required for interactive use.
EOF
fi
