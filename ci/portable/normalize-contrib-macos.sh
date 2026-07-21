#!/usr/bin/env bash
# The prebuilt macOS contrib archive bakes absolute install names pointing at the
# directory it was originally built in (/Users/runner/work/contrib/contrib/
# contrib-build/lib). That path does not exist here, so anything linking against
# contrib inherits a dangling reference and file(GET_RUNTIME_DEPENDENCIES) later
# aborts with "Failed to run otool on ...". Repoint every stale reference at the
# extracted tree before OpenMS is configured, so the whole downstream closure
# records resolvable paths.
# Required: OPENMS_CONTRIB
set -eo pipefail

lib="$OPENMS_CONTRIB/lib"
test -d "$lib"

rewritten=0
while IFS= read -r -d '' macho; do
  file "$macho" | grep -q 'Mach-O' || continue
  chmod u+w "$macho"

  # Give the library an id that resolves, so dependents linking against it from
  # now on record the extracted location rather than the archive's build path.
  install_name_tool -id "$lib/$(basename "$macho")" "$macho" 2>/dev/null || true

  while IFS= read -r dependency; do
    case "$dependency" in
      @*|/usr/lib/*|/System/*) continue ;;
    esac
    # Only absolute references that dangle are stale; leave resolvable ones alone.
    [[ -e "$dependency" ]] && continue
    replacement="$lib/$(basename "$dependency")"
    [[ -e "$replacement" ]] || continue
    install_name_tool -change "$dependency" "$replacement" "$macho"
    rewritten=$((rewritten + 1))
  done < <(otool -L "$macho" | tail -n +2 | sed -E 's/^[[:space:]]*([^[:space:]]+).*/\1/')

  # install_name_tool invalidates any existing signature, and arm64 refuses to
  # load unsigned Mach-O images. Re-apply an ad-hoc signature.
  codesign --force --sign - "$macho" 2>/dev/null || true
done < <(find "$lib" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)

echo "Repointed $rewritten stale contrib install name(s) at $lib"

# Fail loudly rather than deferring to a confusing otool error during deployment.
dangling=0
while IFS= read -r -d '' macho; do
  file "$macho" | grep -q 'Mach-O' || continue
  while IFS= read -r dependency; do
    case "$dependency" in
      @*|/usr/lib/*|/System/*) continue ;;
    esac
    if [[ ! -e "$dependency" ]]; then
      echo "Dangling contrib dependency: $macho -> $dependency" >&2
      dangling=$((dangling + 1))
    fi
  done < <(otool -L "$macho" | tail -n +2 | sed -E 's/^[[:space:]]*([^[:space:]]+).*/\1/')
done < <(find "$lib" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)

test "$dangling" -eq 0
