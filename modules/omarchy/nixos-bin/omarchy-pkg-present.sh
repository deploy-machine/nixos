# True when every named package is installed. Used by the menu's
# installed/not-installed guards. A name counts as installed when it's in
# modules/omarchy/apps.json (menu-installed nixpkgs attribute) or a command
# of that name is on PATH (declared anywhere else in the config).
apps_json="$OMARCHY_REPO/modules/omarchy/apps.json"
for pkg in "$@"; do
  jq -e --arg p "$pkg" '.packages | index($p)' "$apps_json" >/dev/null 2>&1 && continue
  command -v "$pkg" >/dev/null 2>&1 && continue
  exit 1
done
