# Background switcher (omarchy style.background): pick an image from the
# active theme's background set (~/.config/omarchy/current/theme/
# backgrounds) or any loose file in ~/Wallpapers, then paint it with
# awww/swww. Session-scoped; the theme default repaints on next login.

list() {
  find "$HOME/Wallpapers" -maxdepth 1 -type f \
       \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) 2>/dev/null
  find -L "$HOME/.config/omarchy/current/theme/backgrounds" -maxdepth 1 -type f \
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
    "$HOME/.config/omarchy/"*) label="󰸌  $(basename "$f")" ;;
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
