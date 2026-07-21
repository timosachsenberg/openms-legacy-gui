#!/usr/bin/env bash
# Build and run the standalone migrated GUI tests (Linux only). The dedicated
# build tree keeps test targets and CTest metadata out of the package build.
# Xvfb supplies a display for the TOPPView and TSGDialog integration tests.
# Required: GITHUB_WORKSPACE OPENMS_INSTALL OPENMS_CONTRIB QT_ROOT_DIR
set -eo pipefail

test_build="$GITHUB_WORKSPACE/_build/gui-tests"
cmake -S "$GITHUB_WORKSPACE" -B "$test_build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$QT_ROOT_DIR/lib/cmake;$QT_ROOT_DIR;$OPENMS_CONTRIB;$OPENMS_INSTALL" \
  -DOPENMS_CONTRIB_LIBS="$OPENMS_CONTRIB" \
  -DOpenMS_DIR="$OPENMS_INSTALL/lib/cmake/OpenMS" \
  -DOPENMS_LEGACY_GUI_WITH_WEBENGINE=OFF \
  -DOPENMS_LEGACY_GUI_BUILD_TESTS=ON \
  -DOPENMS_LEGACY_GUI_BUILD_INTERACTIVE_TESTS=ON \
  -DOPENMS_LEGACY_GUI_INSTALL_EXAMPLES=OFF
cmake --build "$test_build" --target VISUAL_TEST GUI_TEST

LD_LIBRARY_PATH="$OPENMS_INSTALL/lib:$OPENMS_CONTRIB/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
OPENMS_DATA_PATH="$OPENMS_INSTALL/share/OpenMS" \
  xvfb-run -a ctest --test-dir "$test_build" --output-on-failure
