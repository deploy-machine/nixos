# Remove a TUI desktop entry installed by omarchy-tui-install.
apps_dir="$HOME/.local/share/applications"

mapfile -t files < <(grep -l '^X-Omarchy-TUI=true' "$apps_dir"/*.desktop 2>/dev/null || true)
if [ "${#files[@]}" -eq 0 ]; then
  notify-send -a Omarchy "No TUIs" "Nothing installed via the menu."
  exit 0
fi

declare -A by_name
names=()
for f in "${files[@]}"; do
  n=$(sed -n 's/^Name=//p' "$f" | head -1)
  by_name["$n"]="$f"
  names+=("$n")
done

choice=$(printf '%s\n' "${names[@]}" | rofi -dmenu -i -p "Remove TUI") || exit 0
[ -z "$choice" ] && exit 0
rm -f "${by_name[$choice]}"
notify-send -a Omarchy "TUI removed" "$choice"
