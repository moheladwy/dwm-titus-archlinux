#!/bin/sh
# Run dwm on two side-by-side monitors and check the per-monitor workspace
# split: the even default, hotkeys.toml [monitors] tags applied on reload,
# workspace keys landing on the owning monitor, and invalid values rejected.
# Xvfb cannot expose two positioned monitors, so this uses Xorg with the dummy
# video driver (xf86-video-dummy) and two RandR outputs; it skips (77) when
# that server is unavailable.

set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)

# The pinned test container sets DWM_TEST_REQUIRE_XORG_DUMMY=1, so a missing tool or
# a failing server is an error there instead of a skip.
skip() {
	printf 'skipping: %s\n' "$1" >&2
	[ "${DWM_TEST_REQUIRE_XORG_DUMMY:-0}" = 1 ] && exit 1
	exit 77
}
for cmd in xrandr xprop xdotool cc pkg-config; do
	command -v "$cmd" >/dev/null 2>&1 || skip "missing required command: $cmd"
done
xorg=/usr/lib/Xorg
dummy_driver=$(find /usr/lib/xorg/modules/drivers /usr/lib64/xorg/modules/drivers \
	-name dummy_drv.so 2>/dev/null | head -n 1)
if [ ! -x "$xorg" ] || [ -z "$dummy_driver" ]; then
	skip 'Xorg with the dummy video driver is not installed'
fi

work=$(mktemp -d)
trap 'set +e; [ -n "${client_pid:-}" ] && kill "$client_pid" 2>/dev/null; [ -n "${dwm_pid:-}" ] && kill "$dwm_pid" 2>/dev/null; [ -n "${xorg_pid:-}" ] && kill "$xorg_pid" 2>/dev/null; rm -rf "$work"' EXIT HUP INT TERM

home="$work/home"
hotkeys="$home/.config/dwm-titus/hotkeys.toml"
mkdir -p "$work/bin" "$home/.config/dwm-titus" "$home/.local/share/dwm-titus/config"
# Keep notifications off the caller's desktop while recording them.
: >"$work/notifications.log"
cat >"$work/bin/notify-send" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${DWM_XVFB_NOTIFICATION_LOG:?}"
EOF
chmod 755 "$work/bin/notify-send"
cp "$repo_dir/config/hotkeys.toml" "$repo_dir/config/themes.toml" \
	"$repo_dir/config/window-rules.toml" "$home/.config/dwm-titus/"
cp "$repo_dir/config/"*.toml "$home/.local/share/dwm-titus/config/"
cp "$hotkeys" "$work/hotkeys.base"

# A plain client that reports its window id and waits.
cat >"$work/client.c" <<'EOF'
#include <stdio.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

int
main(int argc, char *argv[])
{
	Display *dpy = XOpenDisplay(NULL);
	XClassHint hint = { "dwmsplit", "DwmSplitClient" };
	Window win;
	FILE *out;

	if (argc != 2 || !dpy)
		return 1;
	win = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 0, 0, 200, 200, 0, 0, 0);
	XSetClassHint(dpy, win, &hint);
	XMapWindow(dpy, win);
	XSync(dpy, False);
	if (!(out = fopen(argv[1], "w")))
		return 1;
	fprintf(out, "0x%lx\n", win);
	fclose(out);
	for (;;)
		pause();
}
EOF
# shellcheck disable=SC2046
cc "$work/client.c" -o "$work/client" $(pkg-config --cflags --libs x11)

active_window() {
	DISPLAY=$display xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | sed -n 's/.*# //p'
}

window_geometry() {
	DISPLAY=$display xdotool getwindowgeometry --shell "$1" 2>/dev/null | awk -F= '
		$1 == "X" { x = $2 } $1 == "Y" { y = $2 }
		$1 == "WIDTH" { w = $2 } $1 == "HEIGHT" { h = $2 }
		END { print x "," y "," w "," h }'
}

root_value() {
	DISPLAY=$display xprop -root "$1" 2>/dev/null | sed -n 's/^[^=]*= //p' | tr -d '[:space:]'
}

wait_for_value() {
	prop=$1
	expected=$2
	i=0
	while [ "$i" -lt 200 ]; do
		[ "$(root_value "$prop")" = "$expected" ] && return 0
		i=$((i + 1))
		sleep 0.05
	done
	printf '%s did not become %s (last: %s)\n' "$prop" "$expected" "$(root_value "$prop")" >&2
	tail -n 20 "$work/dwm.log" >&2
	return 1
}

# Replace hotkeys.toml in one rename, so dwm never reloads a half-written file.
set_monitor_tags() {
	cp "$work/hotkeys.base" "$hotkeys.next"
	if [ -n "$1" ]; then
		printf '\n[monitors]\ntags = %s\n' "$1" >>"$hotkeys.next"
	fi
	mv "$hotkeys.next" "$hotkeys"
	kill -USR1 "$dwm_pid"
}

