#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
# pacman -T succeeds when a package or a package that provides it is installed.
cat >"$work/bin/pacman" <<'PACMAN'
#!/bin/sh
[ "$1" = -T ] || exit 2
case ":${DWM_TEST_CAPABILITIES:-}:" in *":$2:"*) exit 0 ;; *) exit 127 ;; esac
PACMAN
chmod +x "$work/bin/pacman"
profile() {
	# shellcheck disable=SC2016 # Expand arguments inside the isolated Bash process.
	env PATH="$work/bin" DWM_TEST_CAPABILITIES="${1:-}" /usr/bin/bash -c '
        set -eu
        . "$1/scripts/dwm-packages.sh"
        DISTRO_FAMILY=arch
        install_packages() { printf "%s\n" "$@"; }
        dwm_install_package_profile "$2"
    ' sh "$repo" "$2" 2>/dev/null
}
# tuned-ppd provides power-profiles-daemon.
profile power-profiles-daemon desktop >"$work/power"
if grep -Fxq power-profiles-daemon "$work/power"; then
	printf 'Existing provider would be replaced\n' >&2
	exit 1
fi
grep -Fxq upower "$work/power"
profile pulseaudio desktop >"$work/audio"
if grep -Fxq pipewire-pulse "$work/audio"; then
	printf 'Installed PulseAudio server would be replaced\n' >&2
	exit 1
fi
profile xorg-server required >"$work/server"
if grep -Fxq xorg-server "$work/server"; then
	printf 'Existing provider would be replaced\n' >&2
	exit 1
fi
printf '#!/bin/sh\nexit 0\n' >"$work/bin/Xlibre"
chmod +x "$work/bin/Xlibre"
profile '' required >"$work/command"
if grep -Fxq xorg-server "$work/command"; then
	printf 'Existing provider would be replaced\n' >&2
	exit 1
fi
rm "$work/bin/Xlibre" "$work/bin/pacman"
# Without pacman or alternative commands, do not silently omit required packages.
profile '' required >"$work/no-provider"
grep -Fxq xorg-server "$work/no-provider"
profile '' desktop >"$work/no-power"
grep -Fxq power-profiles-daemon "$work/no-power"
grep -Fxq pipewire-pulse "$work/no-power"
printf 'Shared package provider retention: PASS\n'
