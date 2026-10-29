#!/bin/sh
# Every key in the shipped window rules must be one dwm reads; an unknown key
# (such as float=1 instead of isfloating=1) is ignored without any warning.
set -eu

repo=$(
	unset CDPATH
	cd -- "$(dirname -- "$0")/.." && pwd
)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

grep -o 'toml_table_get(&doc, "rules", i, "[a-z]*")' "$repo/dwm.c" |
	sed -E 's/.*"([a-z]+)"\)$/\1/' | sort -u >"$work/known"
grep -Fxq isfloating "$work/known"
grep -E '^[[:space:]]*\{' "$repo/config/window-rules.toml" |
	grep -oE '[a-z_]+=' | tr -d '=' | sort -u >"$work/used"
[ -s "$work/used" ]
if comm -23 "$work/used" "$work/known" | grep .; then
	printf 'window-rules.toml uses keys dwm does not read (listed above).\n' >&2
	exit 1
fi
printf 'Window rule keys: PASS\n'
