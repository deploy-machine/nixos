# Run a command in a floating kitty window (Hyprland rules float the
# Omarchy-float class) and keep the window open until a key is pressed, so
# rebuild output / errors stay readable. Omarchy's
# omarchy-launch-floating-terminal-with-presentation, minus the branding.
# shellcheck disable=SC2016  # the inner script must expand at runtime
exec kitty --class=Omarchy-float --title=Omarchy -e bash -c '
  "$@"
  status=$?
  echo
  if [ "$status" -ne 0 ]; then
    echo "── Command exited with status $status ──"
  fi
  read -n1 -s -r -p "── Press any key to close ──"
' bash "$@"
