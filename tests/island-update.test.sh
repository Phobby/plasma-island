#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# The island's updater (contents/scripts/island-update.sh) against a made-up
# repository in tests/.run: an archive with an install.sh that only notes that
# it ran. Nothing is fetched from the network, nothing is installed, no shell
# is restarted. Run by tools/run-tests; prints one line.
here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../org.phobby.dynamicisland/contents/scripts/island-update.sh"
box="$here/.run/island-update"
rm -rf "$box"; mkdir -p "$box/home" "$box/repo/archive/refs/tags" "$box/repo/archive/refs/heads" "$box/raw/main/org.phobby.dynamicisland"
failed=0
check() { if [ "$2" != "$3" ]; then echo "FAIL $1: expected '$3', got '$2'"; failed=1; fi; }

# an archive as GitHub makes them: one folder, the island in it
archive() {   # VERSION FILE [installer's exit code]
    rm -rf "$box/make"; mkdir -p "$box/make/plasma-island-$1/org.phobby.dynamicisland"
    printf '{ "KPlugin": { "Id": "org.phobby.dynamicisland", "Version": "%s" } }\n' "$1" > "$box/make/plasma-island-$1/org.phobby.dynamicisland/metadata.json"
    printf '#!/usr/bin/env bash\necho "installer output"\necho "PROGRESS 40" >&3\necho "PROGRESS 100" >&3\necho ran >> "%s/ran"\nexit %s\n' "$box" "${3:-0}" > "$box/make/plasma-island-$1/install.sh"
    tar -czf "$2" -C "$box/make" "plasma-island-$1"
}
update() { env HOME="$box/home" XDG_CACHE_HOME="$box/home/.cache" ISLAND_UPDATE_SOURCE="file://$box/repo" ISLAND_UPDATE_RAW="file://$box/raw" ISLAND_UPDATE_NO_RESTART=1 sh "$script" "$@" 2>&1; }

archive 0.2.0 "$box/repo/archive/refs/tags/v0.2.0.tar.gz"
printf '{ "KPlugin": { "Version": "0.2.0" } }\n' > "$box/raw/main/org.phobby.dynamicisland/metadata.json"

out="$(update 0.2.0 --restart)"; code=$?
check "a version: exit code" "$code" 0
check "a version: what it says" "$(echo "$out" | tr '\n' ' ')" "STEP download STEP unpack STEP build PROGRESS 40 PROGRESS 100 STEP install DONE 0.2.0 STEP restart "
check "the installer ran once" "$(wc -l < "$box/ran" | tr -d ' ')" 1
check "its output is in the log" "$(cat "$box/home/.cache/dynamicisland/update/install.log")" "installer output"
check "nothing is left of the download" "$(ls "$box/home/.cache/dynamicisland/update" | tr '\n' ' ')" "install.log "

check "latest" "$(update latest | tail -n 1)" "DONE 0.2.0"
check "without --restart the shell stays" "$(update 0.2.0 | grep -c 'STEP restart')" 0
check "only the restart" "$(update --restart-only)" "STEP restart"
check "which version" "$(update --check | tr '\n' ' ')" "installed $(sed -n 's/.*"Version": "\(.*\)".*/\1/p' "$here/../org.phobby.dynamicisland/metadata.json") newest 0.2.0 "

# no tag of that version: `main`, when it is that version
archive 0.3.0 "$box/repo/archive/refs/heads/main.tar.gz"
check "from main" "$(update 0.3.0 | tail -n 1)" "DONE 0.3.0"
out="$(update 0.4.0)"; code=$?
check "another version than asked for: exit code" "$code" 1
check "another version than asked for" "$(echo "$out" | tail -n 1)" "ERROR the download is version 0.3.0, not 0.4.0"

before="$(wc -l < "$box/ran" | tr -d ' ')"
for bad in "" "1.0; rm -rf x" "../1" "v1" ".1"; do
    out="$(update "$bad")"; check "not a version '$bad'" "$?" 1
done
check "nothing ran for those" "$(wc -l < "$box/ran" | tr -d ' ')" "$before"

archive 0.5.0 "$box/repo/archive/refs/tags/v0.5.0.tar.gz" 1
out="$(update 0.5.0 --restart)"; code=$?
check "the installer failed: exit code" "$code" 1
check "the installer failed: no restart" "$(echo "$out" | grep -c 'STEP restart\|DONE')" 0
check "and the next one can run" "$(update 0.2.0 | tail -n 1)" "DONE 0.2.0"

mkdir -p "$box/home/.cache/dynamicisland/update/lock"
check "one at a time" "$(update 0.2.0 | tail -n 1)" "ERROR an update is running already"
rmdir "$box/home/.cache/dynamicisland/update/lock"

[ $failed -eq 0 ] && echo "island-update: ok"
exit $failed
