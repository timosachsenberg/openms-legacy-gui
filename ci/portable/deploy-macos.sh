#!/usr/bin/env bash
# Deploy five native app bundles plus the shared TOPP command-line directory.
# Required: GITHUB_WORKSPACE GUI_STAGE GUI_BUILD QT_ROOT_DIR QT_PLUGIN_DIR
#           OPENMS_BUILD OPENMS_INSTALL OPENMS_CONTRIB HOMEBREW_PREFIX
set -eo pipefail

bin="$GUI_STAGE/bin"
lib="$GUI_STAGE/lib"
mkdir -p "$bin" "$lib"

smoke=$(find "$GUI_BUILD" -type f -name openms-legacy-gui-thermo-smoke \
  -perm -u+x -print -quit)
test -n "$smoke"
cp "$smoke" "$bin/openms-legacy-gui-thermo-smoke"

is_macho() {
  file "$1" | grep -q 'Mach-O'
}

# LC_RPATH entries print as "         path <value> (offset N)". Take only the path
# lines that follow an LC_RPATH command and strip the decoration textually, so a
# value containing spaces survives (splitting on whitespace would truncate it).
macho_rpaths() {
  local macho=$1 output
  # A bare `otool ... | while` would let a failure vanish: the loop still sees an
  # empty stream and succeeds. Capturing alone is not enough either -- when a
  # helper like this is itself invoked as `x=$(macho_rpaths ...)`, an errexit
  # inside this command substitution does NOT reach the caller. Check explicitly
  # and return, and have every caller check this function in turn.
  if ! output=$(otool -l "$macho" 2>&1); then
    printf 'otool -l failed on %s:\n%s\n' "$macho" "$output" >&2
    return 1
  fi
  printf '%s\n' "$output" | awk '
    /^ *cmd LC_RPATH$/ { in_rpath = 1; next }
    in_rpath && /^ *path / {
      sub(/^ *path /, ""); sub(/ \(offset [0-9]+\)$/, "")
      print; in_rpath = 0
    }'
}

# Binaries carry LC_RPATH entries pointing into the OpenMS/GUI build trees: the
# smoke probe because it is copied straight out of one, and the installed OpenMS
# libraries because their build rpath survives installation. Every library that
# exists in both _build and _install then makes @rpath/<lib> ambiguous, and
# file(GET_RUNTIME_DEPENDENCIES) aborts with "Multiple conflicting paths found"
# (libOpenMS.dylib first, then libOpenSwathAlgo.dylib, ...). Strip build-tree
# rpaths across the whole closure -- not just the root executables -- so the
# install tree is the only resolution.
strip_build_rpaths() {
  local macho=$1 rpath rpaths
  is_macho "$macho" || return 0
  chmod u+w "$macho"
  if ! rpaths=$(macho_rpaths "$macho"); then
    return 1
  fi
  [[ -n "$rpaths" ]] || return 0
  while IFS= read -r rpath; do
    [[ -n "$rpath" ]] || continue
    case "$rpath" in
      "$OPENMS_BUILD"/*|"$OPENMS_BUILD"|"$GUI_BUILD"/*|"$GUI_BUILD")
        install_name_tool -delete_rpath "$rpath" "$macho"
        ;;
    esac
  done <<< "$rpaths"
}

while IFS= read -r macho; do
  strip_build_rpaths "$macho" || exit 1
done < <(find "$bin" "$OPENMS_INSTALL/lib" "$OPENMS_INSTALL/bin" \
  -maxdepth 1 -type f -print)

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

# otool -L prints "\t<path> (compatibility version ...)". Strip the decoration
# textually rather than taking the first whitespace-delimited field, so a path
# containing spaces is not truncated.
macho_dependencies() {
  local macho=$1 output
  if ! output=$(otool -L "$macho" 2>&1); then
    printf 'otool -L failed on %s:\n%s\n' "$macho" "$output" >&2
    return 1
  fi
  printf '%s\n' "$output" | tail -n +2 \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+\(compatibility version .*\)$//'
}

rewrite_macho() {
  local macho=$1
  local rpath=$2
  local dependency name dependencies
  is_macho "$macho" || return 0
  if ! dependencies=$(macho_dependencies "$macho"); then
    return 1
  fi
  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    case "$dependency" in
      @*|/usr/lib/*|/System/*) continue ;;
    esac
    name=$(basename "$dependency")
    if [[ -e "$lib/$name" ]]; then
      install_name_tool -change "$dependency" "@rpath/$name" "$macho"
    fi
  done <<< "$dependencies"
  local existing_rpaths
  if ! existing_rpaths=$(macho_rpaths "$macho"); then
    return 1
  fi
  if ! grep -Fqx "$rpath" <<< "$existing_rpaths"; then
    install_name_tool -add_rpath "$rpath" "$macho"
  fi
}

for executable in "$bin"/*; do
  [[ -f "$executable" ]] && rewrite_macho "$executable" '@executable_path/../lib'
done
for library in "$lib"/*; do
  [[ -f "$library" ]] || continue
  if is_macho "$library"; then
    install_name_tool -id "@rpath/$(basename "$library")" "$library"
    rewrite_macho "$library" '@loader_path'
  fi
done

# Every install_name_tool call above invalidates the code signature, and arm64
# refuses to load unsigned images. Sign the command-line closure now that all
# rewrites are done -- signing earlier would just be undone. The .app bundles are
# signed separately below, after macdeployqt and FixupMacBundle have run.
while IFS= read -r macho; do
  is_macho "$macho" || continue
  codesign --force --sign - "$macho"
done < <(find "$bin" "$lib" -maxdepth 1 -type f -print)

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
