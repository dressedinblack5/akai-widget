cmake_minimum_required(VERSION 3.16)
project(plasmoid-akai-widget VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

find_package(Plasma REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS Quick Qml Core)

set(PLASMOID_NAME "akai-widget")

qt_add_qml_module(akaiwidgetplugin
    URI "Akaiprocess"
    VERSION 1.0
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/package/contents/ui/code
    SOURCES
        package/contents/code/processmanager.cpp
        package/contents/code/processmanager.h
        package/contents/code/storagehelper.cpp
        package/contents/code/storagehelper.h
)

target_include_directories(akaiwidgetplugin PRIVATE ${CMAKE_SOURCE_DIR}/package/contents/code)

set_target_properties(akaiwidgetplugin PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/package/contents/ui/code
)

set_target_properties(akaiwidgetpluginplugin PROPERTIES
    INSTALL_RPATH "$ORIGIN"
    BUILD_RPATH "$ORIGIN"
)

install(TARGETS akaiwidgetplugin akaiwidgetpluginplugin
    DESTINATION ${KDE_INSTALL_PACKAGESDIR}/plasma/plasmoids/${PLASMOID_NAME}/contents/ui/code
)

install(FILES ${CMAKE_BINARY_DIR}/package/contents/ui/code/qmldir
    DESTINATION ${KDE_INSTALL_PACKAGESDIR}/plasma/plasmoids/${PLASMOID_NAME}/contents/ui/code
)

install(
    DIRECTORY package/
    DESTINATION ${KDE_INSTALL_PACKAGESDIR}/plasma/plasmoids/${PLASMOID_NAME}
    PATTERN "code" EXCLUDE
)

option(BUILD_TESTS "Build and register tests" OFF)
if(BUILD_TESTS)
    enable_testing()
    add_test(
        NAME akai-widget-unit
        COMMAND node ${CMAKE_SOURCE_DIR}/tests/tst_utils.js
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    )
endif()
