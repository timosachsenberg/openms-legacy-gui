# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause

include(includes.cmake)
include(GenerateExportHeader)

add_library(OpenMSLegacyGUI ${OpenMSVisual_sources})
add_library(OpenMSLegacyGUI::OpenMSLegacyGUI ALIAS OpenMSLegacyGUI)
target_compile_features(OpenMSLegacyGUI PUBLIC cxx_std_23)
target_include_directories(OpenMSLegacyGUI
  PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>"
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
)
target_link_libraries(OpenMSLegacyGUI
  PUBLIC
    OpenMS
    ${OPENMS_LEGACY_GUI_QT_LIBRARIES}
)
set_target_properties(OpenMSLegacyGUI PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN YES
  VERSION "${PROJECT_VERSION}"
  SOVERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}"
)

set(_openms_gui_config_header
  "${CMAKE_CURRENT_BINARY_DIR}/include/OpenMS/VISUAL/OpenMS_GUIConfig.h")
generate_export_header(OpenMSLegacyGUI
  EXPORT_MACRO_NAME OPENMS_GUI_DLLAPI
  EXPORT_FILE_NAME "${_openms_gui_config_header}"
  STATIC_DEFINE OPENMS_GUI_STATIC_DEFINE
)
if(NOT BUILD_SHARED_LIBS)
  target_compile_definitions(OpenMSLegacyGUI PUBLIC OPENMS_GUI_STATIC_DEFINE)
endif()
if(OPENMS_LEGACY_GUI_PORTABLE)
  target_compile_definitions(OpenMSLegacyGUI PRIVATE OPENMS_LEGACY_GUI_PORTABLE)
endif()

if(MSVC)
  target_compile_options(OpenMSLegacyGUI PRIVATE /we4100 /we4189)
  target_link_options(OpenMSLegacyGUI PRIVATE
    /FORCE:MULTIPLE /INCREMENTAL:NO /ignore:4006 /ignore:4088)
endif()

get_property(_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(_is_multi_config)
  set(_autogen_include_dir
    "${CMAKE_CURRENT_BINARY_DIR}/OpenMSLegacyGUI_autogen/include_$<CONFIG>")
else()
  set(_autogen_include_dir
    "${CMAKE_CURRENT_BINARY_DIR}/OpenMSLegacyGUI_autogen/include")
endif()
target_include_directories(OpenMSLegacyGUI
  INTERFACE "$<BUILD_INTERFACE:${_autogen_include_dir}>")

install(TARGETS OpenMSLegacyGUI
  EXPORT OpenMSLegacyGUITargets
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(DIRECTORY include/OpenMS
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
  FILES_MATCHING PATTERN "*.h")
install(FILES "${_openms_gui_config_header}"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/OpenMS/VISUAL")

set(GUI_DIR source/VISUAL/APPLICATIONS/GUITOOLS)
include(${GUI_DIR}/executables.cmake)

foreach(_app IN LISTS GUI_executables)
  set(_app_sources "${GUI_DIR}/${_app}.cpp")
  set(_resource_file "${CMAKE_CURRENT_SOURCE_DIR}/${GUI_DIR}/${_app}.rc")
  set(_resource_dir "${CMAKE_CURRENT_SOURCE_DIR}/${GUI_DIR}/${_app}-resources")

  if(MSVC AND EXISTS "${_resource_file}")
    list(APPEND _app_sources "${_resource_file}")
  endif()

  if(APPLE)
    add_executable(${_app} MACOSX_BUNDLE ${_app_sources})
    set_target_properties(${_app} PROPERTIES
      MACOSX_BUNDLE_GUI_IDENTIFIER "org.openms.${_app}"
      MACOSX_BUNDLE_BUNDLE_NAME "${_app}"
      MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
      MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
      INSTALL_RPATH "@executable_path/../Frameworks"
    )
    if(IS_DIRECTORY "${_resource_dir}")
      set(_icon_file "${_resource_dir}/${_app}.icns")
      set(_plist_file "${_resource_dir}/${_app}.plist.in")
      target_sources(${_app} PRIVATE "${_icon_file}")
      set_source_files_properties("${_icon_file}" PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources)
      set_target_properties(${_app} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${_plist_file}"
        MACOSX_BUNDLE_ICON_FILE "${_app}.icns"
      )
    endif()
  else()
    add_executable(${_app} ${_app_sources})
  endif()

  target_compile_features(${_app} PRIVATE cxx_std_23)
  target_link_libraries(${_app} PRIVATE OpenMSLegacyGUI)
  install(TARGETS ${_app}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    BUNDLE DESTINATION .)
endforeach()

# These GUI TOPP tools use TOPPBase directly rather than only through the GUI library.
target_link_libraries(ExecutePipeline PRIVATE OpenMS)
target_link_libraries(ImageCreator PRIVATE OpenMS)

add_custom_target(GUI DEPENDS ${GUI_executables})
