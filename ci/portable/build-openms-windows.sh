#!/usr/bin/env bash
# Required: OPENMS_BUILD OPENMS_INSTALL
set -eo pipefail

cmake --build "$OPENMS_BUILD" --target TOPP
cmake --install "$OPENMS_BUILD" \
  --prefix "$OPENMS_INSTALL" \
  --config Release \
  --strip
