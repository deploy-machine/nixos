# The Omarchy menu, recreated as a rofi -dmenu tree (themed by the
# existing milkoutside.rasi). Route argument jumps straight to a submenu:
#   omarchy-menu [root|system|trigger|capture|toggle|style|setup|install|remove|update|learn]
# Escape closes; "Back" walks up one level. Arch-specific omarchy actions
# are re-expressed as NixOS/flake operations throughout.

menu() {
  local prompt="$1"
  shift
  printf '%s\n' "$@" | rofi -dmenu -i -p "$prompt" || true
}

term() { omarchy-floating-term "$@"; }

edit_in_term() {
  kitty --class=Omarchy-float --title=Omarchy --directory "$OMARCHY_REPO" -e "${EDITOR:-nvim}" "$@" &
}

main_menu() {
  case $(menu "Omarchy" \
    "󰀻  Apps" \
    "󱓞  Trigger" \
    "  Style" \
    "  Setup" \
    "󰉉  Install" \
    "󰭌  Remove" \
    "  Update" \
    "󰧑  Learn" \
    "  About" \
    "  System") in
  *Apps*) rofi -show drun -show-icons ;;
  *Trigger*) trigger_menu ;;
  *Style*) style_menu ;;
  *Setup*) setup_menu ;;
  *Install*) install_menu ;;
  *Remove*) remove_menu ;;
  *Update*) update_menu ;;
  *Learn*) learn_menu ;;
  *About*) term fastfetch ;;
  *System*) system_menu ;;
  esac
}

trigger_menu() {
  case $(menu "Trigger" \
    "  Capture" \
    "󰔎  Toggle" \
    "󰅍  Clipboard history" \
    "  Emoji picker" \
    "󰁍  Back") in
  *Capture*) capture_menu ;;
  *Toggle*) toggle_menu ;;
  *Clipboard*) sh -c 'cliphist list | rofi -dmenu -p "Clipboard" | cliphist decode | wl-copy' ;;
  *Emoji*) rofimoji --action copy ;;
  *Back*) main_menu ;;
  esac
}

capture_menu() {
  case $(menu "Capture" \
    "  Screenshot region" \
    "  Screenshot window" \
    "  Screenshot screen" \
    "  Screenrecord (toggle)" \
    "󰴑  Text (OCR)" \
    "󰐲  QR code" \
    "󰃉  Color picker" \
    "󰁍  Back") in
  *region*) omarchy-capture screenshot region ;;
  *window*) omarchy-capture screenshot window ;;
  *screen*) omarchy-capture screenshot output ;;
  *Screenrecord*) omarchy-capture record ;;
  *OCR*) omarchy-capture ocr ;;
  *QR*) omarchy-capture qr ;;
  *Color*) omarchy-capture color ;;
  *Back*) trigger_menu ;;
  esac
}

toggle_menu() {
  local idle="󰅶  Stay awake"
  systemctl --user is-active --quiet hypridle.service || idle="󰅶  Stay awake ✓"
  local night="󰔎  Nightlight"
  systemctl --user is-active --quiet hyprsunset.service && night="󰔎  Nightlight ✓"
  local silence="󰂛  Silence notifications"
  [ "$(swaync-client -D)" = "true" ] && silence="󰂛  Silence notifications ✓"

  case $(menu "Toggle" \
    "$idle" \
    "$night" \
    "$silence" \
    "󰍜  Bar" \
    "  Window gaps" \
    "󰂵  Window transparency" \
    "󱂬  Workspace layout" \
    "󰁍  Back") in
  *awake*) omarchy-toggle idle ;;
  *Nightlight*) omarchy-toggle nightlight ;;
  *Silence*) omarchy-toggle silence ;;
  *Bar*) omarchy-toggle bar ;;
  *gaps*) omarchy-toggle gaps ;;
  *transparency*) omarchy-toggle transparency ;;
  *layout*) omarchy-toggle layout ;;
  *Back*) trigger_menu ;;
  esac
}

style_menu() {
  # Theme itself is off-limits by design (greyscale rice is declarative);
  # this only covers what omarchy calls style.background / config editing.
  case $(menu "Style" \
    "  Background" \
    "  Edit palette (colors.nix)" \
    "  Edit Hyprland look" \
    "󰁍  Back") in
  *Background*) omarchy-wallpaper ;;
  *palette*) edit_in_term modules/home/colors.nix ;;
  *Hyprland*) edit_in_term modules/home/hyprland.nix ;;
  *Back*) main_menu ;;
  esac
}

setup_menu() {
  case $(menu "Setup" \
    "󰤨  Wi-Fi" \
    "󰂯  Bluetooth" \
    "  Audio" \
    "󰍹  Monitors (repo module)" \
    "  Keybindings (hyprland.nix)" \
    "  Config repo (editor)" \
    "󰊢  Config repo (lazygit)" \
    "󰁍  Back") in
  *Wi-Fi*) networkmanager_dmenu ;;
  *Bluetooth*) blueman-manager & ;;
  *Audio*) pavucontrol & ;;
  *Monitors*) edit_in_term modules/roles/multi-monitor.nix ;;
  *Keybindings*) edit_in_term modules/home/hyprland.nix ;;
  *editor*) edit_in_term . ;;
  *lazygit*) kitty --class=Omarchy-float --directory "$OMARCHY_REPO" -e lazygit & ;;
  *Back*) main_menu ;;
  esac
}

install_menu() {
  case $(menu "Install" \
    "󰏖  Package (nixpkgs → flake)" \
    "  Web App" \
    "  TUI" \
    "󰵮  Development environment" \
    "  Docker database" \
    "󰁍  Back") in
  *Package*) term omarchy-pkg-install ;;
  *Web*) omarchy-webapp-install ;;
  *TUI*) omarchy-tui-install ;;
  *Development*) dev_menu ;;
  *database*) db_menu ;;
  *Back*) main_menu ;;
  esac
}

