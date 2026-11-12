#!/usr/bin/env bash
# Installer-only integration; never invoked by Settings or session startup.
set -euo pipefail

# shellcheck source=scripts/dwm-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/dwm-utils.sh"
if [[ $DISTRO_FAMILY != arch ]]; then
	printf 'Automatic time synchronization setup supports Arch Linux only.\n' >&2
	exit 1
fi

# Offline systemctl may return success for ignored queries without a value.
# Require a real manager response before querying active state or starting units.
manager_version=$(systemctl show --property=Version --value 2>/dev/null || true)

# Check enabled as well as active providers so repeated installs never
# introduce a second clock discipline service.
for provider in chronyd.service chronyd-restricted.service ntpd.service ntpsec.service openntpd.service; do
	if systemctl is-enabled --quiet "$provider" 2>/dev/null ||
		{ [[ -n $manager_version ]] && systemctl is-active --quiet "$provider" 2>/dev/null; }; then
		printf 'Preserving existing time synchronization provider: %s\n' "$provider"
		exit 0
	fi
done

state=$(systemctl is-enabled systemd-timesyncd.service 2>/dev/null || true)
case "$state" in
masked | masked-runtime)
	printf 'Preserving masked systemd-timesyncd.service; automatic time synchronization was not enabled.\n'
	exit 0
	;;
esac
# Keep repository helper code unprivileged; elevate only the fixed systemctl
# operations.
service_command=(systemctl)
if ((EUID != 0)); then service_command=(sudo systemctl); fi
printf 'Enabling systemd-timesyncd.service for automatic time synchronization.\n'
"${service_command[@]}" enable systemd-timesyncd.service
# Without a running manager (for example in a chroot), enable only; the
# service starts at the next boot.
if [[ -n $manager_version ]]; then
	"${service_command[@]}" start systemd-timesyncd.service
fi
