# Take a screenshot (omarchy-capture-screenshot, NixOS edition). Upstream
# drives omasnap, which isn't packaged for NixOS; this keeps the same
# arguments on hyprshot + satty: capture, annotate/crop, save to
# ~/Pictures (or $OMARCHY_SCREENSHOT_DIR) and copy to the clipboard.
#   omarchy-capture-screenshot [smart|region|windows|fullscreen|scroll] [copy|save]
mode=region
output=both
for arg in "$@"; do
  case "$arg" in
    smart | region | scroll) mode=region ;;
    windows | window) mode=window ;;
    fullscreen | output) mode=output ;;
    copy) output=copy ;;
    save) output=save ;;
  esac
done

if [ "$output" = copy ]; then
  exec hyprshot -m "$mode" --clipboard-only --silent
fi

dir="${OMARCHY_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"
mkdir -p "$dir"
out="$dir/screenshot_$(date +%Y%m%d_%H%M%S).png"

hyprshot -m "$mode" --raw | satty \
  --filename - \
  --output-filename "$out" \
  --copy-command wl-copy \
  --early-exit \
  --actions-on-enter save-to-clipboard

[ -f "$out" ] || exit 0
omarchy-notification-send -g "$(printf '\uf030')" "Screenshot saved" "$out" --exec xdg-open "$out"
