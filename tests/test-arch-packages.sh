#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT

for command_name in pacman sort comm awk; do
	if ! command -v "$command_name" >/dev/null 2>&1; then
		printf 'Missing required Arch package-check command: %s\n' \
			"$command_name" >&2
		exit 1
	fi
done

# shellcheck source=scripts/dwm-utils.sh
source "$repo/scripts/dwm-utils.sh"
# shellcheck source=scripts/dwm-packages.sh
source "$repo/scripts/dwm-packages.sh"

if [[ $DISTRO_ID != arch || $DISTRO_FAMILY != arch ]]; then
	printf 'Arch package validation requires Arch Linux; detected %s.\n' \
		"$DISTRO_NAME" >&2
	exit 1
fi

official_profiles=(
	required recommended optional full terminal lightdm qml-validation ci-smoke
	source-update theme-optional screenshot-optional
)
mapfile -t packages < <(
	for profile in "${official_profiles[@]}"; do
		dwm_packages arch "$profile"
	done | awk 'NF' | sort -u
)
if ((${#packages[@]} == 0)); then
	printf 'Arch package map returned no packages.\n' >&2
	exit 1
fi

# Every non-AUR entry must resolve from the configured official repositories.
# pacman -Sp reads the sync databases only and changes nothing.
printf '%s\n' "${packages[@]}" >"$work/expected"
if ! pacman -Sp --print-format '%n' -- "${packages[@]}" >"$work/resolved" 2>"$work/errors"; then
	printf 'Unresolvable Arch package-map entries:\n' >&2
	sed 's/^/  /' "$work/errors" >&2
	exit 1
fi
mapfile -t repo_packages < <(pacman -Sl | awk '{ print $2 }' | sort -u)
printf '%s\n' "${repo_packages[@]}" >"$work/available"
comm -23 "$work/expected" "$work/available" >"$work/missing"
if [[ -s $work/missing ]]; then
	printf 'Arch package-map entries are not real repository packages:\n' >&2
	sed 's/^/  /' "$work/missing" >&2
	exit 1
fi

# AUR-only packages must stay out of every official profile, and the AUR
# profile must not duplicate official packages.
mapfile -t aur_packages < <(dwm_packages arch aur-optional)
((${#aur_packages[@]} > 0))
for package in "${aur_packages[@]}"; do
	if grep -Fxq "$package" "$work/expected"; then
		printf 'AUR package %s appears in an official profile.\n' "$package" >&2
		exit 1
	fi
	if grep -Fxq "$package" "$work/available"; then
		printf 'aur-optional lists %s, which is an official repository package.\n' \
			"$package" >&2
		exit 1
	fi
done

# Gaming, Path, Thunar, PackageKit, and Fedora-only names were removed.
for removed in steam gamescope gamemode lib32-gamemode mangohud lib32-mangohud \
	path thunar thunar-archive-plugin tumbler file-roller packagekit \
	libpackagekit-glib dnfdragora gnome-keyring-pam xkbset; do
	if grep -Fxq "$removed" "$work/expected"; then
		printf 'Removed package %s is still in an official profile.\n' "$removed" >&2
		exit 1
	fi
done
if dwm_packages arch gaming >/dev/null 2>&1; then
	printf 'The gaming profile still exists.\n' >&2
	exit 1
fi
for package in dolphin ark archlinux-xdg-menu; do
	dwm_packages arch desktop-optional | grep -Fx "$package" >/dev/null
	dwm_packages arch full | grep -Fx "$package" >/dev/null
done
for package in pyalpm pacman-contrib python-gobject accountsservice cups system-config-printer; do
	dwm_packages arch system-management | grep -Fx "$package" >/dev/null
	dwm_packages arch recommended | grep -Fx "$package" >/dev/null
done
dwm_packages arch system-management-optional | grep -Fx lxqt-admin >/dev/null
for package in xsettingsd bubblewrap libseccomp networkmanager; do
	dwm_packages arch source-update | grep -Fx "$package" >/dev/null
done
for profile in runtime-required required full source-update; do
	dwm_packages arch "$profile" | grep -Fx gnome-keyring >/dev/null
done
grep -Fq 'dwm_install_package_profile system-management' "$repo/install.sh"
grep -Fq 'check_cmd "xsettingsd"' "$repo/scripts/check-deps.sh"
grep -Fq 'check_optional_cmd "xkbset"' "$repo/scripts/check-deps.sh"
if "$repo/scripts/dwm-packages.sh" arch unsupported >"$work/unsupported"; then
	printf 'Unsupported package-map profile unexpectedly passed.\n' >&2
	exit 1
fi
[[ ! -s $work/unsupported ]]

# Installed providers must not be replaced by conflicting defaults:
# tuned-ppd provides power-profiles-daemon, and pulseaudio conflicts with
# pipewire-pulse.
mkdir -p "$work/bin"
cat >"$work/bin/pacman" <<'EOF'
#!/bin/sh
case "$*" in
'-T power-profiles-daemon') [ "${DWM_TEST_PPD_PROVIDER:-0}" = 1 ] ;;
'-Q pulseaudio') [ "${DWM_TEST_PULSEAUDIO:-0}" = 1 ] ;;
*) exit 2 ;;
esac
EOF
chmod +x "$work/bin/pacman"
desktop_install() {
	PATH="$work/bin:$PATH" bash -c '
		. "$1"
		DISTRO_FAMILY=arch
		install_packages() { printf "%s\n" "$@"; }
		dwm_install_package_profile desktop
	' _ "$repo/scripts/dwm-packages.sh" 2>/dev/null
}
with_providers=$(DWM_TEST_PPD_PROVIDER=1 DWM_TEST_PULSEAUDIO=1 desktop_install)
for package in power-profiles-daemon pipewire-pulse; do
	if printf '%s\n' "$with_providers" | grep -Fxq "$package"; then
		printf 'Installed provider would be replaced by %s.\n' "$package" >&2
		exit 1
	fi
done
for package in upower dbus inotify-tools xsettingsd bluez-utils libpulse; do
	printf '%s\n' "$with_providers" | grep -Fxq "$package"
done
without_providers=$(DWM_TEST_PPD_PROVIDER=0 DWM_TEST_PULSEAUDIO=0 desktop_install)
printf '%s\n' "$without_providers" | grep -Fxq power-profiles-daemon
printf '%s\n' "$without_providers" | grep -Fxq pipewire-pulse

# Each optional install must read its pacman confirmation from the caller's
# terminal, never from the package list being iterated.
optional_install() {
	printf 'y\ny\ny\n' | bash -c '
		. "$1"
		DISTRO_FAMILY=arch
		install_optional_package() {
			local answer=""
			IFS= read -r answer || true
			printf "%s:%s\n" "$1" "$answer"
		}
		dwm_install_available_package_profile theme-gtk
	' _ "$repo/scripts/dwm-packages.sh"
}
expected_answers=$(dwm_packages arch theme-gtk | sed 's/$/:y/')
if [[ $(optional_install) != "$expected_answers" ]]; then
	printf 'Optional package installs did not read confirmation from the terminal.\n' >&2
	exit 1
fi

"$repo/install.sh" --dry-run --non-interactive --profile core >/dev/null

printf 'Arch package map: PASS (%s official packages, %s AUR-optional)\n' \
	"${#packages[@]}" "${#aur_packages[@]}"
