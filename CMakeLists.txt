cmake_minimum_required(VERSION 3.24)

project(OpenMSLegacyGUI VERSION 3.6.0 LANGUAGES CXX)

if(POLICY CMP0167)
  cmake_policy(SET CMP0167 NEW)
endif()

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
# Qt 6.4's moc cannot parse GCC 13's C++23 <concept> implementation when the
# compiler predefinition header is injected. OpenMS uses the same setting for
# its GUI target; ordinary C++ compilation still receives all compiler defines.
set(CMAKE_AUTOMOC_COMPILER_PREDEFINES OFF)

if(PROJECT_IS_TOP_LEVEL AND NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
endif()

# Development OpenMS exports commonly provide only a Release location.
set(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release)
set(CMAKE_MAP_IMPORTED_CONFIG_DEBUG Release)

option(BUILD_SHARED_LIBS "Build OpenMSLegacyGUI as a shared library" ON)
option(OPENMS_LEGACY_GUI_WITH_WEBENGINE
  "Enable TOPPView's optional JavaScript sequence view when Qt WebEngine is available" ON)
option(OPENMS_LEGACY_GUI_BUILD_TESTS "Build the migrated GUI class tests" ${PROJECT_IS_TOP_LEVEL})
option(OPENMS_LEGACY_GUI_BUILD_INTERACTIVE_TESTS
  "Build the TOPPView/Qt GUI integration tests" OFF)
option(OPENMS_LEGACY_GUI_INSTALL_EXAMPLES "Install the migrated TOPPAS examples" ON)
option(OPENMS_LEGACY_GUI_BUILD_THERMO_SMOKE
  "Build the non-installed Thermo RAW portable-package smoke probe" OFF)
option(OPENMS_LEGACY_GUI_PORTABLE
  "Force applications to use the adjacent portable OpenMS data and .NET trees" OFF)

find_package(Qt6 6.1 REQUIRED COMPONENTS Core Gui Widgets Svg OpenGLWidgets)
set(OPENMS_LEGACY_GUI_QT_LIBRARIES
  Qt6::Core
  Qt6::Gui
  Qt6::Widgets
  Qt6::Svg
  Qt6::OpenGLWidgets
)

if(APPLE)
  find_package(Qt6 6.1 REQUIRED COMPONENTS PrintSupport)
  list(APPEND OPENMS_LEGACY_GUI_QT_LIBRARIES Qt6::PrintSupport)
endif()

set(OPENMS_LEGACY_GUI_WEBENGINE_ENABLED OFF)
if(OPENMS_LEGACY_GUI_WITH_WEBENGINE)
  find_package(Qt6 6.1 QUIET COMPONENTS WebEngineWidgets)
  if(Qt6WebEngineWidgets_FOUND)
    list(APPEND OPENMS_LEGACY_GUI_QT_LIBRARIES Qt6::WebEngineWidgets)
    set(OPENMS_LEGACY_GUI_WEBENGINE_ENABLED ON)
  else()
    message(STATUS "Qt WebEngineWidgets was not found; TOPPView's JavaScript sequence view is disabled")
  endif()
endif()

# OpenMS has no stable cross-minor ABI. Keep this project on the same minor
# series as the source snapshot recorded in UPSTREAM_OPENMS_REVISION.
if(NOT TARGET OpenMS)
  find_package(OpenMS 3.6...<3.7 CONFIG REQUIRED)
endif()

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

if(UNIX AND NOT APPLE AND NOT DEFINED CMAKE_INSTALL_RPATH)
  set(CMAKE_INSTALL_RPATH "\$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")
endif()

add_subdirectory(src/openms_gui)

if(OPENMS_LEGACY_GUI_BUILD_THERMO_SMOKE)
  add_executable(openms-legacy-gui-thermo-smoke tools/ThermoRawSmoke.cpp)
  target_link_libraries(openms-legacy-gui-thermo-smoke PRIVATE OpenMS)
endif()

install(DIRECTORY share/OpenMS/GUISTYLE
  DESTINATION ${CMAKE_INSTALL_DATADIR}/OpenMS)
install(DIRECTORY share/OpenMS/DESKTOP
  DESTINATION ${CMAKE_INSTALL_DATADIR}/OpenMS)
if(OPENMS_LEGACY_GUI_INSTALL_EXAMPLES)
  install(DIRECTORY share/OpenMS/examples/TOPPAS
    DESTINATION ${CMAKE_INSTALL_DATADIR}/OpenMS/examples)
endif()

if(UNIX AND NOT APPLE)
  install(FILES
    share/OpenMS/DESKTOP/TOPPAS.desktop
    share/OpenMS/DESKTOP/TOPPView.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
  install(FILES
    share/OpenMS/DESKTOP/TOPPAS.appdata.xml
    share/OpenMS/DESKTOP/TOPPView.appdata.xml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/metainfo)
  install(FILES src/openms_gui/source/VISUAL/ICONS/TOPPAS.png
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps
    RENAME TOPPAS.png)
  install(FILES src/openms_gui/source/VISUAL/ICONS/TOPPView.png
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps
    RENAME TOPPView.png)
endif()

if(OPENMS_LEGACY_GUI_BUILD_TESTS)
  enable_testing()
  add_subdirectory(src/tests/class_tests/openms_gui)
endif()

set(_openms_legacy_gui_cmake_dir "${CMAKE_INSTALL_LIBDIR}/cmake/OpenMSLegacyGUI")
configure_package_config_file(
  cmake/OpenMSLegacyGUIConfig.cmake.in
  "${CMAKE_CURRENT_BINARY_DIR}/OpenMSLegacyGUIConfig.cmake"
  INSTALL_DESTINATION "${_openms_legacy_gui_cmake_dir}"
)
write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/OpenMSLegacyGUIConfigVersion.cmake"
  VERSION "${PROJECT_VERSION}"
  COMPATIBILITY SameMinorVersion
)
install(EXPORT OpenMSLegacyGUITargets
  FILE OpenMSLegacyGUITargets.cmake
  NAMESPACE OpenMSLegacyGUI::
  DESTINATION "${_openms_legacy_gui_cmake_dir}"
)
install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/OpenMSLegacyGUIConfig.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/OpenMSLegacyGUIConfigVersion.cmake"
  DESTINATION "${_openms_legacy_gui_cmake_dir}"
)
install(FILES LICENSE README.md UPSTREAM_OPENMS_REVISION
  DESTINATION "${CMAKE_INSTALL_DATADIR}/doc/OpenMSLegacyGUI")

if(PROJECT_IS_TOP_LEVEL)
  set(CPACK_PACKAGE_NAME "OpenMSLegacyGUI")
  set(CPACK_PACKAGE_VENDOR "OpenMS")
  set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Legacy OpenMS Qt GUI tools and applications")
  set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
  set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
  if(WIN32)
    set(CPACK_GENERATOR ZIP)
  elseif(APPLE)
    set(CPACK_GENERATOR ZIP)
  else()
    set(CPACK_GENERATOR "TGZ;ZIP")
  endif()
  include(CPack)
endif()
