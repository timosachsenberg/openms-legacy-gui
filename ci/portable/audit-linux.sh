#!/usr/bin/env bash
# Reject ELF dependencies that resolve only from build-runner directories.
# Required: GUI_STAGE OPENMS_INSTALL OPENMS_BUILD OPENMS_SOURCE OPENMS_CONTRIB
#           OPENMS_CONTRIB_SOURCE QT_ROOT_DIR GITHUB_WORKSPACE
set -eo pipefail

runner_roots=(
  "$OPENMS_INSTALL" "$OPENMS_BUILD" "$OPENMS_SOURCE"
  "$OPENMS_CONTRIB" "$OPENMS_CONTRIB_SOURCE" "$QT_ROOT_DIR"
  "$GITHUB_WORKSPACE/_deps" "$GITHUB_WORKSPACE/_build" "$GITHUB_WORKSPACE/_install"
)
leaks=()
checked=0
system_library_pattern='^(linux-vdso|ld-linux.*|libc|libm|libdl|libpthread|librt|libresolv|libutil|libanl|libnsl|libnss_.*|libBrokenLocale|libmvec|libthread_db|libcrypt|libgcc_s|libstdc\+\+|libGL|libGLX|libGLdispatch|libOpenGL|libEGL|libGLESv2|libglapi|libgbm|libdrm|libX11|libX11-xcb|libxcb|libxcb-.*|libXext|libXau|libXdmcp|libXrender|libXrandr|libXfixes|libXcursor|libXinerama|libXi|libXcomposite|libXdamage|libXtst|libXss|libXxf86vm|libxshmfence|libSM|libICE|libwayland-.*|libxkbcommon|libxkbcommon-x11)\.so.*$'
while IFS= read -r binary; do
  file "$binary" | grep -q ELF || continue
  ((checked += 1))
  dependencies=$(ldd "$binary" 2>&1) || {
    leaks+=("ldd failed [${binary#"$GUI_STAGE"/}]: $dependencies")
    continue
  }
  if grep -q 'not found' <<< "$dependencies"; then
    leaks+=("unresolved dependency [${binary#"$GUI_STAGE"/}]: $(grep 'not found' <<< "$dependencies")")
  fi
  while IFS= read -r resolved; do
    [[ -n "$resolved" ]] || continue
    case "$resolved" in
      "$GUI_STAGE"/*) ;;
      *)
        name=$(basename "$resolved")
        if [[ ! "$name" =~ $system_library_pattern ]]; then
          leaks+=("$resolved [${binary#"$GUI_STAGE"/}]")
          continue
        fi
        # Retain the explicit runner-root check as a diagnostic guard even
        # when a build directory happens to contain a system-named library.
        for root in "${runner_roots[@]}"; do
          [[ "$resolved" == "$root"/* ]] && \
            leaks+=("$resolved [${binary#"$GUI_STAGE"/}]")
        done
        ;;
    esac
  done < <(sed -n -E \
    -e 's/^[[:space:]]*[^[:space:]]+[[:space:]]+=>[[:space:]]+(\/[^[:space:]]+).*/\1/p' \
    -e 's/^[[:space:]]*(\/[^[:space:]]+).*/\1/p' <<< "$dependencies")
done < <(find "$GUI_STAGE/bin" "$GUI_STAGE/lib" -type f -print)

echo "Audited $checked staged ELF objects."
if (( ${#leaks[@]} > 0 )); then
  printf 'Runner-only dependency: %s\n' "${leaks[@]}" | sort -u >&2
  exit 1
fi
