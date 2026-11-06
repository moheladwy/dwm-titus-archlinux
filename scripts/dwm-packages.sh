#!/usr/bin/env bash
# Shared package capability map for dwm-titus installers and diagnostics.

dwm_packages() {
	local family=$1
	local profile=$2

	case "$family:$profile" in
	# Arch Linux is the supported platform. Every package below is in the
	# official core/extra repositories; AUR-only packages live only in
	# aur-optional and are never required.
	arch:provider-policy)
		# package, provided capability (pacman -T), alternative commands.
		# tuned-ppd provides power-profiles-daemon and conflicts with it;
		# pipewire-pulse conflicts with an installed pulseaudio server, which is
		# kept because replacing an audio server is a user decision.
		printf '%s\n' $'power-profiles-daemon\tpower-profiles-daemon\t-' \
			$'pipewire-pulse\tpulseaudio\t-' \
			$'xorg-server\txorg-server\tXorg,Xlibre'
		;;
	arch:build)
		printf '%s\n' \
			gcc make pkgconf libx11 libxft libxinerama libxrender imlib2 libxcb \
			xcb-util freetype2 fontconfig
		;;
	arch:ci-smoke)
		dwm_packages "$family" build
		printf '%s\n' quickshell python dbus util-linux procps-ng \
			xorg-server-xvfb xdotool xorg-xprop xorg-xrandr xorg-xset xsettingsd \
			jq inotify-tools gawk noto-fonts xorg-setxkbmap xorg-xkbcomp xorg-xmodmap xorg-xinput
		;;
	arch:media)
		printf '%s\n' celluloid mpv sxiv python desktop-file-utils
		;;
	arch:x11)
		# xkbset is AUR-only; it is listed in aur-optional and dwm-settings-input
		# reports AccessX controls as unavailable without it.
		printf '%s\n' xorg-server xorg-xinit xorg-xrandr xorg-xset xorg-xsetroot xorg-xinput xorg-setxkbmap
		;;
	arch:runtime-required)
		printf '%s\n' dbus curl git procps-ng psmisc unzip util-linux xclip xdotool xorg-xprop xdg-utils
		dwm_packages "$family" keyring
		;;
	arch:keyring)
		# Arch ships pam_gnome_keyring.so in gnome-keyring itself.
		printf '%s\n' gnome-keyring
		;;
	arch:desktop)
		printf '%s\n' \
			quickshell picom python feh dex mate-polkit xsettingsd bubblewrap libseccomp \
			alsa-utils brightnessctl dbus inotify-tools jq libpulse pipewire pavucontrol \
			pipewire-pulse wireplumber libnotify light-locker xf86-input-libinput \
			bluez bluez-utils blueman playerctl upower power-profiles-daemon flatpak \
			xdg-desktop-portal-gtk nm-connection-editor
		;;
	arch:system-management)
		# pyalpm and pacman-contrib back the native pacman update provider.
		printf '%s\n' \
			pyalpm pacman-contrib python-gobject accountsservice cups \
			system-config-printer
		;;
	arch:system-management-optional)
		printf '%s\n' lxqt-admin
		;;
	arch:source-update)
		# Dependencies introduced after the initial installation that the supported
		# source-checkout synchronization path must reconcile for existing systems.
		printf '%s\n' xsettingsd bubblewrap libseccomp networkmanager
		dwm_packages "$family" keyring
		;;
	arch:desktop-optional)
		# Dolphin is the managed file manager. archlinux-xdg-menu provides the
		# applications.menu that KService needs for "Open With" outside Plasma.
		printf '%s\n' \
			dolphin ark ffmpegthumbs kdegraphics-thumbnailers kio-admin \
			archlinux-xdg-menu gvfs xdg-user-dirs networkmanager rsync
		;;
	arch:theme)
		printf '%s\n' dconf adwaita-icon-theme papirus-icon-theme
		;;
	arch:theme-gtk)
		printf '%s\n' adw-gtk-theme deepin-gtk-theme
		;;
	arch:aur-optional)
		# Installed only with --enable-aur through an existing paru or yay.
		printf '%s\n' xkbset arc-gtk-theme numix-gtk-theme yaru-gtk-theme xfce-theme-bluebird
		;;
	arch:theme-optional)
		printf '%s\n' qt6ct qt5ct
		;;
	arch:fonts)
		printf '%s\n' noto-fonts-emoji noto-fonts ttf-meslo-nerd
		;;
	arch:qml-development)
		printf '%s\n' qt6-declarative
		;;
	arch:qml-validation)
		printf '%s\n' quickshell xsettingsd
		dwm_packages "$family" qml-development
		;;
	arch:lightdm)
		printf '%s\n' lightdm lightdm-slick-greeter
		;;
	arch:terminal)
		printf '%s\n' alacritty kitty
		;;
	arch:terminal-primary)
		printf '%s\n' alacritty
		;;
	arch:screenshot-optional)
		printf '%s\n' maim
		;;
	arch:required)
		dwm_packages "$family" build
		dwm_packages "$family" x11
		dwm_packages "$family" runtime-required
		dwm_packages "$family" media
		;;
	arch:recommended)
		dwm_packages "$family" desktop
		dwm_packages "$family" system-management
		dwm_packages "$family" screenshot-optional
		dwm_packages "$family" theme
		dwm_packages "$family" theme-gtk
		dwm_packages "$family" fonts
		;;
	arch:optional)
		dwm_packages "$family" theme-optional
		dwm_packages "$family" desktop-optional
		dwm_packages "$family" system-management-optional
		;;
	arch:full)
		dwm_packages "$family" required
		dwm_packages "$family" recommended
		dwm_packages "$family" optional
		;;
	*)
		return 1
		;;
	esac
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	[[ $# == 2 ]] || {
		printf 'usage: %s FAMILY PROFILE\n' "$0" >&2
		exit 2
	}
	dwm_packages "$1" "$2"
	exit $?
fi

dwm_install_package_profile() {
	local profile=$1
	local packages=()
	local package

	while IFS= read -r package; do
		[[ -n $package ]] || continue
		if dwm_package_provider_installed "$package"; then
			printf '%s\n' \
				"Retaining installed provider; skipping $package." >&2
			continue
		fi
		packages+=("$package")
	done < <(dwm_packages "$DISTRO_FAMILY" "$profile")

	if ((${#packages[@]} == 0)); then
		return 0
	fi

	install_packages "${packages[@]}"
}

dwm_package_provider_installed() {
	local package=$1 candidate capability commands command
	local -a alternatives=()
	while IFS=$'\t' read -r candidate capability commands; do
		[[ $candidate == "$package" ]] || continue
		IFS=, read -r -a alternatives <<<"$commands"
		for command in "${alternatives[@]}"; do
			[[ $command == - ]] || { command -v "$command" >/dev/null 2>&1 && return 0; }
		done
		# pacman -T also matches packages that provide the capability.
		command -v pacman >/dev/null 2>&1 && pacman -T "$capability" >/dev/null 2>&1
		return $?
	done < <(dwm_packages arch provider-policy)
	return 1
}

dwm_install_aur_profile() {
	local profile=$1
	local packages=()
	local package

	while IFS= read -r package; do
		[[ -n $package ]] && packages+=("$package")
	done < <(dwm_packages "$DISTRO_FAMILY" "$profile")

	if ((${#packages[@]} == 0)); then
		return 0
	fi

	install_aur_packages "${packages[@]}"
}

dwm_install_available_package_profile() {
	local profile=$1
	local packages=()
	local package
	local status=0

	# Collect the list first: pacman inside the read loop would inherit the
	# list as stdin and answer its own confirmation prompt with a package name.
	while IFS= read -r package; do
		[[ -n $package ]] && packages+=("$package")
	done < <(dwm_packages "$DISTRO_FAMILY" "$profile")

	for package in "${packages[@]}"; do
		if ! install_optional_package "$package"; then
			printf 'Skipping unavailable optional package: %s\n' "$package" >&2
			status=1
		fi
	done

	return "$status"
}

dwm_install_first_available_package() {
	local package

	for package in "$@"; do
		if install_optional_package "$package" 2>/dev/null; then
			return 0
		fi
	done

	return 1
}

dwm_install_first_available_profile() {
	local profile=$1
	local packages=()
	local package

	while IFS= read -r package; do
		[[ -n $package ]] && packages+=("$package")
	done < <(dwm_packages "$DISTRO_FAMILY" "$profile")

	if ((${#packages[@]} == 0)); then
		return 1
	fi

	dwm_install_first_available_package "${packages[@]}"
}
