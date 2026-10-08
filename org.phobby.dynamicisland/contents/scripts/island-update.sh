#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
#
# island-update — fetch a version of the Dynamic Island from its repository and
# install it over the one that is there. Settings, accounts and data stay: only
# the widget's files and the native module are replaced (this is what
# `git pull && ./install.sh` does, without needing the folder it was cloned to).
#
#   island-update.sh latest|VERSION [--restart]   fetch, build, install
#   island-update.sh --check                      which version is installed, which is the newest
#   island-update.sh --restart-only               restart the desktop shell
#
# The island runs it when you choose "Update"; it can be run by hand too:
#   sh ~/.local/share/plasma/plasmoids/org.phobby.dynamicisland/contents/scripts/island-update.sh latest --restart
#
# What it says while it works, one line each (the island reads them):
#   STEP download | unpack | build | install | restart     PROGRESS 0-100 (the build)
#   DONE version      ERROR what (and exit 1); the installer's own output is in
#   ~/.cache/dynamicisland/update/install.log
#
# It asks for no password. It downloads one archive, from the island's own
# repository over HTTPS (the tag v<version>; `main` when there is no such tag),
# and runs the install.sh inside it.
#
# (All of it is one function, read to its end before anything runs: the
# installer replaces this very file.)
main() {
    set -u
    repo="${ISLAND_UPDATE_SOURCE:-https://github.com/Phobby/plasma-island}"
    raw="${ISLAND_UPDATE_RAW:-https://raw.githubusercontent.com/Phobby/plasma-island}"
    id="org.phobby.dynamicisland"
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/dynamicisland/update"

    restart_shell() {
        echo "STEP restart"
        [ -n "${ISLAND_UPDATE_NO_RESTART:-}" ] && return 0
        if systemctl --user is-active --quiet plasma-plasmashell 2>/dev/null; then
            systemctl --user restart plasma-plasmashell
        else
            (setsid plasmashell --replace >/dev/null 2>&1 &)
        fi
    }
    fail() { echo "ERROR $1"; exit 1; }
    version_in() { sed -n 's/.*"Version"[[:space:]]*:[[:space:]]*"\([0-9.]*\)".*/\1/p' "$1" | head -n 1; }

    [ "${1:-}" = "--restart-only" ] && { restart_shell; exit 0; }
    if [ "${1:-}" = "--check" ]; then
        # (this file is contents/scripts/ of the installed widget)
        here="$(cd "$(dirname "$0")" && pwd)"
        installed="$(version_in "$here/../../metadata.json" 2>/dev/null)"
        echo "installed ${installed:-unknown}"
        newest="$(curl -fsSL --max-time 30 "$raw/main/$id/metadata.json" 2>/dev/null | sed -n 's/.*"Version"[[:space:]]*:[[:space:]]*"\([0-9.]*\)".*/\1/p' | head -n 1)"
        [ -n "$newest" ] || { echo "newest unknown (the repository could not be reached)"; exit 1; }
        echo "newest $newest"
        exit 0
    fi
    version="${1:-}"; restart=0
    [ "${2:-}" = "--restart" ] && restart=1
    command -v curl >/dev/null 2>&1 || fail "curl is not installed"
    command -v tar >/dev/null 2>&1 || fail "tar is not installed"
    mkdir -p "$cache" || fail "cannot write to $cache"

    # One at a time (a lock left behind by one that was killed is given up after half an hour).
    [ -d "$cache/lock" ] && [ -n "$(find "$cache/lock" -maxdepth 0 -mmin +30 2>/dev/null)" ] && rmdir "$cache/lock" 2>/dev/null
    mkdir "$cache/lock" 2>/dev/null || fail "an update is running already"
    trap 'rmdir "$cache/lock" 2>/dev/null' EXIT
    trap 'exit 1' INT TERM HUP

    echo "STEP download"
    if [ "$version" = "latest" ]; then
        curl -fsSL --max-time 30 -o "$cache/latest.json" "$raw/main/$id/metadata.json" || fail "the repository could not be reached"
        version="$(version_in "$cache/latest.json")"
    fi
    case "$version" in ''|.*|*[!0-9.]*) fail "not a version: $version" ;; esac
    curl -fsSL --max-time 600 -o "$cache/source.tar.gz" "$repo/archive/refs/tags/v$version.tar.gz" 2>/dev/null \
        || curl -fsSL --max-time 600 -o "$cache/source.tar.gz" "$repo/archive/refs/heads/main.tar.gz" \
        || fail "version $version could not be downloaded"

    echo "STEP unpack"
    rm -rf "$cache/source"
    mkdir "$cache/source" && tar -xzf "$cache/source.tar.gz" -C "$cache/source" --strip-components=1 || fail "the download could not be unpacked"
    [ -f "$cache/source/install.sh" ] && [ -f "$cache/source/$id/metadata.json" ] || fail "the download is not the island"
    got="$(version_in "$cache/source/$id/metadata.json")"
    [ "$got" = "$version" ] || fail "the download is version ${got:-?}, not $version"

    # The installer says how far the build is on descriptor 3; everything else it says goes to the log.
    echo "STEP build"
    if ! ( cd "$cache/source" && ISLAND_INSTALL_PROGRESS=1 bash ./install.sh 3>&1 >"$cache/install.log" 2>&1 ); then
        fail "the installer failed: see $cache/install.log"
    fi
    echo "STEP install"
    rm -rf "$cache/source" "$cache/source.tar.gz" "$cache/latest.json"
    rmdir "$cache/lock" 2>/dev/null
    echo "DONE $version"
    [ $restart -eq 1 ] && restart_shell
    exit 0
}
main "$@"
