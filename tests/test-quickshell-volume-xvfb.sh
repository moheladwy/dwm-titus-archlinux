#!/bin/sh
set -eu
repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ "${DWM_VOLUME_UI_SESSION:-0}" != 1 ]; then
	exec env DWM_VOLUME_UI_SESSION=1 dbus-run-session -- "$0"
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
mkdir -p "$work/qml" "$work/home" "$work/config/wireplumber/wireplumber.conf.d" \
	"$work/state" "$work/runtime" "$work/data" "$work/cache"
chmod 700 "$work/runtime"
# Keep the audio daemons off the developer's configuration, saved state and
# sound hardware: private XDG paths, no device monitors, no state persistence.
export HOME="$work/home" XDG_CONFIG_HOME="$work/config" XDG_STATE_HOME="$work/state" \
	XDG_DATA_HOME="$work/data" XDG_CACHE_HOME="$work/cache" XDG_RUNTIME_DIR="$work/runtime"
cat >"$work/config/wireplumber/wireplumber.conf.d/90-dwm-titus-test.conf" <<'CONF'
wireplumber.profiles = {
  main = {
    hardware.audio = disabled
    hardware.bluetooth = disabled
    hardware.video-capture = disabled
    hooks.device.profile.state = disabled
    hooks.device.routes.state = disabled
    hooks.default-nodes.state = disabled
    hooks.stream.state = disabled
  }
}
CONF
cp -a "$repo/config/quickshell/core" "$repo/config/quickshell/controls" "$work/qml/"
cp "$repo/tests/qml/ControlsVolumeUi.qml" "$work/qml/shell.qml"

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

# A private PipeWire graph with one virtual sink boosted above 100%.
pipewire >"$work/pipewire.log" 2>&1 &
pids="$pids $!"
wait_for 'pw-cli info 0 >/dev/null 2>&1' 'PipeWire'
wireplumber >"$work/wireplumber.log" 2>&1 &
pids="$pids $!"
pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=dwm-test-sink media.class=Audio/Sink object.linger=true audio.position=[FL FR] }' >/dev/null
# Default-sink requests made before WirePlumber publishes its "default"
# metadata are lost, so wait for it before choosing the sink.
# shellcheck disable=SC2016 # jq program, not a shell expansion
wait_for 'pw-dump 2>/dev/null | jq -e '\''any(.[]; .type == "PipeWire:Interface:Metadata" and .props["metadata.name"]? == "default")'\'' >/dev/null' \
	'WirePlumber default metadata'
sink_id() {
	pw-dump 2>/dev/null |
		jq -r 'first(.[] | select(.info.props["node.name"]? == "dwm-test-sink") | .id) // empty'
}
# shellcheck disable=SC2016 # expanded later by wait_for
wait_for '[ -n "$(sink_id)" ]' 'virtual sink'
sink=$(sink_id)
wpctl set-volume "$sink" 1.15
# The shell reads the default sink; repeat set-default until it resolves.
# shellcheck disable=SC2016 # expanded later by wait_for
wait_for 'wpctl set-default "$sink" 2>/dev/null
	wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -Fqx "Volume: 1.15"' \
	'boosted default sink'

Xvfb -displayfd 3 -screen 0 640x480x24 -nolisten tcp -extension GLX \
	3>"$work/display" >"$work/xvfb.log" 2>&1 &
pids="$pids $!"
# shellcheck disable=SC2016 # expanded later by wait_for
wait_for '[ -s "$work/display" ]' 'Xvfb display'
display=$(sed -n '1p' "$work/display")

status=0
timeout --kill-after=2s 30s env DISPLAY=":$display" \
	QT_QPA_PLATFORM=xcb QT_QPA_PLATFORMTHEME= quickshell --no-duplicate --path "$work/qml/shell.qml" \
	>"$work/ui.log" 2>&1 || status=$?
if [ "$status" -ne 0 ] || ! grep -Fq 'Controls volume UI: PASS' "$work/ui.log" ||
	grep -Fq 'Controls volume UI FAILED:' "$work/ui.log"; then
	cat "$work/ui.log" >&2
	exit 1
fi
printf 'Controls volume above 100%%: PASS\n'
