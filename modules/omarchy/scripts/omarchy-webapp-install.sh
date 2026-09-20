# Install a chromium --app web app (the pattern the tuta-mail wrapper
# proved out): prompt for name + URL via rofi, grab a favicon, write a
# .desktop entry. Web apps are imperative user data (like omarchy), so they
# live in ~/.local/share/applications, not the flake.
apps_dir="$HOME/.local/share/applications"
icon_dir="$apps_dir/icons"
mkdir -p "$icon_dir"

name=$(rofi -dmenu -p "Web app name" -l 0 </dev/null) || exit 0
[ -z "$name" ] && exit 0
url=$(rofi -dmenu -p "URL" -l 0 </dev/null) || exit 0
[ -z "$url" ] && exit 0
case "$url" in
  http://*|https://*) ;;
  *) url="https://$url" ;;
esac

app_id=$(echo "$name" | tr '[:upper:] ' '[:lower:]-' | tr -cd '[:alnum:]-')
desktop_file="$apps_dir/omarchy-webapp-$app_id.desktop"
icon_file="$icon_dir/$app_id.png"

domain=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|')
curl -sfL --max-time 10 "https://www.google.com/s2/favicons?domain=$domain&sz=128" -o "$icon_file" || icon_file="web-browser"

cat >"$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Name=$name
Comment=$name (chromium web app)
Exec=omarchy-launch-webapp "$url" --class="$app_id" --name="$app_id"
Terminal=false
Type=Application
Icon=$icon_file
StartupNotify=true
StartupWMClass=$app_id
X-Omarchy-Webapp=true
EOF

notify-send -a Omarchy "Web app installed" "$name → $url"
