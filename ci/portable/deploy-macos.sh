#!/usr/bin/env bash
# Deploy five native app bundles plus the shared TOPP command-line directory.
# Required: GITHUB_WORKSPACE GUI_STAGE GUI_BUILD QT_ROOT_DIR QT_PLUGIN_DIR
#           OPENMS_INSTALL OPENMS_CONTRIB HOMEBREW_PREFIX
set -eo pipefail

bin="$GUI_STAGE/bin"
lib="$GUI_STAGE/lib"
mkdir -p "$bin" "$lib"

smoke=$(find "$GUI_BUILD" -type f -name openms-legacy-gui-thermo-smoke \
  -perm -u+x -print -quit)
test -n "$smoke"
cp "$smoke" "$bin/openms-legacy-gui-thermo-smoke"

executables=()
for executable in "$bin"/*; do
  [[ -f "$executable" && -x "$executable" ]] && executables+=("$executable")
done
executable_list=$(IFS=';'; echo "${executables[*]}")
search_directories=(
  "$bin" "$lib" "$OPENMS_INSTALL/bin" "$OPENMS_INSTALL/lib"
  "$OPENMS_CONTRIB/bin" "$OPENMS_CONTRIB/lib"
  "$QT_ROOT_DIR/bin" "$QT_ROOT_DIR/lib"
  "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/lib"
)
search_list=$(IFS=';'; echo "${search_directories[*]}")

# TOPP tools are ordinary Mach-O executables. Collect their non-system closure
# once into the package lib directory, then make every reference relocatable.
cmake \
  "-DEXECUTABLES=$executable_list" \
  "-DDESTINATION=$lib" \
  "-DSEARCH_DIRECTORIES=$search_list" \
  -P "$GITHUB_WORKSPACE/cmake/DeployRuntimeDependencies.cmake"

rewrite_macho() {
  local macho=$1
  local rpath=$2
  file "$macho" | grep -q 'Mach-O' || return 0
  while IFS= read -r dependency; do
    case "$dependency" in
      @*|/usr/lib/*|/System/*) continue ;;
    esac
    local name
    name=$(basename "$dependency")
    if [[ -e "$lib/$name" ]]; then
      install_name_tool -change "$dependency" "@rpath/$name" "$macho"
    fi
  done < <(otool -L "$macho" | tail -n +2 | sed -E 's/^[[:space:]]*([^[:space:]]+).*/\1/')
  if ! otool -l "$macho" | grep -A2 LC_RPATH | grep -Fq "path $rpath "; then
    install_name_tool -add_rpath "$rpath" "$macho"
  fi
}

for executable in "$bin"/*; do
  [[ -f "$executable" ]] && rewrite_macho "$executable" '@executable_path/../lib'
done
for library in "$lib"/*; do
  [[ -f "$library" ]] || continue
  if file "$library" | grep -q 'Mach-O'; then
    install_name_tool -id "@rpath/$(basename "$library")" "$library" 2>/dev/null || true
    rewrite_macho "$library" '@loader_path'
  fi
done

macdeployqt="$QT_ROOT_DIR/bin/macdeployqt"
test -x "$macdeployqt"
for app_name in TOPPView TOPPAS INIFileEditor ExecutePipeline ImageCreator; do
  app="$GUI_STAGE/$app_name.app"
  test -d "$app"
  "$macdeployqt" "$app" -always-overwrite
  mkdir -p "$app/Contents/PlugIns/platforms"
  cp "$QT_PLUGIN_DIR/platforms/libqoffscreen.dylib" \
    "$app/Contents/PlugIns/platforms/"
  cmake \
    "-DBUNDLE=$app" \
    "-DSEARCH_DIRECTORIES=$search_list" \
    -P "$GITHUB_WORKSPACE/cmake/FixupMacBundle.cmake"

  # The Thermo bridge resolves managed assemblies beside its native library.
  # Keep CLR assemblies as signed resources and expose the expected path by symlink.
  mkdir -p "$app/Contents/Resources/managed"
  cp -a "$GUI_STAGE/lib/managed/." "$app/Contents/Resources/managed/"
  if [[ -e "$app/Contents/Frameworks/managed" ]]; then
    rm -rf "$app/Contents/Frameworks/managed"
  fi
  ln -s ../Resources/managed "$app/Contents/Frameworks/managed"
  codesign --force --deep --sign - "$app"
  codesign --verify --deep --strict "$app"
done

test -d "$GUI_STAGE/.dotnet-runtime"
mv "$GUI_STAGE/.dotnet-runtime" "$GUI_STAGE/dotnet"

# Keep command-line access to the two GUI TOPP tools next to the OpenMS suite.
ln -sf ../ExecutePipeline.app/Contents/MacOS/ExecutePipeline "$bin/ExecutePipeline"
ln -sf ../ImageCreator.app/Contents/MacOS/ImageCreator "$bin/ImageCreator"
