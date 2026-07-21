# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
# 
# --------------------------------------------------------------------------
# $Maintainer: Stephan Aiche $
# $Authors: Stephan Aiche $
# --------------------------------------------------------------------------


set(visual_executables_list
  AxisTickCalculator_test
  FileWatcher_test
  GUIHelpers_test
  MultiGradient_test
)

add_custom_target(VISUAL_TEST)
add_dependencies(VISUAL_TEST ${visual_executables_list})

foreach(_class_test ${visual_executables_list})
  add_executable(${_class_test} source/${_class_test}.cpp)
  target_link_libraries(${_class_test} PRIVATE OpenMSLegacyGUI)
  add_test(NAME ${_class_test} COMMAND ${_class_test})
  set_tests_properties(${_class_test} PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
endforeach(_class_test)

#------------------------------------------------------------------------------
# GUI tests special treatment - Apply MOC compiler to GUI
#------------------------------------------------------------------------------

# we only want to run those tests if we have a running XServer
if(OPENMS_LEGACY_GUI_BUILD_INTERACTIVE_TESTS)
  set(GUI_executables_list
    TOPPView_test
    TSGDialog_test
  )

  #------------------------------------------------------------------------------
  # Use QtTest lib

  find_package(Qt6 REQUIRED
    Test
  )
  if (NOT Qt6Test_FOUND)
    message(STATUS "QtTest module not found!")
    message(FATAL_ERROR "To find a custom Qt installation use: cmake <..more options..> -D QT_QMAKE_EXECUTABLE='<path_to_qmake(.exe)' <src-dir>")
  endif()

  #------------------------------------------------------------------------------
  # Add GUI tests
  foreach(_gui_test ${GUI_executables_list})
    # add the executable (Note: The header needs to be added as source file, too. Otherwise automoc will not find it.
    add_executable(${_gui_test} source/GUI/${_gui_test}.cpp ${CMAKE_CURRENT_SOURCE_DIR}/include/GUI/${_gui_test}.h)
    # The dialog UI headers come from OpenMSLegacyGUI's AUTOUIC output, exposed
    # through its build interface. Do not make the test target regenerate them.
    set_target_properties(${_gui_test} PROPERTIES AUTOUIC OFF)
    # add headers
    target_include_directories(${_gui_test} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include/GUI)
    # link against openms_gui and qt
    target_link_libraries(${_gui_test} PRIVATE OpenMSLegacyGUI Qt6::Test)
    # add the test
    add_test(NAME ${_gui_test} COMMAND ${_gui_test})
  endforeach(_gui_test)

  #------------------------------------------------------------------------------
  # GUI tests
  add_custom_target(GUI_TEST)
  add_dependencies(GUI_TEST ${GUI_executables_list})

endif()
