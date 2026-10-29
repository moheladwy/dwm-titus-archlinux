#!/bin/sh
set -eu

repo=$(
	unset CDPATH
	cd -- "$(dirname -- "$0")/.." && pwd
)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin"
cat >"$work/bin/brightnessctl" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >"$DWM_TEST_BRIGHTNESS_LOG"
SH
chmod +x "$work/bin/brightnessctl"

# connector DIR STATE: an internal panel connector with its enabled state.
connector() {
	mkdir -p "$1"
	printf '%s\n' "$2" >"$1/enabled"
}

# backlight ROOT NAME TYPE DIR DEVICE: a backlight in DIR whose device link
# points at DEVICE, published in ROOT/class/backlight like sysfs.
backlight() {
	mkdir -p "$4/$2" "$1/class/backlight"
	printf '%s\n' "$3" >"$4/$2/type"
	ln -s "$5" "$4/$2/device"
	ln -s "$4/$2" "$1/class/backlight/$2"
}

run() {
	DWM_BACKLIGHT_SYSFS="$1/class/backlight" DWM_TEST_BRIGHTNESS_LOG="$work/args" \
		PATH="$work/bin:$PATH" "$repo/scripts/dwm-brightness" "$2"
}

expect() {
	run "$1" "$2"
	if [ "$(cat "$work/args")" != "$3" ]; then
		printf '%s: expected "%s", got "%s"\n' "$4" "$3" "$(cat "$work/args")" >&2
		exit 1
	fi
}

# Hybrid laptop: the panel is on the integrated GPU (amdgpu backlight under its
# enabled eDP connector) while the NVIDIA backlight's eDP connector is off.
hybrid() {
	root=$work/$1
	connector "$root/devices/amd/drm/card2/card2-eDP-2" "$2"
	backlight "$root" amdgpu_bl2 raw "$root/devices/amd/drm/card2/card2-eDP-2" \
		"$root/devices/amd/drm/card2/card2-eDP-2"
	connector "$root/devices/nv/drm/card1/card1-eDP-1" "$3"
	mkdir -p "$root/devices/nv/backlight"
	backlight "$root" nvidia_0 raw "$root/devices/nv/backlight" "$root/devices/nv"
}
hybrid hybrid enabled disabled
expect "$work/hybrid" '10%+' '--quiet --device=amdgpu_bl2 set 10%+' 'hybrid integrated panel'
# The same laptop with the dedicated GPU driving the panel.
hybrid dgpu disabled enabled
expect "$work/dgpu" '10%-' '--quiet --device=nvidia_0 set 10%-' 'dedicated GPU panel'

# An enabled panel's native backlight beats a firmware backlight that does
# not drive any connector.
root=$work/intel
connector "$root/devices/igpu/drm/card0/card0-eDP-1" enabled
backlight "$root" intel_backlight raw "$root/devices/igpu/drm/card0/card0-eDP-1" \
	"$root/devices/igpu/drm/card0/card0-eDP-1"
mkdir -p "$root/devices/acpi/video"
backlight "$root" acpi_video0 firmware "$root/devices/acpi/video" "$root/devices/acpi"
expect "$root" '50%' '--quiet --device=intel_backlight set 50%' 'native panel over firmware'

# Without a backlight on an enabled panel, brightnessctl picks the device.
root=$work/unknown
mkdir -p "$root/devices/acpi/video"
backlight "$root" acpi_video0 firmware "$root/devices/acpi/video" "$root/devices/acpi"
expect "$root" '+10%' '--quiet set +10%' 'no enabled panel'
mkdir -p "$work/empty/class/backlight"
expect "$work/empty" '10%+' '--quiet set 10%+' 'no backlight'

for value in '' '-10%' '%10' '10%%' '10;reboot' '10 20'; do
	if run "$work/hybrid" "$value" 2>/dev/null; then
		printf 'accepted invalid brightness value: %s\n' "$value" >&2
		exit 1
	fi
done
if DWM_BACKLIGHT_SYSFS="$work/hybrid/class/backlight" "$repo/scripts/dwm-brightness" 2>/dev/null; then
	printf 'accepted a missing brightness value\n' >&2
	exit 1
fi

grep -Fq 'cmd="dwm-brightness 10%+"' "$repo/config/hotkeys.toml"
grep -Fq 'cmd="dwm-brightness 10%-"' "$repo/config/hotkeys.toml"
printf 'Brightness follows the active panel: PASS\n'
