#!/usr/bin/env bash
# Configure, build, and install the migrated GUI applications.
# Required: RUNNER_OS GITHUB_WORKSPACE GUI_BUILD GUI_STAGE OPENMS_INSTALL
#           OPENMS_CONTRIB QT_ROOT_DIR; macOS also uses the brew variables.
set -eo pipefail

test -f "$OPENMS_INSTALL/lib/cmake/OpenMS/OpenMSConfig.cmake"
cmake_prefix="$QT_ROOT_DIR/lib/cmake;$QT_ROOT_DIR;$OPENMS_CONTRIB;$OPENMS_INSTALL"
gui_args=()
if [[ "$RUNNER_OS" == "macOS" ]]; then
  openmp_root=$(brew --prefix libomp)
  cmake_prefix="$cmake_prefix;$QT_EXTRA_PREFIXES;$HOMEBREW_PREFIX;$openmp_root"
  gui_args+=("-DOpenMP_ROOT=$openmp_root")
  gui_args+=("-DQT_ADDITIONAL_PACKAGES_PREFIX_PATH=$QT_EXTRA_PREFIXES")
else
  gui_args+=("-DCMAKE_INSTALL_RPATH=\$ORIGIN/../lib")
fi

cmake -S "$GITHUB_WORKSPACE" -B "$GUI_BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$GUI_STAGE" \
  -DCMAKE_PREFIX_PATH="$cmake_prefix" \
  -DOPENMS_CONTRIB_LIBS="$OPENMS_CONTRIB" \
  -DOpenMS_DIR="$OPENMS_INSTALL/lib/cmake/OpenMS" \
  -DOPENMS_LEGACY_GUI_WITH_WEBENGINE=OFF \
  -DOPENMS_LEGACY_GUI_BUILD_TESTS=OFF \
  -DOPENMS_LEGACY_GUI_BUILD_THERMO_SMOKE=ON \
  -DOPENMS_LEGACY_GUI_PORTABLE=ON \
  -DOPENMS_LEGACY_GUI_INSTALL_EXAMPLES=ON \
  "${gui_args[@]}"

if [[ "$RUNNER_OS" == "macOS" ]]; then
  brew_prefix=$(brew --prefix)
  export LIBRARY_PATH="$brew_prefix/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
fi
cmake --build "$GUI_BUILD" --target GUI openms-legacy-gui-thermo-smoke
cmake --install "$GUI_BUILD" --strip
