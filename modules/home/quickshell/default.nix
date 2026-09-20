# Quickshell top bar — replaces waybar (modules/home/waybar.nix is kept in
# the tree but no longer imported). Same information layout as the old bar
# (workspaces, clocks, window title, metrics, network, audio, notifications,
# tray) plus omarchy-style popups: calendar, audio mixer, power menu.
#
# Static QML lives next to this file; Theme.qml is generated so the palette
# always tracks the active theme (modules/omarchy/theme.nix) and the
# workspace-click dispatch matches the Hyprland dialect per arch.
{ config, lib, pkgs, ... }:
let
  c = import ../colors.nix;
  isAsahi = pkgs.stdenv.hostPlatform.isAarch64;

  # Hyprland 0.55 (x86) evaluates dispatch args as Lua; 0.52 (Asahi) wants
  # the classic dispatcher. Same split the waybar config carried.
  focusDispatch =
    if isAsahi
    then ''Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(id)]);''
    else ''Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + id + "\" })"]);'';

  themeQml = ''
    pragma Singleton
    import QtQuick
    import Quickshell

    QtObject {
        // Generated from modules/omarchy/theme.nix — do not edit here.
        readonly property color bg:        "#${c.bg}"
        readonly property color bgAlt:     "#${c.bgAlt}"
        readonly property color surface:   "#${c.surface}"
        readonly property color selection: "#${c.selection}"
        readonly property color border:    "#${c.border}"
        readonly property color muted:     "#${c.muted}"
        readonly property color dim:       "#${c.dim}"
        readonly property color fgDim:     "#${c.fgDim}"
        readonly property color fg:        "#${c.fg}"
        readonly property color fgBright:  "#${c.fgBright}"

        readonly property string fontFamily: "GeistMono Nerd Font"
        readonly property int fontSize: 13
        readonly property int barHeight: 30

        function focusWorkspace(id) {
            ${focusDispatch}
        }
    }
  '';

  # cpu% mem% tempC every 2s, for the metrics pill.
  metricsScript = pkgs.writeShellApplication {
    name = "qs-bar-metrics";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk ];
    text = ''
      prev_total=0
      prev_idle=0
      while :; do
        read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
        idle_all=$((idle + iowait))
        total=$((user + nice + system + idle + iowait + irq + softirq + steal))
        d_total=$((total - prev_total))
        d_idle=$((idle_all - prev_idle))
        cpu=0
        [ "$d_total" -gt 0 ] && cpu=$(((100 * (d_total - d_idle)) / d_total))
        prev_total=$total
        prev_idle=$idle_all

        mem=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {if (t > 0) printf "%d", (t-a)*100/t; else print 0}' /proc/meminfo)

        temp=0
        for z in /sys/class/thermal/thermal_zone*/temp; do
          [ -r "$z" ] || continue
          v=$(cat "$z" 2>/dev/null || echo 0)
          v=$((v / 1000))
          [ "$v" -gt "$temp" ] && temp=$v
        done

        echo "$cpu $mem $temp"
        sleep 2
      done
    '';
  };

  # wifi | eth | off every 5s, for the network pill.
  networkScript = pkgs.writeShellApplication {
    name = "qs-network-status";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      while :; do
        state=off
        while IFS=: read -r type st; do
          case "$type:$st" in
            wifi:connected) state=wifi ;;
            ethernet:connected) [ "$state" = wifi ] || state=eth ;;
            *) ;;
          esac
        done < <(nmcli -t -f TYPE,STATE device 2>/dev/null || true)
        echo "$state"
        sleep 5
      done
    '';
  };
in
{
  home.packages = [
    pkgs.quickshell
    metricsScript
    networkScript
    pkgs.pavucontrol            # audio popup's "open mixer"
    pkgs.networkmanagerapplet   # nm-connection-editor, reachable from networkmanager_dmenu
    pkgs.networkmanager_dmenu   # rofi AP picker (network pill on-click)
  ];

  # Rofi-based wifi picker (network pill on-click). Uses the session rofi
  # theme; passphrase entry runs obscured via rofi's -password mode.
  xdg.configFile."networkmanager-dmenu/config.ini".text = ''
    [dmenu]
    dmenu_command = rofi -dmenu -i
    rofi_highlight = True
    compact = True
    wifi_chars = ▂▄▆█

    [dmenu_passphrase]
    obscure = True
  '';

  xdg.configFile."quickshell/shell.qml".source = ./shell.qml;
  xdg.configFile."quickshell/Bar.qml".source = ./Bar.qml;
  xdg.configFile."quickshell/qmldir".source = ./qmldir;
  xdg.configFile."quickshell/Theme.qml".text = themeQml;

  # Run as part of the graphical session, like waybar before it.
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell bar (koda greyscale)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/qs";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
