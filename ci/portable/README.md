# Portable package pipeline

The portable workflows build OpenMS without its GUI, build this repository's
GUI separately, and combine both installs into one relocatable package. The
result contains the five GUI applications, the OpenMS TOPP command-line suite,
OpenMS data files and examples, Qt plugins, the Thermo RAW bridge, and a private
.NET runtime.

The scripts are split into deliberately small phases:

1. `configure-openms-*` and `build-openms-*` build the pinned OpenMS core and
   TOPP tools with `WITH_GUI=OFF`.
2. `build-gui-*` builds and installs this standalone GUI against that core.
3. `stage-data-*` and `bundle-dotnet-*` add runtime data and the pinned .NET
   runtime.
4. `deploy-*` gathers native dependencies and Qt platform plugins, then fixes
   runtime search paths or macOS bundles.
5. `verify-*` starts every application in a sanitized environment and exercises
   the packaged Thermo RAW bridge.
6. `audit-*` rejects dependencies that still resolve from build-runner paths.
7. `archive-*` creates a ZIP and SHA-256 sidecar.

The workflow definitions in `.github/workflows/` pin OpenMS, contrib, Qt, and
.NET versions. Update those pins together and let all three platform jobs pass
before publishing a package. The applications intentionally receive an invalid
`OPENMS_DATA_PATH` during verification; their portable bootstrap must discover
the adjacent `share/OpenMS` directory without help from the runner.
