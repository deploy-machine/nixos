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
  # waybar 0.15.0 (latest tag) sends `dispatch workspace <id>` over the IPC
  # socket on workspace-button clicks. Hyprland 0.55+ evaluates that as Lua
  # (`return hl.dispatch(workspace 1)`), which fails to parse — clicks are
  # silently dropped. Upstream commit 3547949c (2026-04-29) routes through
  # the new hl.dsp API when the Lua protocol is detected. Pin to that commit
  # until the next tagged release ships it.
  #
  # Master's subprojects/libcava.wrap bumped the cava subproject from
  # v0.10.7-beta → 0.10.7 (same LukashonakV/cava fork nixpkgs already uses for
  # waybar; only the tag moves). Nixpkgs' postUnpack still drops cava into the
  # 0.10.7-beta path, so meson can't resolve it — override postUnpack to feed
  # meson the directory it actually expects.
  cavaSrc = pkgs.fetchFromGitHub {
    owner = "LukashonakV";
    repo  = "cava";
    tag   = "0.10.7";
    hash  = "sha256-zkyj1vBzHtoypX4Bxdh1Vmwh967DKKxN751v79hzmgQ=";
  };
  waybarPkg = pkgs.waybar.overrideAttrs (_old: {
    version = "0.15.0-unstable-2026-04-29";
    src = pkgs.fetchFromGitHub {
      owner = "Alexays";
      repo  = "Waybar";
      rev   = "3547949cb4fa650f46265b35ad4eae7ed741b6ad";
      hash  = "sha256-p5iqMo4JPhbukRqPlYjciaU89wRPDmWSUY9NkxywI+k=";
    };
    postUnpack = ''
      pushd "$sourceRoot"
      cp -R --no-preserve=mode,ownership ${cavaSrc} subprojects/cava-0.10.7
      patchShebangs .
      popd
    '';
    # versionCheckHook runs `waybar --version` and expects to see the version
    # string we declared above. Upstream hasn't bumped the in-source version
    # past 0.15.0 on master, so the binary still prints "Waybar v0.15.0" and
    # the check fails. Skip it; we know exactly which commit we built.
    doInstallCheck = false;
  });

  # 14x31 triangular powerline separators (shape copied from cybr-waybar/svg).
  mkArrow = name: fill: dir:
    pkgs.writeText "waybar-${name}.svg" (
      if dir == "left"
      then ''<svg width="14" height="31" viewBox="0 0 14 31" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M0 0H14V19L0 31V0Z" fill="${fill}"/></svg>''
      else ''<svg width="14" height="31" viewBox="0 0 14 31" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M14 0L0 0L0 17L14 31L14 0Z" fill="${fill}"/></svg>''
    );
  # Full greyscale — no colored accent anywhere on the bar. The three
  # arrow fills are three grey brightness levels so the powerline
  # segmentation still reads by luminance:
  #   no1 = darker panel bg (default module pills)
  #   no2 = mid-grey (center window-title pill)
  #   re0 = brightest — used on the nixos logo pill (leftmost identity
  #         mark) and the active workspace indicator
  no1L = mkArrow "no1-left"  "#141414" "left";
  no1R = mkArrow "no1-right" "#141414" "right";
  no2L = mkArrow "no2-left"  "#1c1c1c" "left";
  no2R = mkArrow "no2-right" "#1c1c1c" "right";
  re0L = mkArrow "re0-left"  "#e0e0e0" "left";
  re0R = mkArrow "re0-right" "#e0e0e0" "right";
in
{
  home.packages = [
    waybarPkg
    pkgs.pavucontrol            # pulseaudio module on-click
    pkgs.networkmanagerapplet   # provides nm-connection-editor for network on-click
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
      "custom/arrow-right-no2",
      "hyprland/window",
      "custom/arrow-left-no2",
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
    "custom/arrow-left-no2": {
      "format": "  ",
      "tooltip": false
    },
    "custom/arrow-right-no2": {
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
      "all-outputs": false,
      "enable-bar-scroll": true,
      "format": "{name}",
      "on-scroll-up":   "hyprctl dispatch 'hl.dsp.focus({workspace=\"e-1\"})'",
      "on-scroll-down": "hyprctl dispatch 'hl.dsp.focus({workspace=\"e+1\"})'",
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

/* === VARIABLES ===
 * Full greyscale rice. Every pill, arrow, hover, active-state, and
 * semantic hint is a shade of grey. Differentiation is by luminance
 * only — no colored accent anywhere.
 */

@define-color no0 #0a0a0a;   /* base / transparent overlay */
@define-color no1 #141414;   /* default module pill bg */
@define-color no2 #1c1c1c;   /* mid-grey for center window pill */
@define-color no3 #272727;   /* hover fill */

@define-color fg  #d0d0d0;   /* bright text (hover / emphasized) */
@define-color wh0 #b0b0b0;   /* primary module text (koda fg) */
@define-color wh1 #777777;   /* dim module text */
@define-color wh2 #50585d;   /* very dim / disabled */
@define-color wh3 #3a3a3a;   /* border */

/* "Accent" — kept as a name so downstream CSS keeps compiling, but the
 * value is bright grey. Reads as "the focused thing" without color. */
@define-color re0 #e0e0e0;
@define-color re1 #b0b0b0;
@define-color re2 #3a3a3a;   /* neutral endcap */

/* Semantic slots — greyed. Luminance differentiates:
 *   ye0 bright   -> caution / urgent
 *   gr0 mid      -> ok / linked
 *   or0 dim      -> disconnected
 *   cy0 mid-dim  -> low-battery info */
@define-color ye0 #d0d0d0;
@define-color gr0 #b0b0b0;
@define-color or0 #777777;
@define-color cy0 #909090;


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
	color: @wh0;
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

/* Bright-grey arrow — transitions from the bright #custom-nixos pill
 * into the grey #workspaces pill. */
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

/* Mid-grey arrows — segment the center window-title pill into a slightly
 * lighter grey without introducing color. */
#custom-arrow-left-no2 {
	background-image: url("${no2L}");
	background-position: left;
	background-repeat: no-repeat;
	background-size: contain;
	background-color: @no1;
}

#custom-arrow-right-no2 {
	background-image: url("${no2R}");
	background-position: right;
	background-repeat: no-repeat;
	background-size: contain;
	background-color: @no1;
}


/* === NIXOS LOGO ===
 * Identity pill on the far left. Bright grey so it reads as the
 * anchor without introducing color. */

#custom-nixos {
	color: @no0;
	background-color: @re0;
	font-weight: bold;
}

