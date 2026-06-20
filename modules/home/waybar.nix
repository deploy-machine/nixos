# /etc/nixos/waybar.nix
# cybrcore "lucid" powerline bar, recoloured to milkoutside.
# Bypasses programs.waybar so Home Manager never writes a competing config:
# the raw config.jsonc + style.css are shipped verbatim and waybar runs as a
# user service. The powerline arrow separators are generated as SVGs in the nix
# store and referenced by absolute path from the CSS.
#
# NOTE: stylix.targets.waybar is disabled in home.nix so Stylix's generic base16
# bar CSS doesn't override this one.
{ config, pkgs, ... }:
let
  # 14x31 triangular powerline separators (shape copied from cybr-waybar/svg).
  mkArrow = name: fill: dir:
    pkgs.writeText "waybar-${name}.svg" (
      if dir == "left"
      then ''<svg width="14" height="31" viewBox="0 0 14 31" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M0 0H14V19L0 31V0Z" fill="${fill}"/></svg>''
      else ''<svg width="14" height="31" viewBox="0 0 14 31" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M14 0L0 0L0 17L14 31L14 0Z" fill="${fill}"/></svg>''
    );
  # milkoutside: no1 = panel bg, re0 = red accent, gr0 = green accent
  no1L = mkArrow "no1-left"  "#0f0f15" "left";
  no1R = mkArrow "no1-right" "#0f0f15" "right";
  re0L = mkArrow "re0-left"  "#f93a82" "left";
  re0R = mkArrow "re0-right" "#f93a82" "right";
  gr0L = mkArrow "gr0-left"  "#92cf9c" "left";
  gr0R = mkArrow "gr0-right" "#92cf9c" "right";