# A headless server: no input devices or GPUs are added from the host.
cat >"$work/xorg.conf" <<'EOF'
Section "ServerFlags"
	Option "AutoAddDevices" "false"
	Option "AutoAddGPU" "false"
	Option "AutoBindGPU" "false"
EndSection
Section "Device"
	Identifier "dummy"
	Driver "dummy"
	VideoRam 256000
EndSection
Section "Screen"
	Identifier "screen"
	Device "dummy"
	DefaultDepth 24
	SubSection "Display"
		Depth 24
		Virtual 3840 1080
	EndSubSection
EndSection
EOF
display=":$((($$ % 500) + 650))"
"$xorg" "$display" -config "$work/xorg.conf" -noreset -nolisten tcp \
	-logfile "$work/xorg.log" >"$work/xorg.out" 2>&1 &
xorg_pid=$!
i=0
until DISPLAY=$display xprop -root >/dev/null 2>&1; do
	i=$((i + 1))
	if [ "$i" -ge 200 ] || ! kill -0 "$xorg_pid" 2>/dev/null; then
		tail -n 20 "$work/xorg.log" >&2 2>/dev/null || true
		skip 'Xorg with the dummy driver did not start'
	fi
	sleep 0.05
done
# Two 1920x1080 outputs side by side; dwm reads them through Xinerama.
DISPLAY=$display xrandr --newmode 1920x1080_test 173.00 1920 2048 2248 2576 \
	1080 1083 1088 1120 -hsync +vsync
for output in DUMMY0 DUMMY1; do
	DISPLAY=$display xrandr --addmode "$output" 1920x1080_test
done
DISPLAY=$display xrandr --output DUMMY0 --mode 1920x1080_test --pos 0x0 --primary \
	--output DUMMY1 --mode 1920x1080_test --pos 1920x0

DISPLAY=$display \
	HOME=$home \
	XDG_CONFIG_HOME="$home/.config" \
	XDG_DATA_HOME="$home/.local/share" \
	PATH="$work/bin:$repo_dir:$PATH" \
	DWM_XVFB_NOTIFICATION_LOG="$work/notifications.log" \
	"$repo_dir/dwm" >"$work/dwm.log" 2>&1 &
dwm_pid=$!

# Default: nine workspaces split evenly, 1-4 and 5-9.
wait_for_value _DWM_MONITOR_TAGS 15,496
wait_for_value _DWM_MONITOR_DESKTOPS 0,0,1920,1080,0,1920,0,1920,1080,4

# A focused window on workspace 5 of the second monitor.
DISPLAY=$display xdotool key Super+5
wait_for_value _DWM_SELECTED_MONITOR 1
DISPLAY=$display "$work/client" "$work/client.id" &
client_pid=$!
i=0
until [ -s "$work/client.id" ] && [ "$(active_window)" = "$(cat "$work/client.id")" ]; do
	i=$((i + 1))
	[ "$i" -lt 200 ] || {
		printf '%s\n' 'the test client never became the active window' >&2
		exit 1
	}
	sleep 0.05
done

# 1-3 on the first monitor, 4-9 on the second, which moves from its old first
# workspace (5) to its new one (4). The window stays on the now-hidden
# workspace 5, so it must lose focus.
set_monitor_tags '[3, 6]'
wait_for_value _DWM_MONITOR_TAGS 7,504
wait_for_value _DWM_MONITOR_DESKTOPS 0,0,1920,1080,0,1920,0,1920,1080,3
i=0
while [ "$(active_window)" = "$(cat "$work/client.id")" ]; do
	i=$((i + 1))
	[ "$i" -lt 100 ] || {
		printf '%s\n' 'a window on a hidden workspace kept focus after the split changed' >&2
		exit 1
	}
	sleep 0.05
done

# Workspace keys land on the monitor that owns the workspace.
DISPLAY=$display xdotool key Super+5
wait_for_value _DWM_SELECTED_MONITOR 1
wait_for_value _DWM_MONITOR_DESKTOPS 0,0,1920,1080,0,1920,0,1920,1080,4
DISPLAY=$display xdotool key Super+3
wait_for_value _DWM_SELECTED_MONITOR 0
wait_for_value _DWM_MONITOR_DESKTOPS 0,0,1920,1080,2,1920,0,1920,1080,4

# A floating window that is fullscreen while the split changes, staying on its
# monitor, must return to its own geometry when it leaves fullscreen.
DISPLAY=$display xdotool key Super+5
client=$(cat "$work/client.id")
i=0
until [ "$(active_window)" = "$client" ]; do
	i=$((i + 1))
	[ "$i" -lt 200 ] || {
		printf '%s\n' 'the test client did not regain focus on workspace 5' >&2
		exit 1
	}
	sleep 0.05
