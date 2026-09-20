# Capture actions, omarchy-capture-* consolidated.
#   screenshot [region|window|output]  hyprshot → satty pipeline (screenshot script)
#   record                             wf-recorder toggle → ~/Videos
#   ocr                                region → tesseract → clipboard
#   qr                                 region → zbarimg → clipboard
#   color                              hyprpicker → clipboard
what="${1-screenshot}"
mode="${2-region}"

case "$what" in
screenshot)
  exec screenshot "$mode"
  ;;
record)
  if pgrep -x wf-recorder >/dev/null; then
    pkill -SIGINT -x wf-recorder
    notify-send -a Omarchy -e "  Recording stopped" "Saved to ~/Videos"
  else
    mkdir -p "$HOME/Videos"
    out="$HOME/Videos/$(date +%F-%H%M%S).mp4"
    notify-send -a Omarchy -e -t 2000 "  Recording started" "Run again to stop"
    exec wf-recorder -f "$out"
  fi
  ;;
ocr)
  text=$(grim -g "$(slurp)" - | tesseract stdin stdout 2>/dev/null) || {
    notify-send -a Omarchy -e "OCR failed" "No text recognized"
    exit 1
  }
  printf '%s' "$text" | wl-copy
  notify-send -a Omarchy -e "󰴑  Text captured" "$(printf '%s' "$text" | head -c 200)"
  ;;
qr)
  tmp=$(mktemp --suffix=.png)
  trap 'rm -f "$tmp"' EXIT
  grim -g "$(slurp)" "$tmp"
  data=$(zbarimg --quiet --raw "$tmp") || {
    notify-send -a Omarchy -e "󰐲  No QR code found"
    exit 1
  }
  printf '%s' "$data" | wl-copy
  notify-send -a Omarchy -e "󰐲  QR captured" "$data"
  ;;
color)
  pkill -x hyprpicker 2>/dev/null || exec hyprpicker -a
  ;;
*)
  echo "Usage: omarchy-capture <screenshot [region|window|output]|record|ocr|qr|color>" >&2
  exit 1
  ;;
esac
