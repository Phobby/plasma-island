# Native helpers for org.phobby.dynamicisland:
#   org.phobby.dynamicisland.effects  pill-shaped KWin blur region
#   org.phobby.dynamicisland.core     PipeWire usage, D-Bus signals/calls,
#                                     D-Bus API service, update counter,
#                                     passwords in KWallet, OAuth loopback,
#                                     local notes app helpers, open popup menus,
#                                     audio levels for the ambient glow,
#                                     a command read while it runs (AI tab)
cmake_minimum_required(VERSION 3.16)
project(dynamicisland-effects LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml DBus Network Sql)
find_package(KF6WindowSystem REQUIRED)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_qml_module(dynamicislandeffects
    URI org.phobby.dynamicisland.effects
    VERSION 1.0
    PLUGIN_TARGET dynamicislandeffects
    NO_GENERATE_PLUGIN_SOURCE
    CLASS_NAME DynamicIslandEffectsPlugin
    SOURCES windowblur.h windowblur.cpp windowmask.h windowmask.cpp plugin.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/org/phobby/dynamicisland/effects
)

target_link_libraries(dynamicislandeffects PRIVATE Qt6::Core Qt6::Gui Qt6::Qml KF6::WindowSystem)

# Installs to <prefix>/org/phobby/dynamicisland/effects; install.sh passes a
# prefix that is on QML_IMPORT_PATH (or the system QML dir with sudo).
set(QML_INSTALL_DIR "lib/qml" CACHE STRING "QML import directory (absolute, or relative to CMAKE_INSTALL_PREFIX)")
install(TARGETS dynamicislandeffects DESTINATION ${QML_INSTALL_DIR}/org/phobby/dynamicisland/effects)
install(FILES
    ${CMAKE_BINARY_DIR}/qml/org/phobby/dynamicisland/effects/qmldir
    ${CMAKE_BINARY_DIR}/qml/org/phobby/dynamicisland/effects/dynamicislandeffects.qmltypes
    DESTINATION ${QML_INSTALL_DIR}/org/phobby/dynamicisland/effects)

# ---- core -------------------------------------------------------------------
qt_add_qml_module(dynamicislandcore
    URI org.phobby.dynamicisland.core
    VERSION 1.0
    PLUGIN_TARGET dynamicislandcore
    NO_GENERATE_PLUGIN_SOURCE
    CLASS_NAME DynamicIslandCorePlugin
    SOURCES
        core/plugin.cpp
        core/pipewirewatcher.h core/pipewirewatcher.cpp
        core/dbussignalwatcher.h core/dbussignalwatcher.cpp
        core/launcher.h core/launcher.cpp
        core/updateschecker.h core/updateschecker.cpp
        core/islandservice.h core/islandservice.cpp
        core/downloadwatcher.h core/downloadwatcher.cpp
        core/commandwatcher.h core/commandwatcher.cpp
        core/packagekitwatcher.h core/packagekitwatcher.cpp
        core/secretstore.h core/secretstore.cpp
        core/loopbackserver.h core/loopbackserver.cpp
        core/localtools.h core/localtools.cpp
        core/userpaths.h core/userpaths.cpp
        core/popupwatcher.h core/popupwatcher.cpp
        core/audiolevels.h core/audiolevels.cpp
        core/streamprocess.h core/streamprocess.cpp
        core/filedrag.h core/filedrag.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/org/phobby/dynamicisland/core
)
target_include_directories(dynamicislandcore PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/core)
target_link_libraries(dynamicislandcore PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::DBus Qt6::Network Qt6::Sql)
install(TARGETS dynamicislandcore DESTINATION ${QML_INSTALL_DIR}/org/phobby/dynamicisland/core)
install(FILES
    ${CMAKE_BINARY_DIR}/qml/org/phobby/dynamicisland/core/qmldir
    ${CMAKE_BINARY_DIR}/qml/org/phobby/dynamicisland/core/dynamicislandcore.qmltypes
    DESTINATION ${QML_INSTALL_DIR}/org/phobby/dynamicisland/core)
