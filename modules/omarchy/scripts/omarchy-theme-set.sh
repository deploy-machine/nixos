# Theme switcher (omarchy-theme-set, declarative edition): pick a palette
# from the registry in modules/omarchy/theme.nix, write the selection to
# theme.json, rebuild. Everything that imports colors.nix — hyprland,
# kitty, rofi, swaync, the quickshell bar, hyprlock, the prompt — follows,
# and the default wallpaper flips to the theme's set.
theme_json="$OMARCHY_REPO/modules/omarchy/theme.json"
current=$(jq -r '.theme' "$theme_json")

# Themes come from the registry so this never drifts from theme.nix.
mapfile -t themes < <(nix eval --json --file "$OMARCHY_REPO/modules/omarchy/theme.nix" names 2>/dev/null | jq -r '.[]')
if [ "${#themes[@]}" -eq 0 ]; then
  themes=(koda-dark vantablack)
fi

target="${1-}"
if [ -z "$target" ]; then
  labels=()
  for t in "${themes[@]}"; do
    if [ "$t" = "$current" ]; then labels+=("󰸌  $t ✓"); else labels+=("󰸌  $t"); fi
  done
  choice=$(printf '%s\n' "${labels[@]}" | rofi -dmenu -i -p "Theme") || exit 0
  [ -z "$choice" ] && exit 0
  target=$(echo "$choice" | sed -e 's/^󰸌  //' -e 's/ ✓$//')
fi

if ! printf '%s\n' "${themes[@]}" | grep -qx "$target"; then
  echo "Unknown theme '$target'. Available: ${themes[*]}" >&2
  exit 1
fi

if [ "$target" = "$current" ]; then
  notify-send -a Omarchy -e "󰸌  Theme" "'$target' is already active"
  exit 0
fi

tmp=$(mktemp)
jq --arg t "$target" '.theme = $t' "$theme_json" >"$tmp"
mv "$tmp" "$theme_json"

omarchy-floating-term omarchy-nixos-rebuild
