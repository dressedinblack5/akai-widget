cmake_minimum_required(VERSION 3.16)
project(plasmoid-akai-chat VERSION 1.0 LANGUAGES CXX)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

find_package(Plasma REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS Quick)

set(PLASMOID_NAME "akai-chat")

install(
    DIRECTORY package/
    DESTINATION ${KDE_INSTALL_PACKAGESDIR}/plasma/plasmoids/${PLASMOID_NAME}
)

# ---- Tests ----
option(BUILD_TESTS "Build and register tests" OFF)
if(BUILD_TESTS)
    enable_testing()
    add_test(
        NAME akai-chat-unit
        COMMAND node ${CMAKE_SOURCE_DIR}/tests/tst_utils.js
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    )
    add_test(
        NAME akai-chat-integration
        COMMAND ${CMAKE_SOURCE_DIR}/tests/run_tests.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    )
endif()