#custom-nixos:hover {
	color: @no0;
	background-color: @re1;
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
	color: @wh1;
	background: transparent;
}

#workspaces button label {
	font-size: 15px;
	padding: 0 10px;
	color: @wh1;
}

/* Active workspace — bright grey pill, matches the #custom-nixos anchor. */
#workspaces button.active {
	background-color: @re0;
}

#workspaces button.active label {
	color: @no0;
}

#workspaces button:hover {
	background-color: @no3;
}

#workspaces button:hover label {
	color: @wh0;
}

#workspaces button.active:hover {
	background-color: @re1;
}

#workspaces button.active:hover label {
	color: @no0;
}

#workspaces button.urgent {
	background-color: @ye0;
}

#workspaces button.urgent label {
	color: @no0;
}

/* === CLOCKS === */

#clock.time,
#clock.date {
	color: @wh0;
	background-color: @no1;
	padding: 0 32px;
}

#clock.time:hover,
#clock.date:hover {
	color: @fg;
	background-color: @no3;
}


/* === SYSTEM METRICS === */

#cpu,
#memory,
#temperature,
#temperature.cpu,
#temperature.gpu {
	color: @wh0;
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
	color: @fg;
	background-color: @no3;
}


/* === NETWORK & AUDIO === */

#network {
	background-color: @no1;
	color: @wh0;
}

#network.disconnected {
	color: @no0;
	background-color: @or0;
}

#network.linked {
	color: @gr0;
	background-color: @no1;
}

#pulseaudio {
	color: @wh0;
	background-color: @no1;
}

#pulseaudio.muted {
	color: @wh2;
}

#network:hover,
#pulseaudio:hover {
	color: @fg;
	background-color: @no3;
}

#pulseaudio.muted:hover {
	color: @wh1;
	background-color: @no3;
}


/* === MUSIC === */

#custom-music {
	background-color: @no1;
	color: @wh0;
	padding: 0 32px;
	border: none;
}


/* === NOTIFICATIONS === */

#custom-notifications {
	background-color: @no1;
	color: @wh1;
	font-size: 20px;
}

#custom-notifications:hover {
	color: @wh0;
	background-color: @no3;
}

#custom-notifications.dnd-none {
	color: @wh2;
}

#custom-notifications.dnd-none:hover {
	color: @wh1;
	background-color: @no3;
}

/* === UPDATES === */

#custom-updates {
	color: @wh0;
	font-size: 20px;
	margin: 0 20px;
}

#custom-updates:hover {
	background-color: @no3;
}


/* === MISC === */

#custom-wf-recorder {
	color: @wh0;
	background-color: @no1;
}

#bluetooth {
	color: @wh0;
	background-color: @no1;
}

#language {
	color: @wh0;
	background-color: @no1;
}

#custom-brightness {
	background-color: @no1;
}

#custom-brightness:hover {
	background-color: @no3;
}

#custom-brightness.max {
	color: @fg;
}

#custom-brightness.high {
	color: @wh0;
}

#custom-brightness.mid {
	color: @wh1;
}

#custom-brightness.low {
	color: @wh2;
}

#custom-brightness.min {
	color: @wh2;
}

#tray {
	color: @wh0;
	background-color: @no1;
}

#custom-wf-recorder:hover,
#bluetooth:hover,
#language:hover {
	color: @fg;
	background-color: @no3;
}

/* === WINDOW TITLE ===
 * Center pill, one shade lighter than the module bg so it segments
 * without color. */

#window {
	color: @wh0;
	background-color: @no2;
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
      ExecStart = "${waybarPkg}/bin/waybar";
      ExecReload = "${pkgs.coreutils}/bin/kill -SIGUSR2 $MAINPID";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}

