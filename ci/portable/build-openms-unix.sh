#!/usr/bin/env bash
# Build and install OpenMS core plus its TOPP command-line suite.
# Required: RUNNER_OS OPENMS_BUILD OPENMS_INSTALL
set -eo pipefail

if [[ "$RUNNER_OS" == "macOS" ]]; then
  brew install curl
  brew_prefix=$(brew --prefix)
  export LIBRARY_PATH="$brew_prefix/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
fi

cmake --build "$OPENMS_BUILD" --target TOPP
cmake --install "$OPENMS_BUILD" \
  --prefix "$OPENMS_INSTALL" \
  --config Release \
  --strip
