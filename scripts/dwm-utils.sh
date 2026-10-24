#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# dwm-utils.sh — Shared utility library for dwm-titus
# Source this file from other scripts:
#   source "$(dirname "$0")/dwm-utils.sh"
# ─────────────────────────────────────────────────────────

# ── Distribution and package manager ────────────────────
DISTRO_ID="unknown"
DISTRO_NAME="Unknown Linux"
DISTRO_FAMILY="unknown"
DWM_PACKAGE_COMMAND=()
OS_RELEASE_FILE="/etc/os-release"
if [[ ${DWM_TEST_MODE:-0} == 1 && -n ${DWM_OS_RELEASE:-} ]]; then
	OS_RELEASE_FILE=$DWM_OS_RELEASE
fi

if [[ -r $OS_RELEASE_FILE ]]; then
	# shellcheck disable=SC1090
	source "$OS_RELEASE_FILE"
	DISTRO_ID="${ID:-unknown}"
	DISTRO_NAME="${PRETTY_NAME:-${NAME:-Unknown Linux}}"
fi

# Plain Arch Linux is the only supported identity. ID_LIKE is deliberately
# ignored: derivatives such as EndeavourOS, CachyOS, and Manjaro are rejected.
dwm_platform_family() {
	case "$1" in
	arch) printf '%s\n' arch ;;
	*) printf '%s\n' unknown ;;
	esac
}

DISTRO_FAMILY=$(dwm_platform_family "$DISTRO_ID")

# Set DWM_PACKAGE_NONINTERACTIVE=1 to pass --noconfirm. Interactive runs keep
# pacman's own confirmation, conflict, and provider prompts.
DWM_PACKAGE_NONINTERACTIVE=${DWM_PACKAGE_NONINTERACTIVE:-0}

case "$DISTRO_FAMILY" in
arch)
	if ((EUID == 0)); then
		DWM_PACKAGE_COMMAND=(pacman -S --needed)
	else
		DWM_PACKAGE_COMMAND=(sudo pacman -S --needed)
	fi
	PKG_CMD="${DWM_PACKAGE_COMMAND[*]}"
	;;
*)
	PKG_CMD="unavailable"
	;;
esac
export PKG_CMD

dwm_pacman_confirm_args() {
	if [[ $DWM_PACKAGE_NONINTERACTIVE == 1 ]]; then
		printf '%s\n' --noconfirm
	fi
}

install_packages() {
	local confirm_args=()

	case "$DISTRO_FAMILY" in
	arch)
		mapfile -t confirm_args < <(dwm_pacman_confirm_args)
		"${DWM_PACKAGE_COMMAND[@]}" "${confirm_args[@]}" -- "$@"
		;;
	*)
		printf 'Unsupported distribution: %s (Arch Linux is required)\n' "$DISTRO_NAME" >&2
		return 1
		;;
	esac
}

# Synchronize and upgrade the whole system. Arch does not support partial
# upgrades, so package installation must never follow a bare `pacman -Sy`.
dwm_system_upgrade() {
	local confirm_args=()
	local prefix=()

	[[ $DISTRO_FAMILY == arch ]] || return 1
	((EUID == 0)) || prefix=(sudo)
	mapfile -t confirm_args < <(dwm_pacman_confirm_args)
	"${prefix[@]}" pacman -Syu "${confirm_args[@]}"
}

package_available() {
	case "$DISTRO_FAMILY" in
	arch)
		pacman -Si -- "$1" >/dev/null 2>&1
		;;
	*)
		return 1
		;;
	esac
}

# Satisfied when the package or a provider of it is installed.
package_installed() {
	[[ $DISTRO_FAMILY == arch ]] || return 1
	pacman -T -- "$1" >/dev/null 2>&1
}

# AUR packages are opt-in and only use an AUR helper that is already
# installed. The helper runs as the invoking user, never as root, and is never
# used for official repository packages.
dwm_aur_helper() {
	local helper

	for helper in paru yay; do
		if command -v "$helper" >/dev/null 2>&1; then
			printf '%s\n' "$helper"
			return 0
		fi
	done
	return 1
}

install_aur_packages() {
	local helper
	local confirm_args=()

	if ((EUID == 0)); then
		printf 'Refusing to run an AUR helper as root.\n' >&2
		return 1
	fi
	helper=$(dwm_aur_helper) || {
		printf 'No AUR helper (paru or yay) is installed; skipping AUR packages: %s\n' "$*" >&2
		return 1
	}
	mapfile -t confirm_args < <(dwm_pacman_confirm_args)
	"$helper" -S --needed "${confirm_args[@]}" -- "$@"
}

install_optional_package() {
	local package=$1

	if package_available "$package"; then
		install_packages "$package"
		return
	fi

	printf 'Optional package is unavailable in enabled repositories: %s\n' "$package" >&2
	return 1
}

# ── Hardware Detection ──────────────────────────────────

# Detect GPU type: nvidia, amd, intel, or unknown
detect_gpu() {
	if command -v lspci &>/dev/null; then
		local vga
		vga=$(lspci 2>/dev/null | command grep -i 'vga\|3d\|display' || true)
		if echo "$vga" | command grep -qi nvidia; then
			echo "nvidia"
		elif echo "$vga" | command grep -qi 'amd\|radeon'; then
			echo "amd"
		elif echo "$vga" | command grep -qi intel; then
			echo "intel"
		else
			echo "unknown"
		fi
	else
		echo "unknown"
	fi
}

# Detect battery device name (e.g., BAT0, BAT1)
detect_battery() {
	command ls /sys/class/power_supply/ 2>/dev/null | command grep -E '^BAT[0-9]' | head -1
}

# Detect AC adapter name (e.g., ACAD, AC0, ADP1)
detect_adapter() {
	command ls /sys/class/power_supply/ 2>/dev/null | command grep -Ev '^BAT' | head -1
}

# Detect if running on a laptop (has battery)
is_laptop() {
	[ -n "$(detect_battery)" ]
}

# Detect first available terminal emulator
detect_terminal() {
	for t in dwmterm alacritty kitty st warp-terminal xterm; do
		if command -v "$t" &>/dev/null; then
			echo "$t"
			return
		fi
	done
	echo "xterm"
}
