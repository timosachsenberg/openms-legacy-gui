#!/usr/bin/env bash
# Deploy Linux dependencies, Qt plugins, and relocatable RPATHs.
# Required: GITHUB_WORKSPACE GUI_STAGE GUI_BUILD QT_PLUGIN_DIR QT_ROOT_DIR
#           OPENMS_INSTALL OPENMS_CONTRIB
set -eo pipefail

bin="$GUI_STAGE/bin"
lib="$GUI_STAGE/lib"
mkdir -p "$lib"

smoke=$(find "$GUI_BUILD" -type f -name openms-legacy-gui-thermo-smoke \
  -perm -u+x -print -quit)
test -n "$smoke"
cp "$smoke" "$bin/openms-legacy-gui-thermo-smoke"

for plugin_group in \
  iconengines imageformats platforminputcontexts platforms tls xcbglintegrations; do
  if [[ -d "$QT_PLUGIN_DIR/$plugin_group" ]]; then
    mkdir -p "$bin/$plugin_group"
    cp -a "$QT_PLUGIN_DIR/$plugin_group/." "$bin/$plugin_group/"
  fi
done

mapfile -t executables < <(find "$bin" -maxdepth 1 -type f -perm -u+x -print)
mapfile -t plugins < <(find "$bin" -mindepth 2 -type f \
  \( -name '*.so' -o -name '*.so.*' \) -print)
if (( ${#executables[@]} == 0 || ${#plugins[@]} == 0 )); then
  echo "Portable dependency roots are incomplete." >&2
  exit 1
fi
executable_list=$(IFS=';'; echo "${executables[*]}")
plugin_list=$(IFS=';'; echo "${plugins[*]}")
search_directories=(
  "$bin" "$OPENMS_INSTALL/bin" "$OPENMS_INSTALL/lib"
  "$OPENMS_CONTRIB/bin" "$OPENMS_CONTRIB/lib"
  "$QT_ROOT_DIR/bin" "$QT_ROOT_DIR/lib"
)
search_list=$(IFS=';'; echo "${search_directories[*]}")

cmake \
  "-DEXECUTABLES=$executable_list" \
  "-DLIBRARIES=$plugin_list" \
  "-DDESTINATION=$lib" \
  "-DSEARCH_DIRECTORIES=$search_list" \
  -P "$GITHUB_WORKSPACE/cmake/DeployRuntimeDependencies.cmake"

# shellcheck disable=SC2016 # $ORIGIN is interpreted by the ELF loader.
while IFS= read -r binary; do
  if file "$binary" | grep -q ELF; then
    patchelf --force-rpath --set-rpath '$ORIGIN/../lib' "$binary"
  fi
done < <(find "$bin" -maxdepth 1 -type f -print)
# shellcheck disable=SC2016 # $ORIGIN is interpreted by the ELF loader.
while IFS= read -r library; do
  if file "$library" | grep -q ELF; then
    patchelf --force-rpath --set-rpath '$ORIGIN' "$library"
  fi
done < <(find "$lib" -type f -print)
# shellcheck disable=SC2016 # $ORIGIN is interpreted by the ELF loader.
while IFS= read -r plugin; do
  if file "$plugin" | grep -q ELF; then
    patchelf --force-rpath --set-rpath '$ORIGIN/../../lib' "$plugin"
  fi
done < <(find "$bin" -mindepth 2 -type f -print)