in
{
  home.packages = with pkgs; [
    waybar
    pavucontrol            # pulseaudio module on-click
    networkmanagerapplet   # provides nm-connection-editor for network on-click
  ];

  xdg.configFile."waybar/config.jsonc".text = ''
[
  {
    "layer": "top",
    "position": "top",
    "height": 31,
    "mode": "dock",
    "exclusive": true,
    "gtk-layer-shell": true,
    "margin-top": 0,
    "margin-bottom": 0,
    "margin-left": 0,
    "margin-right": 0,
    "on-scroll-threshold": 1,
    "modules-left": [
      "custom/nixos",
      "custom/arrow-left-re0",
      "hyprland/workspaces",
      "custom/arrow-left-no1"
    ],
    "modules-center": [
      "custom/arrow-right-no1",
      "clock#date",
      "custom/arrow-right-re0",
      "hyprland/window",
      "custom/arrow-left-re0",
      "clock#time",
      "custom/arrow-left-no1"
    ],
    "modules-right": [
      "custom/arrow-right-no1",
      "cpu",
      "memory",
      "temperature",
      "network",
      "pulseaudio",
      "custom/notifications",
      "tray"
    ],
    "custom/arrow-left-no1": {
      "format": "  ",
      "tooltip": false
    },
    "custom/arrow-right-no1": {
      "format": "  ",
      "tooltip": false
    },
    "custom/arrow-left-re0": {
      "format": "  ",
      "tooltip": false
    },
    "custom/arrow-right-re0": {
      "format": "  ",
      "tooltip": false
    },
    "custom/nixos": {
      "format": "    ",
      "tooltip": false,
      "on-click": "rofi -show drun",
      "on-click-right": "rofi -show run"
    },
    "hyprland/workspaces": {
      "disable-scroll": true,
      "active-only": false,
      "all-outputs": true,
      "enable-bar-scroll": true,
      "format": "{id}",
      "on-scroll-up": "hyprctl dispatch workspace r-1",
      "on-scroll-down": "hyprctl dispatch workspace r+1",
      "on-click": "activate",
      "sort-by-number": true
    },
    "hyprland/window": {
      "format": "{}",
      "max-length": 60,
      "rewrite": {
        "(.*) - Brave": "$1 󰖟",
        "(.*) - Chromium": "$1 󰊯",
        "(.*) — Neovim": "$1 ",
        "(.*) - kitty": "$1 "
      },
      "separate-outputs": false
    },
    "clock#date": {
      "format": "{:%Y/%m/%d}",
      "tooltip-format": "<tt><small>{calendar}</small></tt>",
      "calendar": {
        "mode": "month",
        "mode-mon-col": 3,
        "weeks-pos": "left",
        "on-scroll": 1,
        "on-click-right": "mode"
      }
    },
    "clock#time": {
      "format": "{:%H.%M:%OS}",
      "interval": 1,
      "tooltip-format": "<tt><small>{calendar}</small></tt>",
      "calendar": {
        "mode": "month",
        "mode-mon-col": 3,
        "weeks-pos": "left",
        "on-scroll": 1,
        "on-click-right": "mode"
      }
    },
    "cpu": {
      "on-click": "kitty -e btop",
      "format": " {usage}%",
      "tooltip-format": "CPU",
      "interval": 2
    },
    "memory": {
      "format": " {}%",
      "on-click": "kitty -e btop",
      "tooltip-format": "RAM",
      "interval": 2
    },
    "temperature": {
      "critical-threshold": 90,
      "format-critical": "{icon} {temperatureC}°C",
      "format": "{icon} {temperatureC}°C",
      "format-icons": [
        "",
        "",
        "󰈸"
      ],
      "tooltip-format": "CPU",
      "interval": 2
    },
    "network": {
      "format-wifi": "",
      "format-ethernet": "",
      "on-click": "nm-connection-editor",
      "tooltip-format-wifi": "Network: <b>{essid}</b>\nSignal strength: <b>{signaldBm}dBm ({signalStrength}%)</b>\nFrequency: <b>{frequency}MHz</b>\nInterface: <b>{ifname}</b>\nIP: <b>{ipaddr}/{cidr}</b>\nGateway: <b>{gwaddr}</b>\nNetmask: <b>{netmask}</b>\n<span foreground='#eed49f'> {bandwidthDownBytes}</span> <span foreground='#b7bdf8'> {bandwidthUpBytes}</span>",
      "tooltip-format-ethernet": "Network: <b>{essid}</b>\nInterface: <b>{ifname}</b>\nIP: <b>{ipaddr}/{cidr}</b>\nGateway: <b>{gwaddr}</b>\nNetmask: <b>{netmask}</b>\n<span foreground='#eed49f'> {bandwidthDownBytes}</span> <span foreground='#b7bdf8'> {bandwidthUpBytes}</span>",
      "format-linked": "󰈀 {ifname} (No IP)",
      "format-disconnected": "󰖪 ",
      "tooltip": true,
      "interval": 2
    },
    "pulseaudio": {
      "format": "  {volume}%",
      "format-muted": "  MUTE",
      "interval": 1,
      "tooltip-format": "{desc}, {volume}%",
      "on-click": "pavucontrol",
      "on-click-right": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
      "on-click-middle": "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
      "on-scroll-up": "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+",
      "on-scroll-down": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    },
    "custom/notifications": {
      "tooltip": false,
      "format": "{icon}",
      "format-icons": {
        "notification": "󰀧",
        "none": "󰀧",
        "dnd-notification": "󰳤",
        "dnd-none": "󰳤",
        "inhibited-notification": "<sup></sup>",
        "inhibited-none": "",
        "dnd-inhibited-notification": "<sup></sup>",
        "dnd-inhibited-none": ""
      },
      "return-type": "json",
      "exec-if": "which swaync-client",
      "exec": "swaync-client -swb",
      "on-click": "sleep 0.1 && swaync-client -t -sw",
      "on-click-right": "swaync-client -d -sw",
      "escape": true
    },
    "tray": {
      "icon-size": 16,
      "spacing": 10
    }
  }
]
  '';

  xdg.configFile."waybar/style.css".text = ''
/* 
# ---------------------------------------
# cybrcore    lucid theme for waybar
# Project:    https://github.com/cybrcore/cybr-waybar
# Author:     scherrer-txt   |   License:     GPL-3.0
# Source:     ~/.config/waybar/style.css
# ---------------------------------------
*/

/* === VARIABLES === */

@define-color no0 #040607;
@define-color no1 #0f0f15;
@define-color no2 #1a1e2e;

@define-color re0 #f93a82;
@define-color re1 #7a1d40;
@define-color re2 #2e0f1f;

@define-color gr0 #92cf9c;
@define-color gr1 #2f5a39;
@define-color gr2 #16271b;

@define-color ye0 #f8e063;
@define-color ye1 #635618;
@define-color ye2 #332D10;

@define-color bl0 #63c3dd;
@define-color bl1 #1f4f5c;
@define-color bl2 #0c2329;

@define-color vi0 #9d7cd8;
@define-color vi1 #3f2f5c;
@define-color vi2 #1f1733;

@define-color cy0 #7dcfff;
@define-color cy1 #2a5566;
@define-color cy2 #11242f;

@define-color wh0 #8a8a8a;
@define-color wh1 #393B42;
@define-color wh2 #1E2025;

@define-color me0 #4D5A80;
@define-color me1 #212638;
@define-color me2 #0D1120;

@define-color or0 #ffad00;
@define-color or1 #634300;
@define-color or2 #332300;

@define-color pi0 #e79cfb;
@define-color pi1 #5c3f63;
@define-color pi2 #2e1f33;


/* === GLOBAL === */

* {
	font-family: GeistMono Nerd Font;
	font-size: 15px;
	letter-spacing: -0.05em;
	font-weight: 400;
	min-height: 0;
}

window#waybar {
	background: transparent;
	opacity: 1;
}

