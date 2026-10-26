#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT

snapshot_tree() {
	local root=$1 output=$2
	{
		find "$root" -printf 'entry\t%P\t%y\t%m\t%s\t%l\n'
		find "$root" -type f -exec sha256sum {} + |
			sed "s#  $root/#  #"
	} | sort >"$output"
}

cat >"$work/arch" <<'EOF'
NAME="Arch Linux"
PRETTY_NAME="Arch Linux"
ID=arch
BUILD_ID=rolling
EOF
cat >"$work/unsupported" <<'EOF'
ID=example
PRETTY_NAME="Unsupported Linux"
EOF
# Arch derivatives advertise ID_LIKE=arch, which must not be trusted.
cat >"$work/endeavouros" <<'EOF'
ID=endeavouros
ID_LIKE=arch
PRETTY_NAME="EndeavourOS"
EOF
cat >"$work/cachyos" <<'EOF'
ID=cachyos
ID_LIKE=arch
PRETTY_NAME="CachyOS Linux"
EOF
cat >"$work/manjaro" <<'EOF'
ID=manjaro
ID_LIKE=arch
PRETTY_NAME="Manjaro Linux"
EOF
cat >"$work/fedora" <<'EOF'
ID=fedora
PRETTY_NAME="Fedora Linux 44"
EOF

family_for() {
	DWM_TEST_MODE=1 DWM_OS_RELEASE="$1" bash -c \
		'. "$1"; printf "%s" "$DISTRO_FAMILY"' sh "$repo/scripts/dwm-utils.sh"
}

# Arch has no VERSION_ID; detection must not depend on it.
[[ $(family_for "$work/arch") == arch ]]
for identity in unsupported endeavouros cachyos manjaro fedora; do
	family=$(family_for "$work/$identity")
	if [[ $family != unknown ]]; then
		printf 'Identity %s resolved to family %s instead of unknown.\n' \
			"$identity" "$family" >&2
		exit 1
	fi
done

mkdir -p "$work/bin" "$work/unsupported-home"
for command_name in chmod chown cp curl git install ln make mkdir mv pacman paru rm sudo systemctl tee touch unzip usermod yay; do
	cat >"$work/bin/$command_name" <<'EOF'
#!/usr/bin/env bash
printf '%s\t%s\n' "${0##*/}" "$*" >>"${DWM_MUTATION_LOG:?}"
exit 99
EOF
done
/usr/bin/chmod +x "$work/bin/"*

for identity in unsupported endeavouros manjaro; do
	snapshot_tree "$work/unsupported-home" "$work/home.before"
	set +e
	DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/$identity" \
		DWM_MUTATION_LOG="$work/mutations.log" HOME="$work/unsupported-home" \
		PATH="$work/bin:$PATH" "$repo/install.sh" \
		--non-interactive --profile core >"$work/install-rejection.out" 2>&1
	install_status=$?
	set -e
	if [[ $install_status -ne 1 ]]; then
		printf 'Installer on %s exited with %s instead of 1.\n' \
			"$identity" "$install_status" >&2
		exit 1
	fi
	grep -Fq 'Unsupported distribution:' "$work/install-rejection.out"
	grep -Fq 'dwm-titus supports Arch Linux only.' "$work/install-rejection.out"
	if [[ -e $work/mutations.log ]]; then
		printf 'Installer on %s attempted a package or system mutation.\n' "$identity" >&2
		exit 1
	fi
	snapshot_tree "$work/unsupported-home" "$work/home.after"
	cmp "$work/home.before" "$work/home.after"
done

awk -v os_release="$work/endeavouros" '
	$0 == "OS_RELEASE_FILE=/etc/os-release" {
		print "OS_RELEASE_FILE=" os_release
		next
	}
	{ print }
' "$repo/scripts/power-management.sh" >"$work/power-management-unsupported"
grep -Fqx "OS_RELEASE_FILE=$work/endeavouros" \
	"$work/power-management-unsupported"
chmod +x "$work/power-management-unsupported"
set +e
"$work/power-management-unsupported" --apply >"$work/power-rejection.out" 2>&1
power_status=$?
set -e
if [[ $power_status -ne 1 ]]; then
	printf 'Unsupported power mutation exited with %s instead of 1.\n' \
		"$power_status" >&2
	exit 1
fi
grep -Fq -- '--apply and --apply-tlp support Arch Linux only.' \
	"$work/power-rejection.out"
if grep -Fq 'System Identity' "$work/power-rejection.out"; then
	printf 'Unsupported power mutation continued into the status report.\n' >&2
	exit 1
fi

# Outside test mode the real host identity is used, never the override.
# Expansion is intentionally deferred to the child shell.
# shellcheck disable=SC2016
host_family=$(env -u DWM_TEST_MODE DWM_OS_RELEASE="$work/unsupported" bash -c \
	'. "$1"; printf "%s" "$DISTRO_FAMILY"' sh "$repo/scripts/dwm-utils.sh")
