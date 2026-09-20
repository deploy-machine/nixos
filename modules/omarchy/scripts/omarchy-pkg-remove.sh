# Remove a menu-installed package from apps.json and rebuild.
apps_json="$OMARCHY_REPO/modules/omarchy/apps.json"

mapfile -t installed < <(jq -r '.packages[]' "$apps_json")
if [ "${#installed[@]}" -eq 0 ]; then
  echo "No menu-installed packages to remove."
  echo "(Packages declared elsewhere in the repo are not managed here.)"
  exit 0
fi

choice=$(printf '%s\n' "${installed[@]}" | gum choose --header "Remove package (esc to cancel)") || exit 0
[ -z "$choice" ] && exit 0

tmp=$(mktemp)
jq --arg p "$choice" '.packages -= [$p]' "$apps_json" >"$tmp"
mv "$tmp" "$apps_json"
echo ":: Removed '$choice' from apps.json"

omarchy-nixos-rebuild
