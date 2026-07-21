#!/usr/bin/env bash
# Reject Mach-O dependencies outside the package or Apple's system baseline.
# Required: GUI_STAGE
set -eo pipefail

leaks=()
checked=0
while IFS= read -r macho; do
  file "$macho" | grep -q 'Mach-O' || continue
  ((checked += 1))
  while IFS= read -r path; do
    case "$path" in
      @rpath/*|@executable_path/*|@loader_path/*|/usr/lib/*|/System/*|"$GUI_STAGE"/*) ;;
      *) leaks+=("$path [${macho#"$GUI_STAGE"/}]") ;;
    esac
  done < <(otool -L "$macho" | tail -n +2 | sed -E 's/^[[:space:]]*([^[:space:]]+).*/\1/')
done < <(find "$GUI_STAGE" -type f -print)

echo "Audited $checked staged Mach-O objects."
if (( ${#leaks[@]} > 0 )); then
  printf 'External Mach-O dependency: %s\n' "${leaks[@]}" | sort -u >&2
  exit 1
fi
