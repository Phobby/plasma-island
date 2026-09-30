#!/usr/bin/env bash
# Install / update the Dynamic Island plasmoid (and optionally its native blur helper).
#
#   ./install.sh               install or upgrade the plasmoid for this user
#   ./install.sh --with-blur   also build + install the native blur helper
#   ./install.sh --remove      uninstall plasmoid and helper
#
# The native helper is installed per user to ~/.local/lib/qml and made
# visible to plasmashell through QML_IMPORT_PATH (systemd environment.d).
set -euo pipefail

ID="org.phobby.dynamicisland"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$HERE/$ID"
QML_DIR="$HOME/.local/lib/qml"
ENV_FILE="$HOME/.config/environment.d/90-dynamicisland.conf"

with_blur=0
remove=0
for arg in "$@"; do
    case "$arg" in
        --with-blur) with_blur=1 ;;
        --remove) remove=1 ;;
        -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [[ $remove -eq 1 ]]; then
    kpackagetool6 -t Plasma/Applet -r "$ID" || true
    rm -rf "$QML_DIR/org/phobby/dynamicisland"
    rm -f "$ENV_FILE"
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

if [[ $with_blur -eq 1 ]]; then
    echo "==> Building native blur helper"
    cmake -S "$HERE/native" -B "$HERE/native/build" -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="$HOME/.local" -DQML_INSTALL_DIR="lib/qml" >/dev/null
    cmake --build "$HERE/native/build" -j"$(nproc)"
    cmake --install "$HERE/native/build" >/dev/null
    echo "    installed to $QML_DIR/org/phobby/dynamicisland/effects"

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
EOF
