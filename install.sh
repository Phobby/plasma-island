#!/usr/bin/env bash
# Install / update the Dynamic Island plasmoid and its native modules.
#
#   ./install.sh               install or upgrade the plasmoid, build + install
#                              the native modules (blur, PipeWire, D-Bus API…)
#                              and the island-push tool
#   ./install.sh --no-native   plasmoid only (QML features only)
#   ./install.sh --remove      uninstall everything
#
# Native modules are installed per user to ~/.local/lib/qml and made visible
# to plasmashell through QML_IMPORT_PATH (systemd environment.d).
# island-push goes to ~/.local/bin.
set -euo pipefail

ID="org.phobby.dynamicisland"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$HERE/$ID"
QML_DIR="$HOME/.local/lib/qml"
ENV_FILE="$HOME/.config/environment.d/90-dynamicisland.conf"

BIN_DIR="$HOME/.local/bin"

native=1
remove=0
for arg in "$@"; do
    case "$arg" in
        --with-blur) native=1 ;;   # kept for compatibility: native is the default now
        --no-native) native=0 ;;
        --remove) remove=1 ;;
        -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [[ $remove -eq 1 ]]; then
    kpackagetool6 -t Plasma/Applet -r "$ID" || true
    rm -rf "$QML_DIR/org/phobby/dynamicisland"
    rmdir "$QML_DIR/org/phobby" "$QML_DIR/org" 2>/dev/null || true     # only when nothing else is in them
    rm -f "$ENV_FILE"
    rm -f "$BIN_DIR/island-push"
    echo "Removed. Restart plasmashell: systemctl --user restart plasma-plasmashell"
    exit 0
fi

if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$ID"; then
    echo "==> Upgrading $ID"
    kpackagetool6 -t Plasma/Applet -u "$PKG"
else
    echo "==> Installing $ID"
    kpackagetool6 -t Plasma/Applet -i "$PKG"
fi

if [[ $native -eq 1 ]] && ! command -v cmake >/dev/null 2>&1; then
    echo "!! cmake not found: skipping the native modules (install: cmake extra-cmake-modules"
    echo "   qt6-base-dev qt6-declarative-dev libkf6windowsystem-dev, then run ./install.sh again)"
    native=0
fi

if [[ $native -eq 1 ]]; then
    echo "==> Building native modules"
    if ! cmake -S "$HERE/native" -B "$HERE/native/build" -DCMAKE_BUILD_TYPE=Release \
             -DCMAKE_INSTALL_PREFIX="$HOME/.local" -DQML_INSTALL_DIR="$QML_DIR" >/dev/null \
       || ! cmake --build "$HERE/native/build" -j"$(nproc)" >/dev/null; then
        echo "!! Native build failed. The widget still works without: blur, screen recording,"
        echo "   privacy indicators, unlock, calls, updates and the D-Bus API are then disabled."
        exit 1
    fi
    cmake --install "$HERE/native/build" >/dev/null
    echo "    installed to $QML_DIR/org/phobby/dynamicisland/{effects,core}"

    mkdir -p "$BIN_DIR"
    install -m 755 "$HERE/tools/island-push" "$BIN_DIR/island-push"
    echo "    island-push installed to $BIN_DIR"

    mkdir -p "$(dirname "$ENV_FILE")"
    echo "QML_IMPORT_PATH=$QML_DIR\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}" > "$ENV_FILE"
    # Make it effective for the running session without re-login.
    systemctl --user set-environment "QML_IMPORT_PATH=$QML_DIR${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" || true
    echo "    QML_IMPORT_PATH configured in $ENV_FILE"
fi

cat <<EOF

Done. Next steps:
  * Reload plasmashell:   systemctl --user restart plasma-plasmashell
                          (or: plasmashell --replace & disown)
  * Add the widget:       right-click desktop or panel → Add Widgets… → "Dynamic Island"
  * Preview standalone:   plasmoidviewer -a $ID      (package: plasma-sdk)
  * Logs:                 journalctl --user -f | grep -i -E "dynamicisland|qml"
  * Shell helper:         source $HERE/tools/notify-done.sh   (then: notify-done make)
EOF