[[ $host_family == arch ]]

package_command=$(DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/arch" bash -c \
	'. "$1"; printf "%s" "$PKG_CMD"' sh "$repo/scripts/dwm-utils.sh")
if [[ $EUID -eq 0 ]]; then
	[[ $package_command == 'pacman -S --needed' ]]
else
	[[ $package_command == 'sudo pacman -S --needed' ]]
fi

# --noconfirm is passed only for explicitly non-interactive installs.
# shellcheck disable=SC2016
interactive_args=$(DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/arch" bash -c \
	'. "$1"; dwm_pacman_confirm_args' sh "$repo/scripts/dwm-utils.sh")
[[ -z $interactive_args ]]
# shellcheck disable=SC2016
noninteractive_args=$(DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/arch" DWM_PACKAGE_NONINTERACTIVE=1 \
	bash -c '. "$1"; dwm_pacman_confirm_args' sh "$repo/scripts/dwm-utils.sh")
[[ $noninteractive_args == --noconfirm ]]

set +e
snapshot_tree "$work/unsupported-home" "$work/screensaver-home.before"
DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/cachyos" \
	DWM_MUTATION_LOG="$work/mutations.log" HOME="$work/unsupported-home" \
	PATH="$work/bin:$PATH" "$repo/scripts/xscreensaver-setup.sh" \
	>"$work/xscreensaver-rejection.out" 2>&1
screensaver_status=$?
set -e
if [[ $screensaver_status -ne 1 ]]; then
	printf 'Unsupported screensaver setup exited with %s instead of 1.\n' \
		"$screensaver_status" >&2
	exit 1
fi
grep -Fq 'dwm-titus supports Arch Linux only.' "$work/xscreensaver-rejection.out"
snapshot_tree "$work/unsupported-home" "$work/screensaver-home.after"
if [[ -e $work/mutations.log ]] ||
	! cmp "$work/screensaver-home.before" "$work/screensaver-home.after"; then
	printf 'Unsupported screensaver setup attempted a mutation.\n' >&2
	exit 1
fi

selinux_pattern='setenforce|/etc/selinux/config|(^|[[:space:]])(sudo[[:space:]]+)?chcon([[:space:]]|$)|semanage[[:space:]]+fcontext'
# Allow only the fixed read-only source-map declaration, not the whole reader.
# Every other path reference and all policy/context mutation commands still fail.
selinux_read_source="$repo/scripts/dwm-system-management:    \"selinux-config\": (\"/etc/selinux/config\", 64 * 1024),"
selinux_forbidden_matches() {
	local line
	while IFS= read -r line; do
		if [[ $line != "$selinux_read_source" ]]; then
			return 0
		fi
	done
	return 1
}

# Keep the exception exact, including its file and complete source line.
if selinux_forbidden_matches <<<"$selinux_read_source"; then
	printf 'SELinux read-only declaration was not recognized.\n' >&2
	exit 1
fi
for statement in \
	'open("/etc/selinux/config", "w")' \
	'setenforce 0' \
	'sudo chcon -t bin_t helper' \
	'semanage fcontext -a -t bin_t helper'; do
	grep -Eq "$selinux_pattern" <<<"$statement"
	selinux_forbidden_matches <<<"$repo/scripts/dwm-system-management:$statement"
done
selinux_forbidden_matches <<<"$repo/install.sh:${selinux_read_source#*:}"
selinux_forbidden_matches <<<"$selinux_read_source # changed"

if grep -ERH "$selinux_pattern" "$repo/install.sh" "$repo/scripts" >"$work/selinux-matches"; then
	:
else
	scan_status=$?
	if [[ $scan_status -ne 1 ]]; then
		printf 'SELinux policy scan failed with status %s.\n' "$scan_status" >&2
		exit "$scan_status"
	fi
fi
if selinux_forbidden_matches <"$work/selinux-matches"; then
	printf 'Existing-system tools must not change host LSM policy or assign file contexts.\n' >&2
	exit 1
fi

printf 'Arch-only platform contract: PASS\n'

# The dry run lists the full system upgrade and the AUR opt-in without
# changing anything.
snapshot_tree "$work/unsupported-home" "$work/dry-run-home.before"
DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/arch" \
	DWM_MUTATION_LOG="$work/mutations.log" HOME="$work/unsupported-home" \
	PATH="$work/bin:$PATH" "$repo/install.sh" \
	--dry-run --non-interactive --profile full >"$work/dry-run.out" 2>&1
grep -Fq 'System upgrade: sudo pacman -Syu' "$work/dry-run.out"
grep -Fq 'AUR packages: skipped' "$work/dry-run.out"
grep -Fq 'dolphin' "$work/dry-run.out"
for removed in steam gamescope gamemode mangohud Thunar thunar path dnf; do
	if grep -Eqw -- "$removed" "$work/dry-run.out"; then
		printf 'Dry run still lists removed component: %s\n' "$removed" >&2
		exit 1
	fi
done
if [[ -e $work/mutations.log ]]; then
	printf 'Dry run attempted a package or system mutation.\n' >&2
	exit 1
fi
snapshot_tree "$work/unsupported-home" "$work/dry-run-home.after"
cmp "$work/dry-run-home.before" "$work/dry-run-home.after"
if "$repo/install.sh" --enable-fedora-gaming-repos --dry-run >/dev/null 2>&1; then
	printf 'Removed gaming repository flag is still accepted.\n' >&2
	exit 1
fi

# The first change on a supported system is a full upgrade. If it fails, the
# installer stops before any package installation or build step.
mkdir -p "$work/user/repo/scripts" "$work/user/home"
cp "$repo/install.sh" "$work/user/repo/"
cp "$repo/scripts/dwm-utils.sh" "$repo/scripts/dwm-packages.sh" "$work/user/repo/scripts/"
cp -a "$work/bin" "$work/user/bin"
cp "$work/arch" "$work/user/os-release"
run_as_user=()
if [[ $EUID -eq 0 ]]; then
	# Let the unprivileged user traverse, but not list, the private workspace.
	chmod 0711 "$work"
	chown -R nobody:"$(id -gn nobody)" "$work/user"
	run_as_user=(runuser -u nobody --)
	if ! "${run_as_user[@]}" test -x "$work/user/repo/install.sh"; then
		printf 'Root-run platform tests need a workspace that nobody can traverse.\n' >&2
		printf 'Set DWM_TEST_TMP_ROOT outside /root (CI uses /var/tmp/dwm-ci).\n' >&2
		exit 1
	fi
fi
run_user_install() {
	local output=$1
	shift
	"${run_as_user[@]}" env DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/user/os-release" \
		DWM_MUTATION_LOG="$work/user/mutations.log" HOME="$work/user/home" \
		PATH="$work/user/bin:$PATH" "$work/user/repo/install.sh" "$@" >"$output" 2>&1
}
set +e
run_user_install "$work/upgrade-first.out" --non-interactive --profile core </dev/null
upgrade_status=$?
set -e
if [[ $upgrade_status -ne 1 ]]; then
	printf 'Installer with a failed upgrade exited with %s instead of 1.\n' "$upgrade_status" >&2
	cat "$work/upgrade-first.out" >&2
	exit 1
fi
grep -Fq 'System upgrade failed or was declined' "$work/upgrade-first.out"
# Only the explicit --non-interactive flag adds --noconfirm.
printf 'sudo\tpacman -Syu --noconfirm\n' >"$work/upgrade-first.expected"
cmp "$work/upgrade-first.expected" "$work/user/mutations.log"
rm -f "$work/user/mutations.log"
printf 'Installer upgrades the system before installing packages: PASS\n'

# Unattended mode is never inferred. Without a terminal on stdin and without
# --non-interactive, the installer refuses before any change, even with --yes.
for refusal_flags in '' '--yes'; do
	snapshot_tree "$work/user/home" "$work/no-tty-home.before"
	refusal_args=(--profile core)
	[[ -z $refusal_flags ]] || refusal_args+=("$refusal_flags")
	set +e
	run_user_install "$work/no-tty.out" "${refusal_args[@]}" </dev/null
	refusal_status=$?
	set -e
	if [[ $refusal_status -ne 1 ]]; then
		printf 'Installer without a terminal (%s) exited with %s instead of 1.\n' \
			"${refusal_args[*]}" "$refusal_status" >&2
		cat "$work/no-tty.out" >&2
		exit 1
	fi
	grep -Fq 'Standard input is not a terminal' "$work/no-tty.out"
	grep -Fq 'pass --non-interactive for an unattended install' "$work/no-tty.out"
	if [[ -e $work/user/mutations.log ]] || grep -Fq 'Installation summary' "$work/no-tty.out"; then
		printf 'Installer without a terminal continued past the mode check.\n' >&2
		exit 1
	fi
	snapshot_tree "$work/user/home" "$work/no-tty-home.after"
	cmp "$work/no-tty-home.before" "$work/no-tty-home.after"
done
# A dry run needs no prompts, so it still works without a terminal.
run_user_install "$work/no-tty-dry-run.out" --dry-run --profile core </dev/null
grep -Fq 'Mode: interactive' "$work/no-tty-dry-run.out"
grep -Fq 'Dry run complete; no changes were made.' "$work/no-tty-dry-run.out"
[[ ! -e $work/user/mutations.log ]]

# Redirected stdout with a terminal on stdin keeps the interactive mode: the
# installer asks its questions and pacman gets no --noconfirm.
if command -v script >/dev/null 2>&1; then
	pty_command=$(printf '%q ' env DWM_TEST_MODE=1 \
		DWM_OS_RELEASE="$work/user/os-release" \
		DWM_MUTATION_LOG="$work/user/mutations.log" HOME="$work/user/home" \
		PATH="$work/user/bin:$PATH" "$work/user/repo/install.sh" --profile core)
	pty_command+=">$(printf '%q' "$work/user/pty.out") 2>&1"
	set +e
	# script(1) runs the command with $SHELL; runuser sets nobody's nologin shell.
	printf 'n\ny\n' | "${run_as_user[@]}" env SHELL=/bin/bash \
		script -qec "$pty_command" /dev/null >/dev/null 2>&1
	pty_status=$?
	set -e
	if [[ $pty_status -ne 1 ]]; then
		printf 'Interactive install with redirected stdout exited with %s instead of 1.\n' \
			"$pty_status" >&2
		cat "$work/user/pty.out" >&2 || true
		exit 1
	fi
	grep -Fq 'Mode: interactive' "$work/user/pty.out"
	grep -Fq 'Install optional AUR packages' "$work/user/pty.out"
	grep -Fq 'Skipping optional AUR packages.' "$work/user/pty.out"
	grep -Fq 'Continue with installation? [y/N]' "$work/user/pty.out"
	grep -Fq 'System upgrade failed or was declined' "$work/user/pty.out"
	printf 'sudo\tpacman -Syu\n' >"$work/pty-upgrade.expected"
	cmp "$work/pty-upgrade.expected" "$work/user/mutations.log"
	rm -f "$work/user/mutations.log"
else
	printf 'SKIP: script(1) is unavailable; redirected-stdout interactive mode not exercised.\n'
fi
printf 'Installer interaction mode follows --non-interactive only: PASS\n'

# AUR helpers never run as root and are never bootstrapped.
aur_dir="$work/aur-user"
mkdir -p "$aur_dir/helper-bin"
cp "$work/bin/paru" "$aur_dir/helper-bin/"
cp "$repo/scripts/dwm-utils.sh" "$work/arch" "$aur_dir/"
if [[ $EUID -eq 0 ]]; then
	# shellcheck disable=SC2016
	if DWM_TEST_MODE=1 DWM_OS_RELEASE="$aur_dir/arch" PATH="$aur_dir/helper-bin:$PATH" \
		DWM_MUTATION_LOG="$aur_dir/aur.log" bash -c '. "$1"; install_aur_packages xkbset' \
		sh "$aur_dir/dwm-utils.sh" >"$work/aur-root.out" 2>&1; then
		printf 'AUR install succeeded as root.\n' >&2
		exit 1
	fi
	grep -Fq 'Refusing to run an AUR helper as root.' "$work/aur-root.out"
	if [[ -e $aur_dir/aur.log ]]; then
		printf 'AUR helper ran as root.\n' >&2
		exit 1
	fi
	chown -R nobody:"$(id -gn nobody)" "$aur_dir"
fi
# The unprivileged branch runs in every gate; root-run gates use nobody.
# shellcheck disable=SC2016
"${run_as_user[@]}" env DWM_TEST_MODE=1 DWM_OS_RELEASE="$aur_dir/arch" \
	PATH="$aur_dir/helper-bin:$PATH" DWM_MUTATION_LOG="$aur_dir/aur.log" \
	bash -c '. "$1"; install_aur_packages xkbset' sh "$aur_dir/dwm-utils.sh" \
	>/dev/null 2>&1 || true
printf 'paru\t-S --needed -- xkbset\n' >"$work/aur.expected"
cmp "$work/aur.expected" "$aur_dir/aur.log"
rm -f "$aur_dir/aur.log"
# Without an installed helper nothing runs and nothing is bootstrapped.
# shellcheck disable=SC2016
if "${run_as_user[@]}" env DWM_TEST_MODE=1 DWM_OS_RELEASE="$aur_dir/arch" \
	PATH="$work/bin:$PATH" DWM_MUTATION_LOG="$aur_dir/aur.log" bash -c '
		. "$1"
		dwm_aur_helper() { return 1; }
		install_aur_packages xkbset
	' sh "$aur_dir/dwm-utils.sh" >"$work/aur.out" 2>&1; then
	printf 'AUR install succeeded without an AUR helper.\n' >&2
	exit 1
fi
grep -Fq 'No AUR helper (paru or yay) is installed' "$work/aur.out"
if [[ -e $aur_dir/aur.log ]]; then
	printf 'AUR install without a helper attempted a mutation.\n' >&2
	exit 1
fi
printf 'AUR packages require an existing helper run as the user: PASS\n'
