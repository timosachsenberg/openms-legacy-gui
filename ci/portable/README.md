# Portable package pipeline

The portable workflows build OpenMS without its GUI, build this repository's
GUI separately, and combine both installs into one relocatable package. The
result contains the five GUI applications, the OpenMS TOPP command-line suite,
OpenMS data files and examples, Qt plugins, the Thermo RAW bridge, and a private
.NET runtime.

The scripts are split into deliberately small phases:

1. `configure-openms-*` and `build-openms-*` build the pinned OpenMS core and
   TOPP tools with `WITH_GUI=OFF`.
2. `test-gui-unix.sh` builds the GUI tests in a dedicated tree and runs both
   headless class tests and Xvfb-backed interactive tests on Linux.
3. `build-gui-*` builds and installs this standalone GUI against that core.
4. `stage-data-*` and `bundle-dotnet-*` add runtime data and the pinned .NET
   runtime.
5. `deploy-*` gathers native dependencies and Qt platform plugins, then fixes
   runtime search paths or macOS bundles.
6. `verify-*` starts every application in a sanitized environment and exercises
   the packaged Thermo RAW bridge.
7. `audit-*` rejects dependencies that still resolve from build-runner paths.
8. `archive-*` creates a ZIP and SHA-256 sidecar.

The workflow definitions in `.github/workflows/` pin OpenMS, contrib, Qt, and
.NET versions. Update those pins together and let all three platform jobs pass
before publishing a package.

The applications intentionally receive an invalid `OPENMS_DATA_PATH` during
verification, and the `verify-*` scripts additionally move both compiled-in
OpenMS data trees (the install prefix and the OpenMS source share tree) aside for
the duration of those checks. Both still exist on a build runner and are probed
*before* anything executable-relative, so without hiding them a package that
cannot find its own data would still pass here and only break once unpacked
elsewhere. The scripts restore the trees afterwards and refuse to start if a
`*.hidden-for-verify` backup is left over from an interrupted run.
