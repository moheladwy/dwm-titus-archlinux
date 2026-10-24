#!/usr/bin/env bash
set -euo pipefail

repo=$(
	unset CDPATH
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd
)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

arch_stage="$work/arch"

# Defaults must render the Arch Linux configuration without overrides.
make -C "$repo/lightdm" --no-print-directory \
	DESTDIR="$arch_stage" \
	install >/dev/null
cat >"$work/arch.expected" <<'CONF'
[LightDM]
logind-check-graphical=true

[Seat:*]
greeter-session=lightdm-slick-greeter
user-session=dwm
session-wrapper=/etc/lightdm/Xsession
CONF
cmp -s "$work/arch.expected" "$arch_stage/etc/lightdm/lightdm.conf"

grep -Fqx 'xft-dpi=96' "$arch_stage/etc/lightdm/slick-greeter.conf"
grep -Fqx 'activate-numlock=false' "$arch_stage/etc/lightdm/slick-greeter.conf"

# install.sh must pass the same Arch values explicitly.
for expected in 'LIGHTDM_SEAT_SECTION="Seat:*"' \
	'LIGHTDM_GREETER_SESSION="lightdm-slick-greeter"' \
	'LIGHTDM_SESSION_WRAPPER="/etc/lightdm/Xsession"' \
	'LIGHTDM_LOGIND_CHECK=true'; do
	grep -Fq "$expected" "$repo/install.sh"
done

printf 'LightDM config rendering: PASS\n'
