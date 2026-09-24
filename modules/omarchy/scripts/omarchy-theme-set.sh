# Theme switcher (omarchy-theme-switcher + omarchy-theme-set, declarative
# edition). Shows every theme — Omarchy's full set plus this repo's own —
# as a grid of preview images, writes the pick to theme.json and rebuilds.
# Everything palette-driven follows: hyprland, kitty, rofi, swaync,
# hyprlock, the quickshell bar, the prompt, neovim and Stylix (GTK/Qt/…),
# and the default wallpaper flips to the theme's set.
#
#   omarchy-theme-set            pick from the grid
#   omarchy-theme-set <name>     switch directly
#   omarchy-theme-set --list     print theme names
theme_json="$OMARCHY_REPO/modules/omarchy/theme.json"
current=$(jq -r '.theme' "$theme_json")

# $OMARCHY_THEMES: the themes tree (one directory per theme, the same one
# deployed to ~/.config/omarchy/themes), baked from theme.nix at build time
# so the list never drifts from the registry.
mapfile -t themes < <(find -L "$OMARCHY_THEMES" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

target="${1-}"
if [ "$target" = "--list" ]; then
  printf '%s\n' "${themes[@]}"
  exit 0
fi

# rofi dmenu rows: "label\0icon\x1f<preview>" (NUL can't live in a bash
# variable, so rows are streamed straight into rofi).
entries() {
  local name dir label
  for name in "${themes[@]}"; do
    dir="$OMARCHY_THEMES/$name"
    label="$name"
    grep -q '^mode *= *"light"' "$dir/colors.toml" 2>/dev/null && label="$label  "
    [ "$name" = "$current" ] && label="$label  ✓"
    if [ -f "$dir/preview.png" ]; then
      printf '%s\0icon\x1f%s\n' "$label" "$dir/preview.png"
    else
      printf '%s\n' "$label"
    fi
  done
}

if [ -z "$target" ]; then
  selected=0
  for i in "${!themes[@]}"; do
    [ "${themes[$i]}" = "$current" ] && selected=$i
  done

  choice=$(entries | rofi -dmenu -i -show-icons -p "Theme" \
    -selected-row "$selected" \
    -theme-str 'window { width: 70%; }
                listview { columns: 4; lines: 3; spacing: 12px; flow: horizontal; }
                element { orientation: vertical; padding: 8px; spacing: 6px; }
                element-icon { size: 180px; }
                element-text { horizontal-align: 0.5; }') || exit 0
  [ -z "$choice" ] && exit 0
  target="${choice%% *}"
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
