# Screen zoom via Hyprland's cursor:zoom_factor (omarchy SUPER+CTRL+Z).
case "${1-in}" in
in)
  cur=$(hyprctl getoption cursor:zoom_factor -j | jq -r '.float')
  hyprctl keyword cursor:zoom_factor "$(echo "$cur + 1" | bc)" >/dev/null
  ;;
reset)
  hyprctl keyword cursor:zoom_factor 1 >/dev/null
  ;;
*)
  echo "Usage: omarchy-zoom <in|reset>" >&2
  exit 1
  ;;
esac
