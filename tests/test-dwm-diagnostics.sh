#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT_DIR/scripts/dwm-diagnostics"
BASH_BIN="${BASH:-/usr/bin/bash}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/home/.config"
ln -s "$(command -v dirname)" "$work/bin/dirname"

for cmd in cc make Xorg startx xrandr xset xsetroot xclip xdotool alacritty; do
	cat >"$work/bin/$cmd" <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
	chmod +x "$work/bin/$cmd"
done

cat >"$work/bin/pkg-config" <<'SCRIPT'
#!/bin/sh
test "$1" = "--exists"
case "$2" in
	x11|xft|xinerama|xrender|imlib2|x11-xcb|xcb|xcb-res)
		exit 0
		;;
esac
exit 1
SCRIPT
chmod +x "$work/bin/pkg-config"

# pacman -T prints unsatisfied dependencies and exits 127 when any is missing.
cat >"$work/bin/pacman" <<'SCRIPT'
#!/bin/sh
[ "$1" = -T ] || exit 2
shift
[ "$1" != -- ] || shift
if [ "$1" = "${DWM_TEST_MISSING_PACKAGE:-}" ]; then
	printf '%s\n' "$1"
	exit 127
fi
exit 0
SCRIPT
chmod +x "$work/bin/pacman"
mkdir -p "$work/security"
: >"$work/security/pam_gnome_keyring.so"
export DWM_PAM_SECURITY_DIR="$work/security"
printf '%s\n' 'ID=arch' 'NAME="Arch Linux"' 'PRETTY_NAME="Arch Linux"' >"$work/os-release"

env HOME="$work/home" PATH="$work/bin" "$BASH_BIN" "$HELPER" >"$work/ok"
grep -Fqx "  required_failures=0" "$work/ok"
grep -Fq "Optional desktop" "$work/ok"
grep -Fq "degraded quickshell" "$work/ok"
grep -Fq "degraded maim" "$work/ok"

# A running daemon does not prove that the PAM module is present.
for cmd in tr cut; do
	ln -s "$(command -v "$cmd")" "$work/bin/$cmd"
done
if env HOME="$work/home" PATH="$work/bin" DWM_TEST_MISSING_PACKAGE=gnome-keyring \
	"$BASH_BIN" "$HELPER" --format health-tsv >"$work/keyring-fail"; then
	echo "diagnostics passed despite missing gnome-keyring" >&2
	exit 1
fi
grep -Fq $'error\tdependency-package-gnome-keyring' "$work/keyring-fail"
grep -Fq $'install-dependencies\tOpen dependency installer' "$work/keyring-fail"
mv "$work/security/pam_gnome_keyring.so" "$work/pam.hidden"
if env HOME="$work/home" PATH="$work/bin" \
	"$BASH_BIN" "$HELPER" --format health-tsv >"$work/keyring-fail"; then
	echo "diagnostics passed despite a missing PAM module" >&2
	exit 1
fi
grep -Fq $'error\tdependency-pam-gnome-keyring' "$work/keyring-fail"
mv "$work/pam.hidden" "$work/security/pam_gnome_keyring.so"
env HOME="$work/home" PATH="$work/bin" "$BASH_BIN" "$HELPER" --format health-tsv >"$work/keyring-ok"
grep -Fq $'ok\tdependency-package-gnome-keyring' "$work/keyring-ok"
grep -Fq $'ok\tdependency-pam-gnome-keyring' "$work/keyring-ok"

# The command-line dependency checker must detect the same missing PAM package.
for cmd in grep paste; do
	ln -s "$(command -v "$cmd")" "$work/bin/$cmd"
done
for cmd in quickshell picom feh xsettingsd bwrap dex amixer jq bluetoothctl blueman-applet xdg-open; do
	cp "$work/bin/cc" "$work/bin/$cmd"
done
cat >"$work/bin/fc-list" <<'SCRIPT'
#!/bin/sh
printf '%s\n' 'MesloLGS Nerd Font' 'Noto Color Emoji'
SCRIPT
chmod +x "$work/bin/fc-list"
check_env=(env HOME="$work/home" PATH="$work/bin" DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/os-release")
# xkbset is AUR-only on Arch and must not be required.
"${check_env[@]}" "$BASH_BIN" "$ROOT_DIR/scripts/check-deps.sh" >"$work/check-ok"
grep -Fq 'xkbset' "$work/check-ok"
grep -Fq 'optional, missing' "$work/check-ok"
mv "$work/security/pam_gnome_keyring.so" "$work/pam.hidden"
if "${check_env[@]}" "$BASH_BIN" "$ROOT_DIR/scripts/check-deps.sh" >"$work/check-fail"; then
	echo 'dependency checker passed despite missing keyring PAM' >&2
	exit 1
fi
mv "$work/pam.hidden" "$work/security/pam_gnome_keyring.so"
grep -Fq 'missing pam_gnome_keyring.so' "$work/check-fail"
grep -Fq '1 missing dependency/dependencies.' "$work/check-fail"
if "${check_env[@]}" DWM_TEST_MISSING_PACKAGE=gnome-keyring \
	"$BASH_BIN" "$ROOT_DIR/scripts/check-deps.sh" >"$work/check-fail"; then
	echo 'dependency checker passed despite missing gnome-keyring' >&2
	exit 1
fi
grep -Fq 'missing gnome-keyring' "$work/check-fail"

rm -f "$work/bin/alacritty" "$work/bin/Xorg"

if env HOME="$work/home" PATH="$work/bin" "$BASH_BIN" "$HELPER" >"$work/fail" 2>"$work/err"; then
	echo "diagnostics passed despite missing required commands" >&2
	exit 1
fi

grep -Fq "missing X11 server" "$work/fail"
grep -Fq "missing terminal" "$work/fail"
grep -Fq "Required failures must be fixed" "$work/err"
