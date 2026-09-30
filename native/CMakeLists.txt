# Optional native helper for org.phobby.dynamicisland: gives the island a
# pill-shaped KWin blur region (Plasma's Dialog can only blur the theme frame).
cmake_minimum_required(VERSION 3.16)
project(dynamicisland-effects LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml)
find_package(KF6WindowSystem REQUIRED)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_qml_module(dynamicislandeffects
    URI org.phobby.dynamicisland.effects
    VERSION 1.0
    PLUGIN_TARGET dynamicislandeffects
    NO_GENERATE_PLUGIN_SOURCE
    CLASS_NAME DynamicIslandEffectsPlugin
    SOURCES windowblur.h windowblur.cpp plugin.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/org/phobby/dynamicisland/effects
)

target_link_libraries(dynamicislandeffects PRIVATE Qt6::Core Qt6::Gui Qt6::Qml KF6::WindowSystem)

# Installs to <prefix>/org/phobby/dynamicisland/effects; install.sh passes a
# prefix that is on QML_IMPORT_PATH (or the system QML dir with sudo).
set(QML_INSTALL_DIR "lib/qml" CACHE PATH "QML import directory")
install(TARGETS dynamicislandeffects DESTINATION ${QML_INSTALL_DIR}/org/phobby/dynamicisland/effects)
install(FILES
    ${CMAKE_BINARY_DIR}/qml/org/phobby/dynamicisland/effects/qmldir
    ${CMAKE_BINARY_DIR}/qml/org/phobby/dynamicisland/effects/dynamicislandeffects.qmltypes
    DESTINATION ${QML_INSTALL_DIR}/org/phobby/dynamicisland/effects)