window#waybar.hidden {
	opacity: 0;
}


/* === MODULE DEFAULTS === */

#custom-updates,
#custom-music,
#custom-nixos,
#workspaces,
#window {
	background-color: transparent;
	border: none;
	border-radius: 0;
	padding: 0 16px;
	color: @re0;
}


/* === BUTTON SIZE === */

#tray,
#custom-brightness,
#language,
#bluetooth,
#custom-gpu-usage,
#custom-wf-recorder,
#custom-updates,
#custom-notifications,
#pulseaudio,
#network,
#cpu,
#memory,
#temperature,
#temperature.cpu,
#temperature.gpu,
#battery,
#backlight {
	padding: 0 16px;
	min-width: 15px;
}


/* === POWERLINE ARROWS === */

#custom-arrow-left-no1 {
	background-image: url("${no1L}");
	background-position: left;
	background-repeat: no-repeat;
	background-size: contain;
}

#custom-arrow-right-no1 {
	background-image: url("${no1R}");
	background-position: right;
	background-repeat: no-repeat;
	background-size: contain;
}

#custom-arrow-left-re0 {
	background-image: url("${re0L}");
	background-position: left;
	background-repeat: no-repeat;
	background-size: contain;
	background-color: @no1;
}

#custom-arrow-right-re0 {
	background-image: url("${re0R}");
	background-position: right;
	background-repeat: no-repeat;
	background-size: contain;
	background-color: @no1;
}

#custom-arrow-left-gr0 {
	background-image: url("${gr0L}");
	background-position: left;
	background-repeat: no-repeat;
	background-size: contain;
	background-color: @no1;
}

#custom-arrow-right-gr0 {
	background-image: url("${gr0R}");
	background-position: right;
	background-repeat: no-repeat;
	background-size: contain;
	background-color: @no1;
}


/* === ARCH LOGO === */

#custom-nixos {
	color: @no0;
	background-color: @re0;
	font-weight: bold;
}

#custom-nixos:hover {
	color: @no0;
	background-color: @gr0;
}


/* === WORKSPACES === */

