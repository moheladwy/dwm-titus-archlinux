#!/usr/bin/env bash
set -euo pipefail
umask 022

repo=$(
	unset CDPATH
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd
)
script="$repo/scripts/nvidia-suspend-test.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Run one helper from the sourced script; sourcing must not run the checks.
helper() {
	bash -c '. "$1"; shift; "$@"' nvidia-suspend-test "$script" "$@"
}

[[ -z $(helper true) ]]

# The main file alone.
mkdir -p "$work/main"
cat >"$work/main/mkinitcpio.conf" <<'EOF'
MODULES=(nvidia nvidia_modeset)
HOOKS=(base udev kms)
EOF
helper mkinitcpio_effective_config "$work/main/mkinitcpio.conf" >"$work/main.out"
printf 'module\tnvidia\nmodule\tnvidia_modeset\nhook\tbase\nhook\tudev\nhook\tkms\n' \
	>"$work/main.expected"
cmp "$work/main.expected" "$work/main.out"

# Drop-ins are read after the main file in version order, so 10-*.conf
# overrides 9-*.conf, and later += assignments append. Non-.conf entries and
# directories are ignored; symlinks to files are followed.
conf="$work/dropins/mkinitcpio.conf"
mkdir -p "$conf.d/sub.conf" "$work/dropins/elsewhere"
cat >"$conf" <<'EOF'
MODULES=(i915)
HOOKS=(base udev)
EOF
printf 'MODULES+=(early)\n' >"$conf.d/9-early.conf"
printf 'MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)\n' >"$conf.d/10-nvidia.conf"
printf 'MODULES+=(btrfs?)\n' >"$conf.d/20-optional.conf"
printf 'HOOKS+=(kms)\n' >"$work/dropins/elsewhere/hooks"
ln -s ../elsewhere/hooks "$conf.d/30-hooks.conf"
printf 'MODULES=(ignored)\n' >"$conf.d/40-backup.conf.bak"
printf 'MODULES=(ignored)\n' >"$conf.d/sub.conf/50-nested.conf"
helper mkinitcpio_config_files "$conf" | tr '\0' '\n' >"$work/files.out"
printf '%s\n' "$conf" "$conf.d/9-early.conf" "$conf.d/10-nvidia.conf" \
	"$conf.d/20-optional.conf" "$conf.d/30-hooks.conf" >"$work/files.expected"
cmp "$work/files.expected" "$work/files.out"
helper mkinitcpio_effective_config "$conf" >"$work/dropins.out"
printf '%s\n' $'module\tnvidia' $'module\tnvidia_modeset' $'module\tnvidia_uvm' \
	$'module\tnvidia_drm' $'module\tbtrfs?' $'hook\tbase' $'hook\tudev' \
	$'hook\tkms' >"$work/dropins.expected"
cmp "$work/dropins.expected" "$work/dropins.out"

# Legacy string values are split into words like mkinitcpio's arrayize_config,
# and the sourcing shell does not inherit the caller's environment.
mkdir -p "$work/legacy"
cat >"$work/legacy/mkinitcpio.conf" <<'EOF'
MODULES="nvidia nvidia_drm ${NVIDIA_TEST_LEAK:-}"
HOOKS="base kms"
EOF
NVIDIA_TEST_LEAK=leaked helper mkinitcpio_effective_config \
	"$work/legacy/mkinitcpio.conf" >"$work/legacy.out"
printf '%s\n' $'module\tnvidia' $'module\tnvidia_drm' $'hook\tbase' $'hook\tkms' \
	>"$work/legacy.expected"
cmp "$work/legacy.expected" "$work/legacy.out"

# Content writable by another user is never executed.
mkdir -p "$work/untrusted/mkinitcpio.conf.d"
printf 'MODULES=(nvidia)\n' >"$work/untrusted/mkinitcpio.conf"
printf ': >"%s"\n' "$work/untrusted/executed" >"$work/untrusted/mkinitcpio.conf.d/10-open.conf"
chmod 0666 "$work/untrusted/mkinitcpio.conf.d/10-open.conf"
set +e
helper mkinitcpio_effective_config "$work/untrusted/mkinitcpio.conf" >"$work/untrusted.out"
untrusted_status=$?
set -e
[[ $untrusted_status -eq 2 ]]
printf 'untrusted\t%s\n' "$work/untrusted/mkinitcpio.conf.d/10-open.conf" >"$work/untrusted.expected"
cmp "$work/untrusted.expected" "$work/untrusted.out"
[[ ! -e $work/untrusted/executed ]]

# modinfo locates the module wherever the package or DKMS installed it.
mkdir -p "$work/bin"
cat >"$work/bin/modinfo" <<'EOF'
#!/usr/bin/env bash
[[ $* == "-k 6.9.0-arch1-1 -n nvidia" ]] || exit 1
[[ ${NVIDIA_TEST_MODINFO_FAIL:-0} != 1 ]] || exit 1
printf '%s\n' /usr/lib/modules/6.9.0-arch1-1/updates/dkms/nvidia.ko.zst
EOF
chmod +x "$work/bin/modinfo"
module_path=$(PATH="$work/bin:$PATH" helper nvidia_module_path 6.9.0-arch1-1 "$work/modules")
[[ $module_path == /usr/lib/modules/6.9.0-arch1-1/updates/dkms/nvidia.ko.zst ]]

# Without a modinfo answer the Arch extramodules location is checked.
mkdir -p "$work/modules/6.9.0-arch1-1/extramodules"
: >"$work/modules/6.9.0-arch1-1/extramodules/nvidia.ko.xz"
module_path=$(NVIDIA_TEST_MODINFO_FAIL=1 PATH="$work/bin:$PATH" \
	helper nvidia_module_path 6.9.0-arch1-1 "$work/modules")
[[ $module_path == "$work/modules/6.9.0-arch1-1/extramodules/nvidia.ko.xz" ]]
if NVIDIA_TEST_MODINFO_FAIL=1 PATH="$work/bin:$PATH" \
	helper nvidia_module_path 6.10.0-arch1-1 "$work/modules" >/dev/null; then
	printf 'A missing nvidia module was reported as present.\n' >&2
	exit 1
fi

printf 'NVIDIA suspend checker mkinitcpio and module lookup: PASS\n'
