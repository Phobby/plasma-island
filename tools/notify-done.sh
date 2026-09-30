# notify-done — run a long command and let the Dynamic Island follow it.
#
#   source /path/to/notify-done.sh     (e.g. from ~/.bashrc or ~/.zshrc)
#   notify-done make -j16
#   notify-done cargo build --release
#
# While the command runs, the island shows it as a live activity with the
# elapsed time; when it ends you get "Done" (green) or "Failed" (red).
notify-done() {
    if [ $# -eq 0 ]; then
        echo "usage: notify-done <command> [args…]" >&2
        return 2
    fi
    local id="cmd-$$-$RANDOM" start rc
    start=$(date +%s)
    island-push --id "$id" --title "$*" --subtitle "Running…" --icon system-run --color blue 2>/dev/null
    # Refresh the elapsed time every 10 s in the background.
    ( while sleep 10; do
          island-push --id "$id" --trailing "$(( ($(date +%s) - start) / 60 ))m$(( ($(date +%s) - start) % 60 ))s" 2>/dev/null || break
      done ) &
    local ticker=$!
    "$@"
    rc=$?
    kill "$ticker" 2>/dev/null
    wait "$ticker" 2>/dev/null
    local took=$(( $(date +%s) - start ))
    if [ $rc -eq 0 ]; then
        island-push --id "$id" --subtitle "${took}s" --done --status success 2>/dev/null
    else
        island-push --id "$id" --subtitle "exit $rc · ${took}s" --done --status error 2>/dev/null
    fi
    return $rc
}
