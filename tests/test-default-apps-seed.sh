#!/bin/bash
# Fresh-account application defaults seeded by install.sh.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
if [[ $(id -u) == 0 ]]; then
	# Exercise the real unprivileged guard even in root-run containers.
	mkdir -p "$work/repo/tests" "$work/repo/scripts"
	cp "$0" "$work/repo/tests/"
	cp "$repo/scripts/seed-default-apps.sh" "$work/repo/scripts/"
	chown -R nobody:"$(id -gn nobody)" "$work"
	runuser -u nobody -- env TMPDIR="$work" bash "$work/repo/tests/test-default-apps-seed.sh"
	exit
fi
seed=$repo/scripts/seed-default-apps.sh
export HOME=$work/home XDG_CONFIG_HOME=$work/home/.config XDG_DATA_HOME=$work/home/.local/share
mkdir -p "$XDG_CONFIG_HOME" "$work/bin"
export PATH="$work/bin:$PATH"
# The removed image mode and any other argument are rejected.
for argument in --image --unknown; do
	if bash "$seed" "$argument" 2>/dev/null; then
		printf 'Seeder accepted an argument: %s\n' "$argument" >&2
		exit 1
	fi
done
[[ ! -e $XDG_CONFIG_HOME/mimeapps.list ]]
# An existing MIME file must prevent any default-setting operation.
printf '[Default Applications]\nimage/png=custom.desktop;\n' >"$XDG_CONFIG_HOME/mimeapps.list"
cp "$XDG_CONFIG_HOME/mimeapps.list" "$work/mime"
bash "$seed"
cmp "$work/mime" "$XDG_CONFIG_HOME/mimeapps.list"
# Exercise a fresh account with real xdg-mime and isolated desktop entries.
export XDG_DATA_DIRS="$work/system-data"
mkdir -p "$XDG_DATA_DIRS/applications"
for app in celluloid sxiv brave-origin dolphin; do
	printf '#!/bin/sh\nexit 0\n' >"$work/bin/$app"
	chmod +x "$work/bin/$app"
done
cat >"$XDG_DATA_DIRS/applications/io.github.celluloid_player.Celluloid.desktop" <<'APP'
[Desktop Entry]
Type=Application
Name=Celluloid
Exec=celluloid %U
MimeType=audio/mpeg;audio/flac;video/mp4;application/ogg;application/x-matroska;
APP
cat >"$XDG_DATA_DIRS/applications/sxiv.desktop" <<'APP'
[Desktop Entry]
Type=Application
Name=sxiv
Exec=sxiv %F
NoDisplay=true
MimeType=image/png;image/jpeg;
APP
cat >"$XDG_DATA_DIRS/applications/brave-origin.desktop" <<'APP'
[Desktop Entry]
Type=Application
Name=Brave Origin
Exec=brave-origin %U
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;image/png;application/pdf;
APP
cat >"$XDG_DATA_DIRS/applications/org.kde.dolphin.desktop" <<'APP'
[Desktop Entry]
Type=Application
Name=Dolphin
Exec=dolphin %u
MimeType=inode/directory;
APP
rm "$XDG_CONFIG_HOME/mimeapps.list"
bash "$seed"
for mime in audio/mpeg audio/flac video/mp4 application/ogg application/x-matroska; do
	[[ $(xdg-mime query default "$mime") == io.github.celluloid_player.Celluloid.desktop ]]
done
for mime in image/png image/jpeg; do
	[[ $(xdg-mime query default "$mime") == sxiv.desktop ]]
done
# An installed optional browser is used for the web and PDF types only.
[[ $(xdg-mime query default x-scheme-handler/https) == brave-origin.desktop ]]
[[ $(xdg-mime query default inode/directory) == org.kde.dolphin.desktop ]]
if grep -q 'image/webp=' "$XDG_CONFIG_HOME/mimeapps.list"; then exit 1; fi
cp "$XDG_CONFIG_HOME/mimeapps.list" "$work/seeded-mimes"
bash "$seed"
cmp "$XDG_CONFIG_HOME/mimeapps.list" "$work/seeded-mimes"
# Ensure no duplicate keys exist in mimeapps.list
[[ $(grep -c '^inode/directory=' "$XDG_CONFIG_HOME/mimeapps.list") == 1 ]]
[[ $(grep -c '^image/png=' "$XDG_CONFIG_HOME/mimeapps.list") == 1 ]]
# Missing required desktop entries must fail without leaving a partial seed.
rm "$XDG_CONFIG_HOME/mimeapps.list"
mv "$XDG_DATA_DIRS/applications/sxiv.desktop" "$work/sxiv.desktop"
if bash "$seed"; then
	echo 'Missing image handler was accepted' >&2
	exit 1
fi
[[ ! -e $XDG_CONFIG_HOME/mimeapps.list ]]
mv "$work/sxiv.desktop" "$XDG_DATA_DIRS/applications/sxiv.desktop"
# The browser and file manager are optional.
rm "$XDG_DATA_DIRS/applications/brave-origin.desktop" \
	"$XDG_DATA_DIRS/applications/org.kde.dolphin.desktop"
bash "$seed"
[[ $(xdg-mime query default video/mp4) == io.github.celluloid_player.Celluloid.desktop ]]
if grep -Eq 'brave-origin|inode/directory' "$XDG_CONFIG_HOME/mimeapps.list"; then exit 1; fi
rm "$XDG_CONFIG_HOME/mimeapps.list"
# A desktop-specific MIME file is a user preference too.
printf '[Default Applications]\nimage/png=custom.desktop;\n' >"$XDG_CONFIG_HOME/dwm-mimeapps.list"
bash "$seed"
[[ ! -e $XDG_CONFIG_HOME/mimeapps.list ]]
rm "$XDG_CONFIG_HOME/dwm-mimeapps.list"
# A preference created after discovery but before publication must win.
real_ln=$(command -v ln)
export DWM_TEST_REAL_LN=$real_ln
cat >"$work/bin/ln" <<'SH'
#!/bin/sh
printf '[Default Applications]\ntext/plain=user-editor.desktop;\n' >"$XDG_CONFIG_HOME/mimeapps.list"
exec "$DWM_TEST_REAL_LN" "$@"
SH
chmod +x "$work/bin/ln"
bash "$seed"
printf '[Default Applications]\ntext/plain=user-editor.desktop;\n' >"$work/concurrent-mimes"
cmp "$work/concurrent-mimes" "$XDG_CONFIG_HOME/mimeapps.list"
[[ -z $(find "$XDG_CONFIG_HOME" -name '.dwm-mimeapps.*' -print -quit) ]]
printf 'Fresh-account application defaults: PASS\n'
