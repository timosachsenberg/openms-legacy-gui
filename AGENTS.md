# Working in this repository

[`README.md`](README.md) covers what the project is and how to build it, and
[`ci/portable/README.md`](ci/portable/README.md) describes the packaging pipeline.
This file covers what those two do not: the behaviour that is easy to get wrong
here, and how to check your work before reporting it.

## Build and test loop

`OpenMS_DIR` may point at either an installed OpenMS or a core-only *build* tree,
which is the fastest way to iterate locally:

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DOpenMS_DIR=/path/to/OpenMS-build \
  -DOPENMS_LEGACY_GUI_WITH_WEBENGINE=OFF
cmake --build build --target GUI
```

The interactive tests (`TOPPView_test`, `TSGDialog_test`) need
`OPENMS_LEGACY_GUI_BUILD_INTERACTIVE_TESTS=ON`, run headless under
`QT_QPA_PLATFORM=offscreen` or `xvfb-run`, and need example data:

```sh
cmake -S . -B build -DOPENMS_LEGACY_GUI_BUILD_TESTS=ON \
  -DOPENMS_LEGACY_GUI_BUILD_INTERACTIVE_TESTS=ON \
  -DOPENMS_LEGACY_GUI_TEST_DATA_DIR=/path/to/OpenMS/share/OpenMS
cmake --build build --target VISUAL_TEST GUI_TEST
xvfb-run -a ctest --test-dir build --output-on-failure
```

`OPENMS_LEGACY_GUI_TEST_DATA_DIR` exists because the packaging build configures
OpenMS with `INSTALL_OPENMS_EXAMPLES=OFF` — `examples/` is 136 MB of a 195 MB
share tree — so the *installed* data directory the tests would otherwise resolve
has no example files. Point it at an OpenMS **source** share tree.

## How OpenMS finds its shared data

This trips up anything touching packaging or tests. `File::getOpenMSDataPath()`
probes in this order and takes the first hit, validating only that
`CHEMISTRY/unimod.xml` exists:

1. compiled-in install path (`CMAKE_INSTALL_PREFIX/share/OpenMS`) — skipped on Windows
2. compiled-in build path (the OpenMS **source** share tree)
3. macOS bundle-relative (`../../../share/OpenMS`)
4. executable-relative (`../share/OpenMS`)
5. `OPENMS_DATA_PATH`

Consequences worth internalising:

- **Setting `OPENMS_DATA_PATH` usually does nothing.** It is probed last, so on
  any machine that built OpenMS, steps 1–2 win first.
- Both compiled-in paths exist on a CI runner, so a package that cannot find its
  own data can still appear to work there. The `verify-*` scripts therefore move
  both trees aside before running the packaged binaries; that is the only reason
  those checks prove anything.
- The result is cached in a function-local static. Anything that resolves the
  path early pins it for the process.

## Portable builds behave differently

`OPENMS_LEGACY_GUI_PORTABLE=ON` (set by `ci/portable/build-gui-*`) activates
`QApplicationTOPP::configurePortableEnvironment()`, which forces the bundled data
tree and refuses to start if OpenMS did not resolve to it. A default local build
does **not** define it, so a local run cannot reproduce portable-mode failures —
configure with `-DOPENMS_LEGACY_GUI_PORTABLE=ON` and stage `bin/` + `share/OpenMS`
side by side to exercise that path.

That function returns an error string and must never throw. OpenMS installs a
`GlobalExceptionHandler` that suppresses the `terminate called` message, so an
exception escaping `main()` becomes a bare `SIGABRT` — exit 134 on Linux,
`0xC0000409` on Windows — with no diagnostic at all. Any exit-134-with-no-output
means *some* uncaught OpenMS exception; the signature alone never identifies
which one. `ExecutePipeline` and `ImageCreator` construct a `TOPPBase` object in
`main()`, outside `tool.main()`'s own try/catch, so that construction needs
explicit guarding.

## macOS packaging

Three recurring hazards, all handled in `ci/portable/`:

- The prebuilt contrib archive bakes absolute install names pointing at the
  directory it was built in. `normalize-contrib-macos.sh` repoints them before
  OpenMS is configured, so the whole downstream closure records resolvable paths.
- Binaries keep `LC_RPATH` entries into the build tree, and any library present
  in both `_build` and `_install` makes `@rpath/<lib>` ambiguous —
  `file(GET_RUNTIME_DEPENDENCIES)` then aborts with "Multiple conflicting paths
  found". Strip build-tree rpaths across the **whole closure**, not just root
  executables; the installed OpenMS libraries carry them too.
- `install_name_tool` invalidates code signatures and arm64 refuses to load
  unsigned images. Sign **after** all rewrites, and never hide a `codesign`
  failure — it resurfaces much later as an obscure load-time error.

## Shell conventions in `ci/portable/`

Scripts are `set -eo pipefail` and fail closed.

**Anything that runs on macOS must be bash 3.2 compatible.** macOS still ships
bash 3.2 as `/bin/bash`, so `mapfile`/`readarray`, associative arrays
(`declare -A`), and `${var^^}`/`${var,,}` are unavailable — using one fails with
`command not found` and exit 127. Build arrays with a read loop instead:

```sh
items=()
while IFS= read -r -d '' item; do items+=("$item"); done < <(find ... -print0)
```

Linux-only scripts (`deploy-linux.sh`, `audit-linux.sh`, ...) run on Ubuntu with
bash 5 and may use the newer builtins; the `*-unix.sh` and `*-macos.sh` ones may
not.

Three further traps that have already caused silent breakage here:

- `some_tool ... | while read ...` hides a failure of `some_tool`: the loop still
  sees an empty stream and succeeds. Capture the output first.
- Capturing is not sufficient on its own. When a helper is called as
  `x=$(helper ...)`, an `errexit` firing *inside* that command substitution does
  not reach the caller. Helpers must check explicitly and `return 1`, and callers
  must check the helper in turn.
- Parse `otool` output textually rather than by whitespace field, or paths
  containing spaces get truncated.

## Before reporting a change as done

- Prefer reproducing a failure locally before fixing it, and re-run the same
  check afterwards. Most of this file was learned by a local reproduction
  contradicting a plausible-sounding theory.
- A matching symptom (exit code, log signature) is *consistent with* a cause, not
  proof of it — especially where a global handler flattens many causes into one.
- macOS and Windows behaviour cannot be verified from a Linux checkout. Say so
  plainly rather than implying a fix is confirmed.
- CI logs are authoritative: `gh run view --repo <owner>/<repo> --job <id> --log-failed`,
  or `gh api repos/<owner>/<repo>/actions/jobs/<id>/logs` when that returns empty.
