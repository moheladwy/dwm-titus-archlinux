#!/bin/sh
set -eu
repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
xvfb_pid=
cleanup() {
	if [ -n "$xvfb_pid" ]; then
		kill "$xvfb_pid" 2>/dev/null || true
		wait "$xvfb_pid" 2>/dev/null || true
	fi
	rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
mkdir -p "$work/qml" "$work/home" "$work/state" "$work/runtime" \
	"$work/data/dwm-titus/scripts"
chmod 700 "$work/runtime"
cp -a "$repo/config/quickshell/core" "$repo/config/quickshell/controlcenter" "$work/qml/"
cp "$repo/tests/qml/ControlCenterThemeUi.qml" "$work/qml/shell.qml"
# The model prefers the managed helper copy, so the stub takes its place.
cat >"$work/data/dwm-titus/scripts/dwm-quickshell-controlcenter" <<'SH'
#!/bin/sh
case $1:${2:-} in
themes:) printf 'active\tnord\navailable\tdracula\navailable\tbroken\n' ;;
theme-set:dracula)
	printf 'theme-apply: applied theme dracula\n' >&2
	printf 'theme\tdracula\n'
	;;
theme-set:broken)
	printf 'theme-apply: staged theme broken\n' >&2
	printf 'dwm-settings-theme: unsafe theme integration file: /fixture/kitty/active-theme.conf\n' >&2
	exit 1
	;;
# A result record followed by a failing exit must not count as success.
theme-set:liar)
	printf 'theme\tliar\n'
	exit 1
	;;
*) exit 2 ;;
esac
SH
chmod 755 "$work/data/dwm-titus/scripts/dwm-quickshell-controlcenter"
Xvfb -displayfd 3 -screen 0 1024x768x24 -nolisten tcp -extension GLX \
	3>"$work/display" >"$work/xvfb.log" 2>&1 &
xvfb_pid=$!
attempt=0
while [ ! -s "$work/display" ] && [ "$attempt" -lt 100 ]; do
	attempt=$((attempt + 1))
	sleep 0.05
done
display=$(sed -n '1p' "$work/display")
case $display in
'' | *[!0-9]*)
	cat "$work/xvfb.log" >&2
	exit 1
	;;
esac
status=0
timeout --kill-after=2s 20s env DISPLAY=":$display" HOME="$work/home" \
	XDG_DATA_HOME="$work/data" XDG_STATE_HOME="$work/state" XDG_RUNTIME_DIR="$work/runtime" \
	QT_QPA_PLATFORM=xcb QT_QPA_PLATFORMTHEME= quickshell --no-duplicate --path "$work/qml/shell.qml" \
	>"$work/ui.log" 2>&1 || status=$?
if [ "$status" -ne 0 ] || ! grep -Fq 'Control Center theme UI: PASS' "$work/ui.log" ||
	grep -Fq 'Control Center theme UI FAILED:' "$work/ui.log"; then
	cat "$work/ui.log" >&2
	exit 1
fi
printf 'Control Center theme UI: PASS\n'
