# Session toggles, omarchy-toggle-* consolidated. State comes from the
# running services / hyprctl, so these survive without a state directory.
what="${1-}"

notify() { notify-send -a Omarchy -e -t 2500 "$1" "${2-}"; }

case "$what" in
idle)
  # "Stay awake": stop hypridle so the screen never locks/suspends.
  if systemctl --user is-active --quiet hypridle.service; then
    systemctl --user stop hypridle.service
    notify "󰅶  Staying awake" "Idle locking and suspend disabled"
  else
    systemctl --user start hypridle.service
    notify "󰒲  Idle handling on" "Lock 10m · screen off 11m · suspend 30m"
  fi
  ;;
nightlight)
  if systemctl --user is-active --quiet hyprsunset.service; then
    systemctl --user stop hyprsunset.service
    notify "󰖨  Nightlight off"
  else
    systemctl --user start hyprsunset.service
    notify "󰔎  Nightlight on" "4500K"
  fi
  ;;
bar)
  pkill -SIGUSR1 waybar || true
  ;;
silence)
  state=$(swaync-client -d)
  if [ "$state" = "true" ]; then
    notify "󰂛  Notifications silenced"
  else
    notify "󰂚  Notifications on"
  fi
  ;;
gaps)
  cur=$(hyprctl getoption general:gaps_out -j | jq -r '.custom' | awk '{print $1}')
  if [ "$cur" = "0" ]; then
    hyprctl --batch "keyword general:gaps_out 20 ; keyword general:gaps_in 5" >/dev/null
  else
    hyprctl --batch "keyword general:gaps_out 0 ; keyword general:gaps_in 0" >/dev/null
  fi
  ;;
transparency)
  cur=$(hyprctl getoption decoration:inactive_opacity -j | jq -r '.float')
  if [ "$cur" = "1.000000" ] || [ "$cur" = "1" ]; then
    hyprctl --batch "keyword decoration:active_opacity 1.0 ; keyword decoration:inactive_opacity 0.95" >/dev/null
  else
    hyprctl --batch "keyword decoration:active_opacity 1.0 ; keyword decoration:inactive_opacity 1.0" >/dev/null
  fi
  ;;
layout)
  cur=$(hyprctl getoption general:layout -j | jq -r '.str')
  if [ "$cur" = "dwindle" ]; then
    hyprctl keyword general:layout master >/dev/null
    notify "󱂬  Layout: master"
  else
    hyprctl keyword general:layout dwindle >/dev/null
    notify "󱂬  Layout: dwindle"
  fi
  ;;
*)
  echo "Usage: omarchy-toggle <idle|nightlight|bar|silence|gaps|transparency|layout>" >&2
  exit 1
  ;;
esac
