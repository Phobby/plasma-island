#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Opens btop in the user's terminal, showing only the graph of one metric.
#
#   btop-view.sh <cpu|temp|battery|gpu|ram|disk|net>         find a terminal, run there
#   btop-view.sh --in-terminal <metric>                      (internal) run btop here
#
# btop gets its own config (-c), derived from the user's btop.conf so the
# colour theme carries over while the user's own layout stays untouched.

if [ "$1" != "--in-terminal" ]; then
    metric=$1
    term=$(kreadconfig6 --file kdeglobals --group General --key TerminalApplication 2>/dev/null)
    command -v "${term%% *}" >/dev/null 2>&1 || term=
    if [ -z "$term" ]; then
        for t in konsole alacritty kitty foot xterm; do
            command -v "$t" >/dev/null 2>&1 && { term=$t; break; }
        done
    fi
    [ -n "$term" ] || exit 1
    # shellcheck disable=SC2086  # the setting may carry arguments
    exec $term -e sh "$0" --in-terminal "$metric"
fi

metric=$2
if ! command -v btop >/dev/null 2>&1; then
    echo "btop is not installed (sudo apt install btop)."
    echo "Press Enter to close."
    read -r _
    exit 1
fi
# btop older than 1.4 has no --config: open it with the user's own layout.
btop --help 2>&1 | grep -q -- '--config' || exec btop

extra=
case "$metric" in
    cpu|temp|battery) boxes="cpu" ;;
    gpu)  boxes="gpu0" ;;
    ram)  boxes="mem"; extra='show_disks = False
mem_graphs = True' ;;
    disk) boxes="mem"; extra='show_disks = True
io_mode = True' ;;
    net)  boxes="net" ;;
    *)    exec btop ;;
esac

dir="${XDG_CACHE_HOME:-$HOME/.cache}/dynamicisland"
conf="$dir/btop-$metric.conf"
base="${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf"
mkdir -p "$dir" || exec btop
{
    [ -f "$base" ] && grep -v -E '^(shown_boxes|show_disks|mem_graphs|io_mode)[[:space:]]*=' "$base"
    printf 'shown_boxes = "%s"\n' "$boxes"
    [ -n "$extra" ] && printf '%s\n' "$extra"
} > "$conf"
exec btop -c "$conf"
