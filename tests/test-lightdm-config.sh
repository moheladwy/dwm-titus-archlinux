#!/usr/bin/env bash
set -euo pipefail

repo=$(
	unset CDPATH
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd
)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

dropin_path=etc/lightdm/lightdm.conf.d/50-dwm-titus.conf
cat >"$work/dropin.expected" <<'CONF'
# Installed by dwm-titus. LightDM reads lightdm.conf.d drop-ins before
# /etc/lightdm/lightdm.conf, so any value set there still takes precedence.
[LightDM]
logind-check-graphical=true

[Seat:*]
greeter-session=lightdm-slick-greeter
user-session=dwm
CONF

assert_stage() {
	local stage=$1

	cmp "$work/dropin.expected" "$stage/$dropin_path"
	[[ $(stat -c %a "$stage/$dropin_path") == 644 ]]
	grep -Fqx 'xft-dpi=96' "$stage/etc/lightdm/slick-greeter.conf"
	grep -Fqx 'activate-numlock=false' "$stage/etc/lightdm/slick-greeter.conf"
	[[ -f $stage/usr/share/pixmaps/dwm-titus.jpg ]]
	[[ -f $stage/usr/share/pixmaps/dwm-titus-logo.png ]]
	# The installer owns only the drop-in; nothing else is written there.
	[[ $(find "$stage/etc/lightdm/lightdm.conf.d" -mindepth 1 | wc -l) -eq 1 ]]
	if find "$stage/etc/lightdm" -name '*.bak' | grep -q .; then
		printf 'LightDM install created a backup of lightdm.conf.\n' >&2
		exit 1
	fi
}

# A fresh stage gets the drop-in and never a lightdm.conf.
fresh_stage="$work/fresh"
make -C "$repo/lightdm" --no-print-directory DESTDIR="$fresh_stage" install >/dev/null
assert_stage "$fresh_stage"
if [[ -e $fresh_stage/etc/lightdm/lightdm.conf ]]; then
	printf 'LightDM install created lightdm.conf.\n' >&2
	exit 1
fi

# An administrator's lightdm.conf, such as one with autologin, stays untouched.
custom_stage="$work/custom"
mkdir -p "$custom_stage/etc/lightdm"
cat >"$custom_stage/etc/lightdm/lightdm.conf" <<'CONF'
[Seat:*]
autologin-user=example
autologin-session=dwm
session-wrapper=/etc/lightdm/Xsession
CONF
chmod 0600 "$custom_stage/etc/lightdm/lightdm.conf"
touch -d '2001-02-03 04:05:06' "$custom_stage/etc/lightdm/lightdm.conf"
cp -p "$custom_stage/etc/lightdm/lightdm.conf" "$work/custom-lightdm.conf.before"
stat -c '%a %s %Y' "$custom_stage/etc/lightdm/lightdm.conf" >"$work/custom.stat.before"
for _ in 1 2; do
	make -C "$repo/lightdm" --no-print-directory DESTDIR="$custom_stage" install >/dev/null
done
assert_stage "$custom_stage"
cmp "$work/custom-lightdm.conf.before" "$custom_stage/etc/lightdm/lightdm.conf"
stat -c '%a %s %Y' "$custom_stage/etc/lightdm/lightdm.conf" >"$work/custom.stat.after"
cmp "$work/custom.stat.before" "$work/custom.stat.after"

# The deprecated [SeatDefaults] lightdm.conf template is gone.
if [[ -e $repo/lightdm/lightdm.conf ]]; then
	printf 'Stale lightdm/lightdm.conf is still in the tree.\n' >&2
	exit 1
fi

# install.sh uses the drop-in install without lightdm.conf overrides.
# shellcheck disable=SC2016
grep -Fqx '	sudo make -C "$REPO_DIR/lightdm" install' "$repo/install.sh"
if grep -Eq 'LIGHTDM_[A-Z_]+=' "$repo/install.sh"; then
	printf 'install.sh still passes LightDM rendering overrides.\n' >&2
	exit 1
fi

printf 'LightDM drop-in config: PASS\n'
