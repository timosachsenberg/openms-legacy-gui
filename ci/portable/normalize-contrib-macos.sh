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

is_macho() {
  file "$1" | grep -q 'Mach-O'
}

# otool -L prints "\t<path> (compatibility version ...)". Strip the decoration
# textually rather than taking the first whitespace-delimited field, so a path
# containing spaces is not truncated.
#
# A bare `otool ... | while` would let a failure vanish: the loop still sees an
# empty stream and succeeds, so even the validation pass below would silently
# skip a Mach-O. Capturing alone is not enough either -- when this helper is
# invoked as `x=$(macho_dependencies ...)`, an errexit inside that command
# substitution does NOT reach the caller. Check explicitly and return non-zero,
# and have every caller check this function in turn.
macho_dependencies() {
  local macho=$1 output
  if ! output=$(otool -L "$macho" 2>&1); then
    printf 'otool -L failed on %s:\n%s\n' "$macho" "$output" >&2
    return 1
  fi
  printf '%s\n' "$output" | tail -n +2 \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+\(compatibility version .*\)$//'
}

# Collected up front because the list is walked twice (rewrite, then validate).
# Built with a read loop rather than mapfile: macOS ships bash 3.2, where mapfile
# does not exist. Keep every macOS-executed script bash 3.2 compatible.
candidates=()
while IFS= read -r -d '' macho; do
  candidates+=("$macho")
done < <(find "$lib" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)

rewritten=0
for macho in "${candidates[@]}"; do
  is_macho "$macho" || continue
  chmod u+w "$macho"

  # Give the library an id that resolves, so dependents linking against it from
  # now on record the extracted location rather than the archive's build path.
  install_name_tool -id "$lib/$(basename "$macho")" "$macho"

  if ! dependencies=$(macho_dependencies "$macho"); then
    exit 1
  fi
  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    case "$dependency" in
      @*|/usr/lib/*|/System/*) continue ;;
    esac
    # Only absolute references that dangle are stale; leave resolvable ones alone.
    [[ -e "$dependency" ]] && continue
    replacement="$lib/$(basename "$dependency")"
    [[ -e "$replacement" ]] || continue
    install_name_tool -change "$dependency" "$replacement" "$macho"
    rewritten=$((rewritten + 1))
  done <<< "$dependencies"

  # The -id rewrite above always modifies the file, which invalidates its
  # signature, and arm64 will not load unsigned images. Nothing rewrites these
  # files again, so signing here is final. A failure is fatal rather than
  # suppressed: an unsigned dylib fails much later, at load time, with a far
  # less obvious error.
  codesign --force --sign - "$macho"
done

echo "Repointed $rewritten stale contrib install name(s) at $lib"

# Fail loudly rather than deferring to a confusing otool error during deployment.
dangling=0
for macho in "${candidates[@]}"; do
  is_macho "$macho" || continue
  if ! dependencies=$(macho_dependencies "$macho"); then
    exit 1
  fi
  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    case "$dependency" in
      @*|/usr/lib/*|/System/*) continue ;;
    esac
    if [[ ! -e "$dependency" ]]; then
      echo "Dangling contrib dependency: $macho -> $dependency" >&2
      dangling=$((dangling + 1))
    fi
  done <<< "$dependencies"
done

test "$dangling" -eq 0
