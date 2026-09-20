# Searchable keybinding cheatsheet (omarchy-menu-keybindings): reads the
# live binds from hyprctl so it's always in sync with whichever config
# dialect (.conf or .lua) this machine runs.
hyprctl binds -j | jq -r '
  def mods:
    (if .modmask % 128 >= 64 then "SUPER+" else "" end) +
    (if .modmask % 16  >= 8  then "ALT+"   else "" end) +
    (if .modmask % 8   >= 4  then "CTRL+"  else "" end) +
    (if .modmask % 2   >= 1  then "SHIFT+" else "" end);
  .[]
  | select(.key != "")
  | (mods + .key) as $combo
  | ($combo + "\t" + (if .description != "" then .description else (.dispatcher + " " + .arg) end))
' | sort -u | column -t -s $'\t' | rofi -dmenu -i -p "Keybindings" >/dev/null || true
