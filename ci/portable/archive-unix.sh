#!/usr/bin/env bash
# Required: RUNNER_OS GITHUB_WORKSPACE GUI_STAGE PACKAGE_PLATFORM ARCH
#           OPENMS_SHORT_SHA GITHUB_OUTPUT
set -eo pipefail

artifact_name="OpenMSLegacyGUI-$PACKAGE_PLATFORM-$ARCH-openms-$OPENMS_SHORT_SHA"
artifact_directory="$GITHUB_WORKSPACE/artifacts"
zip_path="$artifact_directory/$artifact_name.zip"
mkdir -p "$artifact_directory"

if [[ "$RUNNER_OS" == "macOS" ]]; then
  ditto -c -k --sequesterRsrc --keepParent "$GUI_STAGE" "$zip_path"
  shasum -a 256 "$zip_path" | \
    sed "s#  .*#  $artifact_name.zip#" > "$zip_path.sha256"
else
  (
    cd "$(dirname "$GUI_STAGE")"
    zip -r -9 -q -y "$zip_path" "$(basename "$GUI_STAGE")"
  )
  sha256sum "$zip_path" | \
    sed "s#  .*#  $artifact_name.zip#" > "$zip_path.sha256"
fi
echo "artifact_name=$artifact_name" >> "$GITHUB_OUTPUT"
