# OpenMS Legacy GUI

This repository contains the Qt GUI library and applications migrated out of
the OpenMS monorepo. It builds against an independently installed OpenMS core
from the matching 3.6 minor series.

The initial source snapshot comes from OpenMS commit
`7ee0cccf29d69a75503cae542ea397b4dec5c88e`; the precise source paths are listed
in [`UPSTREAM_OPENMS_REVISION`](UPSTREAM_OPENMS_REVISION). The upstream directory
layout is intentionally retained below `src/openms_gui` to keep later source
synchronization reviewable.

## Applications

- `TOPPView` — inspect mass-spectrometry maps, spectra, chromatograms, features,
  consensus features, and identifications.
- `TOPPAS` — visually compose and execute OpenMS processing workflows.
- `INIFileEditor` — edit OpenMS parameter files.
- `ExecutePipeline` — execute a TOPPAS pipeline.
- `ImageCreator` — render OpenMS data to an image from the command line.

## Build

OpenMS and this project must use ABI-compatible compilers, build types, and
dependencies. Point `OpenMS_DIR` at the CMake package exported by a core-only
OpenMS build and make Qt available through `CMAKE_PREFIX_PATH` when it is not in
a system prefix:

```sh
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DOpenMS_DIR=/path/to/OpenMS/lib/cmake/OpenMS
cmake --build build --target GUI
ctest --test-dir build --output-on-failure
cmake --install build --prefix /path/to/stage
```

Qt 6 Core, Gui, Widgets, Svg, and OpenGLWidgets are required. WebEngineWidgets
is optional and enables TOPPView's JavaScript sequence view. Set
`OPENMS_LEGACY_GUI_WITH_WEBENGINE=OFF` to disable the probe explicitly.

`TOPPAS` and TOPPView's tool dialogs discover TOPP command-line programs next
to the GUI executables or on `PATH`. A production portable package therefore
bundles the OpenMS TOPP suite as well as the OpenMS core library.

## Portable packages

The workflows under `.github/workflows` build OpenMS without its in-tree GUI,
build these migrated applications against that installation, stage the OpenMS
data tree and TOPP tools, collect native dependencies and Qt plugins, verify the
relocated folder in a sanitized environment, and publish a ZIP plus SHA-256
checksum. The deterministic stages live under `ci/portable`; GitHub Actions only
provides runner setup and orchestration.

Portable builds enable `OPENMS_LEGACY_GUI_PORTABLE`. Each application then
validates and selects the package-local `share/OpenMS` tree before OpenMS first
resolves data, and selects the app-local `dotnet` runtime when present. This
makes direct execution independent of stale system OpenMS or .NET settings.

The extracted layout is:

```text
OpenMSLegacyGUI/
  bin/                 GUI and TOPP executables; Qt plugins on Linux/Windows
  lib/                 OpenMS, OpenMSLegacyGUI, and native dependencies
  share/OpenMS/        OpenMS runtime data, GUI stylesheet, and TOPPAS examples
  dotnet/              app-local .NET runtime used by Thermo RAW support
  BUILD-INFO.txt       exact OpenMS, GUI, contrib, Qt, and .NET provenance
```

macOS uses native `.app` bundles at the package root and embeds each bundle's
runtime dependencies. CI artifacts are ad-hoc signed and are not notarized.

## License

The migrated OpenMS sources are BSD-3-Clause licensed; see [`LICENSE`](LICENSE).
