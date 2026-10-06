# For the tests only (tools/run-tests builds it into tests/.run/helper): wheel
# steps as a touchpad sends them, which QtTest's mouseWheel() cannot make.
cmake_minimum_required(VERSION 3.16)
project(dynamicisland-test-helper LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_qml_module(islandtest
    URI IslandTest
    VERSION 1.0
    PLUGIN_TARGET islandtest
    SOURCES wheelsender.h wheelsender.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/IslandTest
)
target_link_libraries(islandtest PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick)
