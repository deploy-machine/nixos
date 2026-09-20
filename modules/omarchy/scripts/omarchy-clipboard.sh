# Universal copy/paste/cut (omarchy's SUPER+C/V/X): sends the right
# shortcut for the focused window — kitty wants CTRL+SHIFT+C/V, everything
# else CTRL+C/V/X. Uses Hyprland's sendshortcut so it works in both the
# .conf (0.52) and .lua (0.55) configs.
op="${1-}"
class=$(hyprctl activewindow -j | jq -r '.class // ""')

is_terminal=false
case "$class" in
  kitty|Omarchy-float) is_terminal=true ;;
esac

case "$op" in
copy)
  if $is_terminal; then hyprctl dispatch sendshortcut "CTRL SHIFT,C,"; else hyprctl dispatch sendshortcut "CTRL,C,"; fi
  ;;
paste)
  if $is_terminal; then hyprctl dispatch sendshortcut "CTRL SHIFT,V,"; else hyprctl dispatch sendshortcut "CTRL,V,"; fi
  ;;
cut)
  hyprctl dispatch sendshortcut "CTRL,X,"
  ;;
*)
  echo "Usage: omarchy-clipboard <copy|paste|cut>" >&2
  exit 1
  ;;
esac
