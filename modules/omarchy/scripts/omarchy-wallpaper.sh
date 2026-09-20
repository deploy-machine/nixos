# Background switcher (omarchy style.background): pick an image from the
# active theme's background set (~/Wallpapers/themes/<theme>/) or any loose
# file in ~/Wallpapers, then paint it with awww/swww. Session-scoped; the
# declarative theme default (theme.nix) repaints on next login.
theme=$(jq -r '.theme' "$OMARCHY_REPO/modules/omarchy/theme.json")

list() {
  find "$HOME/Wallpapers" -maxdepth 1 -type f \
       \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) 2>/dev/null
  find "$HOME/Wallpapers/themes/$theme" -maxdepth 1 \( -type f -o -type l \) \
       \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) 2>/dev/null
}

mapfile -t files < <(list | sort -u)
if [ "${#files[@]}" -eq 0 ]; then
  notify-send -a Omarchy "No wallpapers" "Put images in ~/Wallpapers or switch themes"
  exit 0
fi

declare -A by_label
labels=()
for f in "${files[@]}"; do
  case "$f" in
    "$HOME/Wallpapers/themes/"*) label="󰸌  $(basename "$f")" ;;
    *) label="  $(basename "$f")" ;;
  esac
  by_label["$label"]="$f"
  labels+=("$label")
done

choice=$(printf '%s\n' "${labels[@]}" | rofi -dmenu -i -p "Background") || exit 0
[ -z "$choice" ] && exit 0

if command -v awww >/dev/null; then
  awww img "${by_label[$choice]}"
else
  swww img "${by_label[$choice]}"
fi
