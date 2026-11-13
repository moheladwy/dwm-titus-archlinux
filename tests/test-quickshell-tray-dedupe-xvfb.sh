#!/bin/sh
# An app with an open window shows one panel icon: its tray icon is hidden
# while the running-app button is shown, and returns when the window closes.
# Only the one item the button takes over is hidden; a second tray item of
# the same app stays in the tray so its menu remains reachable.
# Tray-only apps stay visible, and a window class never claims a tray item
# whose name merely starts with the same letters.
set -eu
repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ "${DWM_TRAY_DEDUPE_SESSION:-0}" != 1 ]; then
	exec env DWM_TRAY_DEDUPE_SESSION=1 dbus-run-session -- "$0"
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
cp "$repo/tests/qml/TrayDedupeUi.qml" "$work/qml/shell.qml"
cp "$repo/scripts/dwm-quickshell-tray" "$work/data/dwm-titus/scripts/"

fail() {
	printf '%s\n' "$1" >&2
	for log in "$work"/*.log; do
		printf '== %s\n' "$log" >&2
		cat "$log" >&2
	done
	exit 1
}

wait_for() {
	attempt=0
	until eval "$1"; do
		attempt=$((attempt + 1))
		[ "$attempt" -lt 200 ] || fail "Timed out waiting for: $2"
		sleep 0.05
	done
}

Xvfb -displayfd 3 -screen 0 640x480x24 -nolisten tcp -extension GLX \
	3>"$work/display" >"$work/xvfb.log" 2>&1 &
pids="$pids $!"
# shellcheck disable=SC2016 # expanded later by wait_for
wait_for '[ -s "$work/display" ]' 'Xvfb display'
display=$(sed -n '1p' "$work/display")

run_shell() {
	env DISPLAY=":$display" HOME="$work/home" XDG_DATA_HOME="$work/data" \
		XDG_STATE_HOME="$work/state" XDG_RUNTIME_DIR="$work/runtime" \
		QT_QPA_PLATFORM=xcb QT_QPA_PLATFORMTHEME= \
		quickshell "$@"
}

run_shell --no-duplicate --path "$work/qml/shell.qml" >"$work/shell.log" 2>&1 &
pids="$pids $!"
wait_for 'busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1' 'Quickshell watcher'

for id in lark_status_icon_1 lark_status_icon_2 background-only zenity; do
	python3 -I "$repo/tests/fixtures/sni-item.py" --id "$id" --ready "$work/$id.ready" &
	pids="$pids $!"
done
# shellcheck disable=SC2016 # expanded later by wait_for
wait_for '[ -s "$work/lark_status_icon_1.ready" ] && [ -s "$work/lark_status_icon_2.ready" ] && [ -s "$work/background-only.ready" ] && [ -s "$work/zenity.ready" ]' \
	'tray item fixtures'

latest() {
	grep -o "$1 .*" "$work/shell.log" | tail -n 1
}

expected_match='MATCH lark:yes timedoctor:yes title:yes dns:yes prefix:no empty:no none:no'
[ "$(latest MATCH)" = "$expected_match" ] ||
	fail "Unexpected tray name matching: $(latest MATCH)"

# Lark has a window, so its button takes over one of its two tray items
# (whichever registered first); the other stays visible with the tray-only
# app and zenity.
one_lark_hidden() {
	case $(latest VISIBLE) in
	'VISIBLE background-only,lark_status_icon_1,zenity' | \
		'VISIBLE background-only,lark_status_icon_2,zenity') return 0 ;;
	esac
	return 1
}
wait_for one_lark_hidden 'one Lark tray icon hidden while its window is open'

# Closing the windows brings the tray icon back.
run_shell ipc --path "$work/qml/shell.qml" call test closeWindows >/dev/null 2>&1 ||
	fail 'IPC call closeWindows failed'
# shellcheck disable=SC2016 # expanded later by wait_for
wait_for '[ "$(latest VISIBLE)" = "VISIBLE background-only,lark_status_icon_1,lark_status_icon_2,zenity" ]' \
	'Lark tray icons shown after its window closes'

printf 'Quickshell tray hides icons of apps with open windows: PASS\n'