done
tiled=$(window_geometry "$client")
DISPLAY=$display xdotool key Super+space
i=0
until floating=$(window_geometry "$client") && [ "$floating" != "$tiled" ]; do
	i=$((i + 1))
	[ "$i" -lt 200 ] || {
		printf '%s\n' 'the test client did not float' >&2
		exit 1
	}
	sleep 0.05
done
DISPLAY=$display xdotool windowstate --add FULLSCREEN "$client"
i=0
until [ "$(window_geometry "$client")" = 1920,0,1920,1080 ]; do
	i=$((i + 1))
	[ "$i" -lt 200 ] || {
		printf 'the test client did not become fullscreen (%s)\n' "$(window_geometry "$client")" >&2
		exit 1
	}
	sleep 0.05
done
set_monitor_tags '[2, 7]'
wait_for_value _DWM_MONITOR_TAGS 3,508
DISPLAY=$display xdotool windowstate --remove FULLSCREEN "$client"
i=0
until [ "$(window_geometry "$client")" = "$floating" ]; do
	i=$((i + 1))
	[ "$i" -lt 200 ] || {
		printf 'leaving fullscreen restored %s instead of %s\n' \
			"$(window_geometry "$client")" "$floating" >&2
		exit 1
	}
	sleep 0.05
done

# Fullscreen again, then move workspace 5 to the first monitor: leaving
# fullscreen there restores the same geometry shifted onto that monitor.
DISPLAY=$display xdotool windowstate --add FULLSCREEN "$client"
i=0
until [ "$(window_geometry "$client")" = 1920,0,1920,1080 ]; do
	i=$((i + 1))
	[ "$i" -lt 200 ] || {
		printf '%s\n' 'the test client did not become fullscreen again' >&2
		exit 1
	}
	sleep 0.05
done
set_monitor_tags '[5, 4]'
wait_for_value _DWM_MONITOR_TAGS 31,480
DISPLAY=$display xdotool key Super+5
wait_for_value _DWM_SELECTED_MONITOR 0
i=0
until [ "$(window_geometry "$client")" = 0,0,1920,1080 ]; do
	i=$((i + 1))
	[ "$i" -lt 200 ] || {
		printf 'the fullscreen client did not cover the first monitor (%s)\n' \
			"$(window_geometry "$client")" >&2
		exit 1
	}
	sleep 0.05
done
shifted=$(printf '%s\n' "$floating" | awk -F, '{ print $1 - 1920 "," $2 "," $3 "," $4 }')
DISPLAY=$display xdotool windowstate --remove FULLSCREEN "$client"
i=0
until [ "$(window_geometry "$client")" = "$shifted" ]; do
	i=$((i + 1))
	[ "$i" -lt 200 ] || {
		printf 'leaving fullscreen on the new monitor restored %s instead of %s\n' \
			"$(window_geometry "$client")" "$shifted" >&2
		exit 1
	}
	sleep 0.05
done

# The last monitor also owns workspaces the list leaves over.
set_monitor_tags '[2, 2]'
wait_for_value _DWM_MONITOR_TAGS 3,508

# Fewer entries than monitors falls back to the even split, quietly.
set_monitor_tags '[3]'
wait_for_value _DWM_MONITOR_TAGS 15,496
[ ! -s "$work/notifications.log" ] || {
	printf '%s\n' 'a valid [monitors] value emitted a notification' >&2
	cat "$work/notifications.log" >&2
	exit 1
}

# Invalid values keep the even split and report the bad setting.
set_monitor_tags '[3, 6]'
wait_for_value _DWM_MONITOR_TAGS 7,504
for invalid in '[5, 6]' '[0, 9]' '["three", 6]' '[3, true, 6]'; do
	before=$(wc -l <"$work/notifications.log")
	set_monitor_tags "$invalid"
	wait_for_value _DWM_MONITOR_TAGS 15,496
	i=0
	while [ "$(wc -l <"$work/notifications.log")" -le "$before" ]; do
		i=$((i + 1))
		[ "$i" -lt 100 ] || {
			printf 'invalid [monitors] tags %s raised no notification\n' "$invalid" >&2
			exit 1
		}
		sleep 0.05
	done
	grep -Fq 'invalid [monitors] tags' "$work/notifications.log"
	set_monitor_tags '[3, 6]'
	wait_for_value _DWM_MONITOR_TAGS 7,504
done

# Removing the section restores the even split.
set_monitor_tags ''
wait_for_value _DWM_MONITOR_TAGS 15,496

printf '%s\n' 'Configured per-monitor workspace split on two monitors: PASS'
