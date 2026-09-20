# Remove a web app installed by omarchy-webapp-install.
apps_dir="$HOME/.local/share/applications"

mapfile -t files < <(grep -l '^X-Omarchy-Webapp=true' "$apps_dir"/*.desktop 2>/dev/null || true)
if [ "${#files[@]}" -eq 0 ]; then
  notify-send -a Omarchy "No web apps" "Nothing installed via the menu."
  exit 0
fi

declare -A by_name
names=()
for f in "${files[@]}"; do
  n=$(sed -n 's/^Name=//p' "$f" | head -1)
  by_name["$n"]="$f"
  names+=("$n")
done

choice=$(printf '%s\n' "${names[@]}" | rofi -dmenu -i -p "Remove web app") || exit 0
[ -z "$choice" ] && exit 0

file="${by_name[$choice]}"
icon=$(sed -n 's/^Icon=//p' "$file" | head -1)
rm -f "$file"
[ -f "$icon" ] && rm -f "$icon"
notify-send -a Omarchy "Web app removed" "$choice"
