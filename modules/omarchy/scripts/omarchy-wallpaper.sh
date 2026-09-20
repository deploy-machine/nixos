# Background switcher (omarchy style.background): pick any image from
# ~/Wallpapers and paint it with awww/swww. The choice lasts for this
# session; the declarative default in hyprland.nix repaints on next login.
dir="$HOME/Wallpapers"
if ! find "$dir" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | grep -q .; then
  notify-send -a Omarchy "No wallpapers" "Put images in ~/Wallpapers"
  exit 0
fi

choice=$(find "$dir" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) -printf '%f\n' |
  sort | rofi -dmenu -i -p "Background") || exit 0
[ -z "$choice" ] && exit 0

if command -v awww >/dev/null; then
  awww img "$dir/$choice"
else
  swww img "$dir/$choice"
fi
