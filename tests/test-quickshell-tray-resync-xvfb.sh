#!/bin/sh
set -eu
repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ "${DWM_TRAY_RESYNC_SESSION:-0}" != 1 ]; then
	exec env DWM_TRAY_RESYNC_SESSION=1 dbus-run-session -- "$0"
fi
work=$(mktemp -d)
pids=
cleanup() {
	for pid in $pids; do
		kill "$pid" 2>/dev/null || true
	done
	for pid in $pids; do
		wait "$pid" 2>/dev/null || true
	done
	rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
mkdir -p "$work/qml" "$work/home" "$work/state" "$work/runtime" \
	"$work/data/dwm-titus/scripts"
chmod 700 "$work/runtime"
cp -a "$repo/config/quickshell/core" "$repo/config/quickshell/panel" "$work/qml/"
cp "$repo/tests/qml/TrayResyncUi.qml" "$work/qml/shell.qml"
cp "$repo/scripts/dwm-quickshell-tray" "$work/data/dwm-titus/scripts/"
helper=$work/data/dwm-titus/scripts/dwm-quickshell-tray

wait_for() {
	attempt=0
	until eval "$1"; do
		attempt=$((attempt + 1))
		if [ "$attempt" -ge 200 ]; then
			printf 'Timed out waiting for: %s\n' "$2" >&2
			for log in "$work"/*.log; do
				printf '== %s\n' "$log" >&2
				cat "$log" >&2
			done
			exit 1
		fi
		sleep 0.05
	done
}

Xvfb -displayfd 3 -screen 0 640x480x24 -nolisten tcp -extension GLX \
	3>"$work/display" >"$work/xvfb.log" 2>&1 &
pids="$pids $!"
# shellcheck disable=SC2016 # expanded later by wait_for
wait_for '[ -s "$work/display" ]' 'Xvfb display'
display=$(sed -n '1p' "$work/display")

start_shell() {
	env DISPLAY=":$display" HOME="$work/home" XDG_DATA_HOME="$work/data" \
		XDG_STATE_HOME="$work/state" XDG_RUNTIME_DIR="$work/runtime" \
		QT_QPA_PLATFORM=xcb QT_QPA_PLATFORMTHEME= \
		quickshell --no-duplicate --path "$work/qml/shell.qml" >"$work/$1.log" 2>&1 &
	shell_pid=$!
	pids="$pids $shell_pid"
}

latest_items() {
	grep -o 'TRAY_ITEMS .*' "$work/$1.log" | tail -n 1
}

# Without a watcher there is nothing to resync.
[ -z "$("$helper" resync)" ]

start_shell first
wait_for 'busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1' 'Quickshell watcher'
# A process name with spaces must not hide the item from the resync scan.
python3 -I "$repo/tests/fixtures/sni-item.py" --id unique-only --comm 'tray item app' \
	--ready "$work/unique.ready" &
pids="$pids $!"
python3 -I "$repo/tests/fixtures/sni-item.py" --id well-known \
	--name org.kde.StatusNotifierItem-4242-1 --ready "$work/named.ready" &
pids="$pids $!"
python3 -I "$repo/tests/fixtures/sni-item.py" --id plain --plain --ready "$work/plain.ready" &
pids="$pids $!"
# shellcheck disable=SC2016 # expanded later by wait_for
wait_for '[ -s "$work/unique.ready" ] && [ -s "$work/named.ready" ] && [ -s "$work/plain.ready" ]' \
	'tray item fixtures'
# shellcheck disable=SC2016 # expanded later by wait_for
wait_for '[ "$(latest_items first)" = "TRAY_ITEMS 2 unique-only,well-known" ]' \
	'both items in the first shell'

# Restart Quickshell. The fixture items, like Lark or KGpg, never register
# again, so only the startup resync can bring them back.
kill "$shell_pid"
wait "$shell_pid" 2>/dev/null || true
start_shell second
# shellcheck disable=SC2016 # expanded later by wait_for
wait_for '[ "$(latest_items second)" = "TRAY_ITEMS 2 unique-only,well-known" ]' \
	'both items after the restart'
sleep 1
if [ "$(latest_items second)" != "TRAY_ITEMS 2 unique-only,well-known" ]; then
	printf 'Tray items changed after resync: %s\n' "$(latest_items second)" >&2
	exit 1
fi
registered=$(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
	org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems)
case $registered in
*org.kde.StatusNotifierItem-4242-1*) ;;
*)
	printf 'Named item was not registered by its well-known name: %s\n' "$registered" >&2
	exit 1
	;;
esac
# A second resync finds every item registered and changes nothing.
[ -z "$("$helper" resync)" ]
if "$helper" resync extra 2>/dev/null; then
	printf 'resync accepted an extra argument\n' >&2
	exit 1
fi
printf 'Quickshell tray resync after restart: PASS\n'