dev_menu() {
  local choice
  choice=$(menu "New project" \
    "󰫏  Ruby on Rails" \
    "  Node.js" \
    "  Bun" \
    "  Deno" \
    "  Go" \
    "  PHP" \
    "  Laravel" \
    "  Symfony" \
    "  Python" \
    "  Elixir" \
    "  Phoenix" \
    "  Rust" \
    "  Java" \
    "  Zig" \
    "  OCaml" \
    "  .NET" \
    "  Clojure" \
    "  Scala" \
    "󰁍  Back")
  case "$choice" in
  *Ruby*) term omarchy-dev-env ruby ;;
  *Node*) term omarchy-dev-env node ;;
  *Bun*) term omarchy-dev-env bun ;;
  *Deno*) term omarchy-dev-env deno ;;
  *Go*) term omarchy-dev-env go ;;
  *Laravel*) term omarchy-dev-env laravel ;;
  *Symfony*) term omarchy-dev-env symfony ;;
  *PHP*) term omarchy-dev-env php ;;
  *Python*) term omarchy-dev-env python ;;
  *Phoenix*) term omarchy-dev-env phoenix ;;
  *Elixir*) term omarchy-dev-env elixir ;;
  *Rust*) term omarchy-dev-env rust ;;
  *Java*) term omarchy-dev-env java ;;
  *Zig*) term omarchy-dev-env zig ;;
  *OCaml*) term omarchy-dev-env ocaml ;;
  *.NET*) term omarchy-dev-env dotnet ;;
  *Clojure*) term omarchy-dev-env clojure ;;
  *Scala*) term omarchy-dev-env scala ;;
  *Back*) install_menu ;;
  esac
}

db_menu() {
  local dbs_json="$OMARCHY_REPO/modules/omarchy/dbs.json"
  mark() {
    if jq -e --arg d "$1" '.enabled | index($d)' "$dbs_json" >/dev/null; then
      echo " ✓"
    fi
  }
  local mssql_label
  mssql_label="  MSSQL$(mark mssql)"
  [ "$(uname -m)" != "x86_64" ] && mssql_label="  MSSQL (x86 only)"

  case $(menu "Docker DB (toggle)" \
    "  PostgreSQL$(mark postgres)" \
    "  MySQL$(mark mysql)" \
    "  MariaDB$(mark mariadb)" \
    "  Redis$(mark redis)" \
    "  MongoDB$(mark mongodb)" \
    "$mssql_label" \
    "󰁍  Back") in
  *PostgreSQL*) term omarchy-docker-db toggle postgres ;;
  *MySQL*) term omarchy-docker-db toggle mysql ;;
  *MariaDB*) term omarchy-docker-db toggle mariadb ;;
  *Redis*) term omarchy-docker-db toggle redis ;;
  *MongoDB*) term omarchy-docker-db toggle mongodb ;;
  *MSSQL*) term omarchy-docker-db toggle mssql ;;
  *Back*) install_menu ;;
  esac
}

remove_menu() {
  case $(menu "Remove" \
    "󰏖  Package" \
    "  Web App" \
    "  TUI" \
    "  Docker database" \
    "󰁍  Back") in
  *Package*) term omarchy-pkg-remove ;;
  *Web*) omarchy-webapp-remove ;;
  *TUI*) omarchy-tui-remove ;;
  *database*) db_menu ;;
  *Back*) main_menu ;;
  esac
}

update_menu() {
  case $(menu "Update" \
    "  Rebuild system (apply config)" \
    "󰚰  Bump flake inputs + rebuild" \
    "󰕌  Rollback to previous generation" \
    "󰃢  Garbage collect" \
    "󰁍  Back") in
  *Rebuild*) term omarchy-update system ;;
  *Bump*) term omarchy-update inputs ;;
  *Rollback*) term omarchy-update rollback ;;
  *Garbage*) term omarchy-update clean ;;
  *Back*) main_menu ;;
  esac
}

learn_menu() {
  case $(menu "Learn" \
    "  Keybindings" \
    "  NixOS manual" \
    "󰏖  Nixpkgs search" \
    "  Home Manager options" \
    "  Hyprland wiki" \
    "󰁍  Back") in
  *Keybindings*) omarchy-menu-keybindings ;;
  *manual*) omarchy-launch-webapp "https://nixos.org/manual/nixos/stable/" ;;
  *Nixpkgs*) omarchy-launch-webapp "https://search.nixos.org/packages" ;;
  *Home*) omarchy-launch-webapp "https://home-manager-options.extranix.com/" ;;
  *Hyprland*) omarchy-launch-webapp "https://wiki.hypr.land/" ;;
  *Back*) main_menu ;;
  esac
}

system_menu() {
  case $(menu "System" \
    "  Lock" \
    "󰒲  Suspend" \
    "󰍃  Logout" \
    "󰑓  Restart Hyprland" \
    "󰜉  Reboot" \
    "󰐥  Shutdown") in
  *Lock*) hyprlock & ;;
  *Suspend*) systemctl suspend ;;
  *Logout*) hyprctl dispatch exit ;;
  *Restart\ Hyprland*) hyprctl reload ;;
  *Reboot*) systemctl reboot ;;
  *Shutdown*) systemctl poweroff ;;
  esac
}

case "${1-root}" in
root) main_menu ;;
system) system_menu ;;
trigger) trigger_menu ;;
capture) capture_menu ;;
toggle) toggle_menu ;;
style) style_menu ;;
setup) setup_menu ;;
install) install_menu ;;
remove) remove_menu ;;
update) update_menu ;;
learn) learn_menu ;;
*) main_menu ;;
esac
