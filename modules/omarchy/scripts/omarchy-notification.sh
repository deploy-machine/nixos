# Notification helpers on swaync — the omarchy-notification-* set.
case "${1-}" in
dismiss)
  swaync-client --close-latest
  ;;
dismiss-all)
  swaync-client -C
  ;;
panel)
  swaync-client -t -sw
  ;;
time)
  notify-send -a Omarchy -e -t 4000 "  $(date +%H:%M)" "$(date '+%A, %d %B %Y')"
  ;;
battery)
  found=false
  for bat in /sys/class/power_supply/BAT* /sys/class/power_supply/macsmc-battery; do
    [ -e "$bat/capacity" ] || continue
    found=true
    cap=$(cat "$bat/capacity")
    status=$(cat "$bat/status" 2>/dev/null || echo Unknown)
    notify-send -a Omarchy -e -t 4000 "󰁹  Battery: $cap%" "$status"
  done
  if ! $found; then
    notify-send -a Omarchy -e -t 4000 "󰚥  No battery" "This machine runs on mains power"
  fi
  ;;
weather)
  report=$(curl -sf --max-time 10 'https://wttr.in/?format=3') ||
    report="Weather unavailable (no network?)"
  notify-send -a Omarchy -e -t 6000 "  Weather" "$report"
  ;;
*)
  echo "Usage: omarchy-notification <dismiss|dismiss-all|panel|time|battery|weather>" >&2
  exit 1
  ;;
esac