#workspaces {
	background-color: @no1;
	border: none;
}

#workspaces button {
	border-radius: 0;
	border: none;
	margin: 0;
	min-width: 30px;
	font-weight: bolder;
	color: @re0;
	background: transparent;
}

#workspaces button label {
	font-size: 15px;
	padding: 0 10px;
	color: @re0;
}

#workspaces button.active label {
	color: @gr0;
}

#workspaces button:hover {
	background-color: @re2;
}

#workspaces button:hover label {
	color: @re0;
}

#workspaces button.active:hover {
	background-color: @gr2;
}

#workspaces button.active label {
	color: @gr0;
}

#workspaces button.urgent {
	background-color: @ye0;
}

#workspaces button.urgent label {
	color: @ye2;
}

/* === CLOCKS === */

#clock.time,
#clock.date {
	color: @re0;
	background-color: @no1;
	padding: 0 32px;
}

#clock.time:hover,
#clock.date:hover {
	color: @re0;
	background-color: @re2;
}


/* === SYSTEM METRICS === */

#cpu,
#memory,
#temperature,
#temperature.cpu,
#temperature.gpu {
	color: @re0;
	background-color: @no1;
}

#temperature.critical {
	color: @no0;
	background-color: @ye0;
}

#cpu:hover,
#memory:hover,
#temperature:hover,
#temperature.cpu:hover,
#temperature.gpu:hover,
#temperature.critical:hover {
	color: @re0;
	background-color: @re2;
}


/* === NETWORK & AUDIO === */

#network {
	background-color: @no1;
	color: @re0;
}

#network.disconnected {
	color: @wh0;
	background-color: @or0;
}

#network.linked {
	color: @gr0;
	background-color: @no1;
}

#pulseaudio {
	color: @re0;
	background-color: @no1;
}

#pulseaudio.muted {
	color: @re1;
}

#network:hover,
#pulseaudio:hover {
	color: @re0;
	background-color: @re2;
}

#pulseaudio.muted:hover {
	color: @re1;
	background-color: @re2;
}


/* === MUSIC === */

#custom-music {
	background-color: @gr0;
	color: @no0;
	padding: 0 32px;
	border: none;
}


/* === NOTIFICATIONS === */

#custom-notifications {
	background-color: @no1;
	color: @re1;
	font-size: 20px;
}

#custom-notifications:hover {
	color: @re0;
	background-color: @re1;
}

#custom-notifications.dnd-none {
	color: @re1;
}

#custom-notifications.dnd-none:hover {
	color: @re1;
	background-color: @re2;
}

/* === UPDATES === */

#custom-updates {
	color: @wh0;
	font-size: 20px;
	margin: 0 20px;
}

#custom-updates:hover {
	background-color: @gr1;
}


/* === MISC === */

#custom-wf-recorder {
	color: @re0;
	background-color: @no1;
}

#bluetooth {
	color: @re0;
	background-color: @no1;
}

#language {
	color: @re0;
	background-color: @no1;
}

#custom-brightness {
	background-color: @no1;
}

#custom-brightness:hover {
	background-color: @re1;
}

#custom-brightness.max {
	color: @re0;
}

#custom-brightness.high {
	color: @ye0;
}

#custom-brightness.mid {
	color: @wh0;
}

#custom-brightness.low {
	color: @cy0;
}

#custom-brightness.min {
	color: @re0;
}

#tray {
	color: @re0;
	background-color: @no1;
}

#custom-wf-recorder:hover,
#bluetooth:hover,
#language:hover {
	color: @re0;
	background-color: @re2;
}

/* === WINDOW === */

#window {
	color: @no0;
	background-color: @re0;
	padding: 0 32px;
	border: none;
}
  '';

  # Run waybar as part of the graphical session (UWSM provides the target).
  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar (cybr lucid / milkoutside)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      ExecReload = "${pkgs.coreutils}/bin/kill -SIGUSR2 $MAINPID";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}

