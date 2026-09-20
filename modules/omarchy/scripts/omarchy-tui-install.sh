# Register a terminal app as a desktop entry (launches in kitty), like
# omarchy-tui-install. The command itself should already be installed —
# use Install > Package for that.
apps_dir="$HOME/.local/share/applications"
mkdir -p "$apps_dir"

name=$(rofi -dmenu -p "TUI name" -l 0 </dev/null) || exit 0
[ -z "$name" ] && exit 0
cmd=$(rofi -dmenu -p "Command" -l 0 </dev/null) || exit 0
[ -z "$cmd" ] && exit 0

app_id=$(echo "$name" | tr '[:upper:] ' '[:lower:]-' | tr -cd '[:alnum:]-')
cat >"$apps_dir/omarchy-tui-$app_id.desktop" <<EOF
[Desktop Entry]
Version=1.0
Name=$name
Comment=$name (terminal app)
Exec=kitty --class="$app_id" -e $cmd
Terminal=false
Type=Application
Icon=utilities-terminal
StartupNotify=true
StartupWMClass=$app_id
X-Omarchy-TUI=true
EOF

notify-send -a Omarchy "TUI installed" "$name → $cmd"
