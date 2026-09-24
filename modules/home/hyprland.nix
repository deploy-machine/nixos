{ config, lib, pkgs, ... }:
let
  c = import ./colors.nix;
  # Default background follows the active theme (modules/omarchy/theme.nix);
  # background sets are deployed to ~/Wallpapers/themes/<name>/ by
  # modules/omarchy/home.nix. omarchy-wallpaper switches within the set.
  wallpaper = "${config.home.homeDirectory}/${(import ../omarchy/theme.nix).wallpaper}";

  # 26.05 renamed swww → awww; 25.11 still ships swww. The CLIs are
  # identical (`<bin> img <path>`, `<bin>-daemon`) so the autostart lines
  # below just interpolate this name. (pkgs.swww on 26.05 is an alias to
  # awww with a deprecation warning, so we check awww first.)
  wallpaperBin = if pkgs ? awww then "awww" else "swww";

  # Hyprland 0.55 (26.05 channel) loads ~/.config/hypr/hyprland.lua natively;
  # Hyprland 0.52 (25.11 channel, Asahi) does NOT — it silently ignores .lua
  # and generates an autogen .conf. Pick the right format per channel.
  # SUPER everywhere since the full-Omarchy keybind layout: omarchy leans on
  # ALT+TAB / SUPER+ALT chords, so ALT can't be the main modifier anymore.
  # (Asahi's Cmd key maps to Super; on x86 it's the Windows key.)
  isAsahi = pkgs.stdenv.hostPlatform.isAarch64;
  mainMod = "SUPER";

  # Discord client tracks what nixcord.nix actually installs: upstream Discord
  # is unfree + x86_64-only, so aarch64 falls back to Vesktop.
  discordBin = if isAsahi then "vesktop" else "discord";

  # `screenshot <region|window|output>` — hyprshot captures pixels to stdout
  # (--raw), satty pops up an annotate/crop UI, on save it writes the file +
  # copies to the clipboard. After save, notify-send blocks on --wait so a
  # click on "Open" or "Show in Files" fires xdg-open.
  screenshotScript = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      hyprshot satty wl-clipboard libnotify xdg-utils coreutils
    ];
    text = ''
      MODE="''${1:-region}"
      TS="$(date +%Y%m%d_%H%M%S)"
      OUT="$HOME/Pictures/screenshot_$TS.png"
      mkdir -p "$HOME/Pictures"

      hyprshot -m "$MODE" --raw | satty \
        --filename - \
        --output-filename "$OUT" \
        --copy-command wl-copy \
        --early-exit \
        --actions-on-enter save-to-clipboard

      [ -f "$OUT" ] || exit 0

      ACTION=$(notify-send -a Screenshot -i "$OUT" \
        --action="open=Open" --action="reveal=Show in Files" \
        --wait \
        "Screenshot saved" "$OUT")
      case "$ACTION" in
        open)   xdg-open "$OUT" ;;
        reveal) xdg-open "$(dirname "$OUT")" ;;
      esac
    '';
  };

  # swww/awww-daemon notices when a new wayland output appears but won't
  # paint it until a client re-issues `img`. Hyprland's exec-once only fires
  # at session start, so a monitor hot-plugged later stays blank. This
  # watcher: waits for the daemon, paints once, then tails socket2 and
  # re-paints on every monitoradded/monitorremoved. Cold-boot covered too,
  # because outputs that come up after Hyprland starts surface as
  # `monitoradded` events as soon as they're registered. Used by both the
  # .conf and .lua paths below — one helper, one place to debug.
  wallpaperScript = pkgs.writeShellApplication {
    name = "hypr-wallpaper";
    runtimeInputs = [ pkgs.${wallpaperBin} pkgs.socat pkgs.coreutils ];
    text = ''
      paint() { ${wallpaperBin} img "${wallpaper}" >/dev/null 2>&1 || true; }

      # Daemon is launched in parallel by another exec-once; wait up to ~10s
      # for its IPC socket. Without this, the first paint races and silently
      # no-ops.
      for _ in $(seq 1 50); do
        ${wallpaperBin} query >/dev/null 2>&1 && break
        sleep 0.2
      done

      paint

      SOCK="''${XDG_RUNTIME_DIR}/hypr/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
      [ -S "$SOCK" ] || exit 0
      # socket2 broadcasts every event to every connected client, so this
      # coexists fine with the pin watcher below.
      socat -U - "UNIX-CONNECT:$SOCK" | while read -r line; do
        case "$line" in
          monitoradded*|monitorremoved*) paint ;;
        esac
      done
    '';
  };

  # Hyprland 0.52's .conf format has no Lua-style loops, so the dynamic
  # workspace pinning (1 mon → 1..10, 2 → 5+5, 3 → 3+3+3, 4+ → round-robin)
  # lives in this helper that re-pins on monitor add/remove via socket2 IPC.
  # Equivalent to autoPinWorkspaces() in the .lua path below.
  pinScript = pkgs.writeShellApplication {
    name = "hypr-pin-workspaces";
    runtimeInputs = with pkgs; [ jq socat hyprland coreutils gnused ];
    text = ''
      pin() {
        mapfile -t mons < <(hyprctl monitors -j | jq -r 'sort_by(.x // 0) | .[].name')
        local n=''${#mons[@]}
        [ "$n" -eq 0 ] && return

        local -a layout
        case "$n" in
          1) layout=("1 2 3 4 5 6 7 8 9 10") ;;
          2) layout=("1 2 3 4 5" "6 7 8 9 10") ;;
          3) layout=("1 2 3" "4 5 6" "7 8 9") ;;
          *)
            for ((i=0; i<n; i++)); do layout[i]=""; done
            for w in 1 2 3 4 5 6 7 8 9 10; do
              idx=$(((w - 1) % n))
              layout[idx]+="$w "
            done
            ;;
        esac

        for ((i=0; i<n; i++)); do
          local first=""
          for w in ''${layout[i]}; do
            local default=false
            if [ -z "$first" ]; then default=true; first="$w"; fi
            hyprctl keyword workspace "$w,monitor:''${mons[i]},persistent:true,default:$default" >/dev/null
          done
        done
      }

      pin

      SOCK="''${XDG_RUNTIME_DIR}/hypr/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
      [ -S "$SOCK" ] || exit 0
      socat -U - "UNIX-CONNECT:$SOCK" | while read -r line; do
        case "$line" in
          monitoradded*|monitorremoved*) pin ;;
        esac
      done
    '';
  };

  # ---------------------------- .conf (Hyprland 0.52, Asahi / 25.11) --------
  hyprlandConf = ''
    # milkoutside / cyberpunk Hyprland config (.conf, Hyprland 0.52)

    $terminal    = kitty
    $fileManager = thunar
    $menu        = rofi -show drun -show-icons
    $mainMod     = ${mainMod}

    ############################################################ AUTOSTART
    exec-once = ${wallpaperBin}-daemon
    exec-once = ${wallpaperScript}/bin/hypr-wallpaper
    exec-once = sleep 6 && systemctl --user start wayvnc.service
    exec-once = ${pinScript}/bin/hypr-pin-workspaces
    # waybar + swaync are started by their home-manager systemd user services
    # (wantedBy = graphical-session.target). Don't also exec them here.

    ############################################################# MONITORS
    # Per-host monitor layout (written by modules/roles/multi-monitor.nix).
    # Hyprland's `source =` tolerates a missing file with a warning, so
    # single-screen and headless hosts still parse.
    source = ~/.config/hypr/monitors.conf

    ############################################################# ENV VARS
    env = XCURSOR_SIZE,24
    env = HYPRCURSOR_SIZE,24

    ######################################################## LOOK AND FEEL
    general {
        gaps_in  = 5
        gaps_out = 20
        border_size = 2
        # Full greyscale rice: active window border is a bright→brighter
        # grey gradient. Focus signal reads via luminance, no color.
        col.active_border = rgb(${c.fg}) rgb(${c.fgBright}) 45deg
        col.inactive_border = rgb(${c.border})
        resize_on_border = false
        allow_tearing = false
        layout = dwindle
    }

    decoration {
        rounding = 10
        rounding_power = 2
        active_opacity = 1.0
        inactive_opacity = 0.95

        shadow {
            enabled = true
            range = 8
            render_power = 3
            color = 0xaa000000
            color_inactive = 0x66000000
        }

        blur {
            enabled = true
            size = 4
            passes = 2
            vibrancy = 0.1696
        }
    }

    animations {
        enabled = true

        bezier = easeOutQuint,   0.23, 1,    0.32, 1
        bezier = easeInOutCubic, 0.65, 0.05, 0.36, 1
        bezier = linear,         0,    0,    1,    1
        bezier = almostLinear,   0.5,  0.5,  0.75, 1
        bezier = quick,          0.15, 0,    0.1,  1
        # Spring curves aren't reliably available in 0.52's .conf parser;
        # approximate the lua `easy` spring with a slightly-overshooting cubic.
        bezier = easy,           0.34, 1.56, 0.64, 1

        animation = global,     1, 10,   default
        animation = border,     1, 5.39, easeOutQuint
        animation = windows,    1, 4.79, easy
        animation = windowsIn,  1, 4.1,  easy,         popin 87%
        animation = windowsOut, 1, 1.49, linear,       popin 87%
        animation = fadeIn,     1, 1.73, almostLinear
        animation = fadeOut,    1, 1.46, almostLinear
        animation = fade,       1, 3.03, quick
        animation = layers,     1, 3.81, easeOutQuint
        animation = layersIn,   1, 4,    easeOutQuint, fade
        animation = layersOut,  1, 1.5,  linear,       fade
        animation = workspaces, 1, 1.94, almostLinear, fade
    }

    dwindle {
        preserve_split = true
    }

    master {
        new_status = master
    }

    misc {
        force_default_wallpaper = 0
        disable_hyprland_logo   = true
    }

    input {
        kb_layout  = us
        kb_variant =
        kb_model   =
        # ctrl:nocaps: CapsLock becomes a second Ctrl.
        kb_options = ctrl:nocaps
        kb_rules   =
        follow_mouse = 1
        sensitivity = 0
        touchpad {
            natural_scroll = false
        }
    }

    # Hyprland 0.50 replaced the `gestures { workspace_swipe = ... }` block
    # with a unified `gesture =` keyword (FINGERS, DIRECTION, ACTION).
    gesture = 3, horizontal, workspace

    device {
        name = epic-mouse-v1
        sensitivity = -0.5
    }

    ###################################################### WORKSPACE RULES
    # Smart gaps: single-window workspaces drop the gap/border so the window
    # fills the screen edge-to-edge. (Per-monitor pinning is dynamic — see
    # the pin script in autostart.)
    workspace = w[tv1], gapsout:0, gapsin:0
    workspace = f[1],   gapsout:0, gapsin:0

    ######################################################### KEYBINDINGS
    # Full Omarchy layout, ported. Menus/notifications/toggles go through the
    # omarchy-* scripts (modules/omarchy/), tiling through native dispatchers.

    # -------- Applications (omarchy bindings/applications.lua) --------
    bind = $mainMod,           RETURN, exec, $terminal
    bind = $mainMod SHIFT,     RETURN, exec, chromium
    bind = $mainMod SHIFT,     B, exec, chromium
    bind = $mainMod SHIFT ALT, B, exec, chromium --incognito
    bind = $mainMod SHIFT,     F, exec, $fileManager
    bind = $mainMod SHIFT,     N, exec, kitty -e nvim
    bind = $mainMod SHIFT,     D, exec, kitty --class=lazydocker -e lazydocker
    bind = $mainMod SHIFT,     G, exec, ${discordBin}
    bind = $mainMod SHIFT,     O, exec, obsidian
    bind = $mainMod SHIFT,     slash, exec, bitwarden
    bind = $mainMod CTRL,      T, exec, kitty -e btop
    bind = $mainMod CTRL,      A, exec, pavucontrol
    bind = $mainMod CTRL,      B, exec, blueman-manager
    bind = $mainMod CTRL,      W, exec, networkmanager_dmenu

    # -------- Menus (omarchy-menu tree, rofi-based) --------
    bind = $mainMod,           SPACE, exec, omarchy-menu
    bind = $mainMod ALT,       SPACE, exec, $menu
    bind = $mainMod,           ESCAPE, exec, omarchy-menu system
    bind = $mainMod CTRL,      C, exec, omarchy-menu capture
    bind = $mainMod CTRL,      O, exec, omarchy-menu toggle
    bind = $mainMod CTRL,      E, exec, rofimoji --action copy
    bind = $mainMod CTRL,      SPACE, exec, omarchy-wallpaper
    bind = $mainMod,           K, exec, omarchy-menu-keybindings

    # -------- Notifications (swaync) --------
    bind = $mainMod,           comma, exec, omarchy-notification dismiss
    bind = $mainMod SHIFT,     comma, exec, omarchy-notification dismiss-all
    bind = $mainMod CTRL,      comma, exec, omarchy-toggle silence
    bind = $mainMod SHIFT ALT, comma, exec, omarchy-notification panel

    # -------- Toggles --------
    bind = $mainMod CTRL,      I, exec, omarchy-toggle idle
    bind = $mainMod CTRL,      N, exec, omarchy-toggle nightlight
    bind = $mainMod SHIFT,     SPACE, exec, omarchy-toggle bar
    bind = $mainMod,           BACKSPACE, exec, omarchy-toggle transparency
    bind = $mainMod SHIFT,     BACKSPACE, exec, omarchy-toggle gaps

    # -------- Info notifications --------
    bind = $mainMod CTRL ALT,  T, exec, omarchy-notification time
    bind = $mainMod CTRL ALT,  B, exec, omarchy-notification battery
    bind = $mainMod CTRL ALT,  W, exec, omarchy-notification weather

    # -------- Window management (omarchy bindings/tiling.lua) --------
    bind = $mainMod,           W, killactive
    bind = $mainMod,           Q, killactive
    bind = $mainMod,           J, togglesplit
    bind = $mainMod,           P, pseudo
    bind = $mainMod,           T, togglefloating
    bind = $mainMod,           F, fullscreen
    bind = $mainMod ALT,       F, fullscreen, 1
    bind = $mainMod,           O, exec, hyprctl --batch "dispatch togglefloating ; dispatch pin"
    bind = $mainMod,           L, exec, omarchy-toggle layout

    # Focus / swap with arrows.
    bind = $mainMod,        left, movefocus, l
    bind = $mainMod,       right, movefocus, r
    bind = $mainMod,          up, movefocus, u
    bind = $mainMod,        down, movefocus, d
    # movewindow (not swapwindow) so a window at the screen edge crosses to
    # the next/previous monitor.
    bind = $mainMod SHIFT,  left, movewindow, l
    bind = $mainMod SHIFT, right, movewindow, r
    bind = $mainMod SHIFT,    up, movewindow, u
    bind = $mainMod SHIFT,  down, movewindow, d

    # Workspaces 1-10 (0 = ws 10), globally numbered, pinned to monitors by
    # the pin script in autostart. SHIFT moves + follows, SHIFT+ALT moves
    # silently.
    bind = $mainMod,           1, workspace, 1
    bind = $mainMod,           2, workspace, 2
    bind = $mainMod,           3, workspace, 3
    bind = $mainMod,           4, workspace, 4
    bind = $mainMod,           5, workspace, 5
    bind = $mainMod,           6, workspace, 6
    bind = $mainMod,           7, workspace, 7
    bind = $mainMod,           8, workspace, 8
    bind = $mainMod,           9, workspace, 9
    bind = $mainMod,           0, workspace, 10
    bind = $mainMod SHIFT,     1, movetoworkspace, 1
    bind = $mainMod SHIFT,     2, movetoworkspace, 2
    bind = $mainMod SHIFT,     3, movetoworkspace, 3
    bind = $mainMod SHIFT,     4, movetoworkspace, 4
    bind = $mainMod SHIFT,     5, movetoworkspace, 5
    bind = $mainMod SHIFT,     6, movetoworkspace, 6
    bind = $mainMod SHIFT,     7, movetoworkspace, 7
    bind = $mainMod SHIFT,     8, movetoworkspace, 8
    bind = $mainMod SHIFT,     9, movetoworkspace, 9
    bind = $mainMod SHIFT,     0, movetoworkspace, 10
    bind = $mainMod SHIFT ALT, 1, movetoworkspacesilent, 1
    bind = $mainMod SHIFT ALT, 2, movetoworkspacesilent, 2
    bind = $mainMod SHIFT ALT, 3, movetoworkspacesilent, 3
    bind = $mainMod SHIFT ALT, 4, movetoworkspacesilent, 4
    bind = $mainMod SHIFT ALT, 5, movetoworkspacesilent, 5
    bind = $mainMod SHIFT ALT, 6, movetoworkspacesilent, 6
    bind = $mainMod SHIFT ALT, 7, movetoworkspacesilent, 7
    bind = $mainMod SHIFT ALT, 8, movetoworkspacesilent, 8
    bind = $mainMod SHIFT ALT, 9, movetoworkspacesilent, 9
    bind = $mainMod SHIFT ALT, 0, movetoworkspacesilent, 10

    # Workspace cycling + former workspace.
    bind = $mainMod,       TAB, workspace, e+1
    bind = $mainMod SHIFT, TAB, workspace, e-1
    bind = $mainMod CTRL,  TAB, workspace, previous

    # Window cycling (ALT+TAB) — both binds on one key fire together.
    bind = ALT,       TAB, cyclenext
    bind = ALT,       TAB, bringactivetotop
    bind = ALT SHIFT, TAB, cyclenext, prev
    bind = ALT SHIFT, TAB, bringactivetotop

    # Scratchpad.
    bind = $mainMod,       S, togglespecialworkspace, scratchpad
    bind = $mainMod ALT,   S, movetoworkspacesilent, special:scratchpad
    bind = $mainMod,       grave, togglespecialworkspace, scratchpad
    bind = $mainMod SHIFT, grave, movetoworkspacesilent, special:scratchpad

    # Throw the current workspace at another monitor.
    bind = $mainMod SHIFT ALT,  left, movecurrentworkspacetomonitor, l
    bind = $mainMod SHIFT ALT, right, movecurrentworkspacetomonitor, r
    bind = $mainMod SHIFT ALT,    up, movecurrentworkspacetomonitor, u
    bind = $mainMod SHIFT ALT,  down, movecurrentworkspacetomonitor, d
    bind = CTRL ALT,       TAB, focusmonitor, +1
    bind = CTRL ALT SHIFT, TAB, focusmonitor, -1

    # Resize: -/= a step, ALT a little, CTRL a lot (binde = repeats).
    binde = $mainMod,            minus, resizeactive, -100 0
    binde = $mainMod,            equal, resizeactive, 100 0
    binde = $mainMod SHIFT,      minus, resizeactive, 0 -100
    binde = $mainMod SHIFT,      equal, resizeactive, 0 100
    binde = $mainMod ALT,        minus, resizeactive, -25 0
    binde = $mainMod ALT,        equal, resizeactive, 25 0
    binde = $mainMod SHIFT ALT,  minus, resizeactive, 0 -25
    binde = $mainMod SHIFT ALT,  equal, resizeactive, 0 25
    binde = $mainMod CTRL,       minus, resizeactive, -300 0
    binde = $mainMod CTRL,       equal, resizeactive, 300 0
    binde = $mainMod CTRL SHIFT, minus, resizeactive, 0 -300
    binde = $mainMod CTRL SHIFT, equal, resizeactive, 0 300

    # Window groups.
    bind = $mainMod,           G, togglegroup
    bind = $mainMod ALT,       G, moveoutofgroup
    bind = $mainMod ALT,    left, moveintogroup, l
    bind = $mainMod ALT,   right, moveintogroup, r
    bind = $mainMod ALT,      up, moveintogroup, u
    bind = $mainMod ALT,    down, moveintogroup, d
    bind = $mainMod ALT,       TAB, changegroupactive, f
    bind = $mainMod ALT SHIFT, TAB, changegroupactive, b
    bind = $mainMod CTRL,   left, changegroupactive, b
    bind = $mainMod CTRL,  right, changegroupactive, f

    # Mouse: scroll workspaces, drag/resize, cycle group windows.
    bind  = $mainMod,     mouse_down, workspace, e+1
    bind  = $mainMod,     mouse_up,   workspace, e-1
    bind  = $mainMod ALT, mouse_down, changegroupactive, f
    bind  = $mainMod ALT, mouse_up,   changegroupactive, b
    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow

    # -------- Universal clipboard (omarchy bindings/clipboard.lua) --------
    # SUPER+C/V/X work everywhere; kitty gets CTRL+SHIFT translated.
    bind = $mainMod,      C, exec, omarchy-clipboard copy
    bind = $mainMod,      V, exec, omarchy-clipboard paste
    bind = $mainMod,      X, exec, omarchy-clipboard cut
    bind = $mainMod CTRL, V, exec, sh -c 'cliphist list | rofi -dmenu | cliphist decode | wl-copy'

    # -------- Capture (PRINT may be absent on the Mac keyboard; the
    # SUPER+CTRL+C capture menu covers everything there) --------
    bind = ,               PRINT, exec, omarchy-capture screenshot region
    bind = SHIFT,          PRINT, exec, omarchy-capture screenshot window
    bind = CTRL,           PRINT, exec, omarchy-capture screenshot output
    bind = ALT,            PRINT, exec, omarchy-capture record
    bind = $mainMod,       PRINT, exec, omarchy-capture color
    bind = $mainMod CTRL,  PRINT, exec, omarchy-capture ocr

    # -------- Zoom / lock --------
    bind = $mainMod CTRL,     Z, exec, omarchy-zoom in
    bind = $mainMod CTRL ALT, Z, exec, omarchy-zoom reset
    bind = $mainMod CTRL,     L, exec, hyprlock

    # Hardware media keys (l = locked, e = repeat); ALT variants are precise.
    bindle = ,    XF86AudioRaiseVolume,  exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
    bindle = ,    XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindle = ALT, XF86AudioRaiseVolume,  exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+
    bindle = ALT, XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-
    bindl  = ,    XF86AudioMute,         exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindl  = ,    XF86AudioMicMute,      exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    bindle = ,    XF86MonBrightnessUp,   exec, brightnessctl -e4 -n2 set 5%+
    bindle = ,    XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-
    bindle = ALT, XF86MonBrightnessUp,   exec, brightnessctl -e4 -n2 set 1%+
    bindle = ALT, XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 1%-
    bindl  = ,    XF86AudioNext,         exec, playerctl next
    bindl  = ,    XF86AudioPause,        exec, playerctl play-pause
    bindl  = ,    XF86AudioPlay,         exec, playerctl play-pause
    bindl  = ,    XF86AudioPrev,         exec, playerctl previous

    ######################################################## WINDOW RULES
    windowrulev2 = suppressevent maximize, class:.*
    windowrulev2 = nofocus, class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0
    # Floating terminal the Omarchy menu launches things in.
    windowrulev2 = float, class:^(Omarchy-float)$
    windowrulev2 = size 60% 70%, class:^(Omarchy-float)$
    windowrulev2 = center, class:^(Omarchy-float)$
  '';

  # ---------------------------- .lua (Hyprland 0.55+, 26.05) ---------------
  hyprlandLua = ''
    -- milkoutside / cyberpunk Hyprland config (native Lua, Hyprland 0.55+)

    local terminal    = "kitty"
    local fileManager = "thunar"
    local menu        = "rofi -show drun -show-icons"

    ----------------------------------------------------------------- AUTOSTART
    hl.on("hyprland.start", function ()
      hl.exec_cmd("${wallpaperBin}-daemon")
      hl.exec_cmd("${wallpaperScript}/bin/hypr-wallpaper")
      hl.exec_cmd("nm-applet --indicator")
      hl.exec_cmd("sleep 6 && systemctl --user start wayvnc.service")
    end)
    -- waybar + swaync are started by their home-manager systemd user services
    -- (wantedBy = graphical-session.target). Don't also exec them here, that
    -- caused 4-bars-on-2-monitors (one set per spawn × per monitor).

    ------------------------------------------------------------------- MONITORS
    -- Per-host monitor layout (written by modules/roles/multi-monitor.nix).
    -- pcall keeps single-screen and headless hosts happy when the file is absent.
    pcall(dofile, (os.getenv("HOME") or "/home") .. "/.config/hypr/monitors.lua")

    --------------------------------------------------- WORKSPACE PINNING (AUTO)
    -- Pin global workspaces 1-10 to monitors based on how many are connected.
    -- Monitors are sorted left → right by x position; ${mainMod}+N in the keybinds
    -- section below focuses workspace N, which makes focus jump to whichever
    -- monitor owns it. persistent=true keeps each waybar's button row stable
    -- even when the workspace is empty.
    --
    --   1 monitor  → [1..10]                       on the one monitor
    --   2 monitors → [1..5] | [6..10]
    --   3 monitors → [1..3] | [4..6] | [7..9]      (ws 10 left unpinned)
    --   4+         → round-robin (1→m1, 2→m2, …)
    --
    -- Per-host overrides: add extra hl.workspace_rule calls in monitors.lua
    -- after this runs; last write wins for any given workspace.
    local function autoPinWorkspaces()
        local monitors = hl.get_monitors()
        if not monitors or #monitors == 0 then return end
        table.sort(monitors, function(a, b) return (a.x or 0) < (b.x or 0) end)

        local n = #monitors
        local layout
        if     n == 1 then layout = { {1, 2, 3, 4, 5, 6, 7, 8, 9, 10} }
        elseif n == 2 then layout = { {1, 2, 3, 4, 5}, {6, 7, 8, 9, 10} }
        elseif n == 3 then layout = { {1, 2, 3}, {4, 5, 6}, {7, 8, 9} }
        else
            layout = {}
            for i = 1, n do layout[i] = {} end
            for w = 1, 10 do
                table.insert(layout[((w - 1) % n) + 1], w)
            end
        end

        for i, mon in ipairs(monitors) do
            local list = layout[i] or {}
            for _, w in ipairs(list) do
                hl.workspace_rule({
                    workspace  = tostring(w),
                    monitor    = mon.name,
                    persistent = true,
                    default    = (w == list[1]),
                })
                -- Rules only apply at creation, so move any workspace that
                -- was already created on the wrong monitor (e.g. during boot,
                -- before positions from monitors.lua were applied).
                local ws = hl.get_workspace(tostring(w))
                if ws and ws.monitor and ws.monitor.name ~= mon.name then
                    hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(w), monitor = mon.name }))
                end
            end
        end
    end

    -- Call inline so `hyprctl reload` re-pins immediately (monitors are already
    -- up). The event hooks below cover cold boot (monitors come up after the
    -- config parses) and hot-plug. monitor.added fires before the output's
    -- configured position is applied (it still reads x=0), so also re-pin on
    -- layout_changed once positions have settled.
    autoPinWorkspaces()
    hl.on("monitor.added",          autoPinWorkspaces)
    hl.on("monitor.removed",        autoPinWorkspaces)
    hl.on("monitor.layout_changed", autoPinWorkspaces)

    ------------------------------------------------------------------- ENV VARS
    hl.env("XCURSOR_SIZE", "24")
    hl.env("HYPRCURSOR_SIZE", "24")

    -------------------------------------------------------------- LOOK AND FEEL
    hl.config({
        general = {
            gaps_in  = 5,
            gaps_out = 20,
            border_size = 2,
            col = {
                -- Full greyscale: bright grey → brighter grey gradient
                -- on the active border. Luminance-only focus signal.
                active_border   = { colors = {"rgb(${c.fg})", "rgb(${c.fgBright})"}, angle = 45 },
                inactive_border = "rgb(${c.border})",
            },
            resize_on_border = false,
            allow_tearing = false,
            layout = "dwindle",
        },

        decoration = {
            rounding       = 10,
            rounding_power = 2,
            active_opacity   = 1.0,
            inactive_opacity = 0.95,
            shadow = {
                enabled      = true,
                range        = 8,
                render_power = 3,
                color          = 0xaa000000,   -- neutral drop shadow, no color cast
                color_inactive = 0x66000000,
            },
            blur = {
                enabled  = true,
                size     = 4,
                passes   = 2,
                vibrancy = 0.1696,
            },
        },

        animations = {
            enabled = true,
        },

        dwindle = {
            preserve_split = true,
        },

        master = {
            new_status = "master",
        },

        misc = {
            force_default_wallpaper = 0,
            disable_hyprland_logo   = true,
        },

        input = {
            kb_layout  = "us",
            kb_variant = "",
            kb_model   = "",
            -- ctrl:nocaps: CapsLock becomes a second Ctrl. Carried over from
            -- the omarchy keyboard setup — no more accidental SHOUTING and
            -- the home-row Ctrl makes vim/tmux comfortable.
            kb_options = "ctrl:nocaps",
            kb_rules   = "",
            follow_mouse = 1,
            sensitivity = 0,
            touchpad = {
                natural_scroll = false,
            },
        },
    })

    ----------------------------------------------------------------- WORKSPACE RULES
    -- Smart gaps from the omarchy config: workspaces holding exactly one tiled
    -- or one fullscreen window drop the surrounding gap and border so the
    -- single window fills the screen edge-to-edge.
    hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
    hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

    ------------------------------------------------------------------ ANIMATIONS
    hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
    hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
    hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
    hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
    hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
    hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

    hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
    hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
    hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
    hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
    hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
    hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
    hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
    hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
    hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
    hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
    hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
    hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

    ----------------------------------------------------------------------- INPUT
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
    hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

    ------------------------------------------------------------------ KEYBINDINGS
    -- Full Omarchy layout on Hyprland's native Lua dispatchers (hl.dsp.*).
    -- Menus / notifications / toggles route through the omarchy-* scripts
    -- from modules/omarchy/, same as the .conf dialect above.
    local mainMod = "${mainMod}"

    local function bind(combo, desc, action, opts)
        opts = opts or {}
        opts.description = desc
        hl.bind(combo, action, opts)
    end
    local function run(cmd) return hl.dsp.exec_cmd(cmd) end

    -- Applications (omarchy bindings/applications.lua)
    bind(mainMod .. " + RETURN",              "Terminal",           run(terminal))
    bind(mainMod .. " + SHIFT + RETURN",      "Browser",            run("chromium"))
    bind(mainMod .. " + SHIFT + B",           "Browser",            run("chromium"))
    bind(mainMod .. " + SHIFT + ALT + B",     "Browser (private)",  run("chromium --incognito"))
    bind(mainMod .. " + SHIFT + F",           "File manager",       run(fileManager))
    bind(mainMod .. " + SHIFT + N",           "Editor",             run("kitty -e nvim"))
    bind(mainMod .. " + SHIFT + D",           "Docker (lazydocker)",run("kitty --class=lazydocker -e lazydocker"))
    bind(mainMod .. " + SHIFT + G",           "Discord",            run("${discordBin}"))
    bind(mainMod .. " + SHIFT + O",           "Obsidian",           run("obsidian"))
    bind(mainMod .. " + SHIFT + SLASH",       "Passwords",          run("bitwarden"))
    bind(mainMod .. " + CTRL + T",            "Activity (btop)",    run("kitty -e btop"))
    bind(mainMod .. " + CTRL + A",            "Audio mixer",        run("pavucontrol"))
    bind(mainMod .. " + CTRL + B",            "Bluetooth",          run("blueman-manager"))
    bind(mainMod .. " + CTRL + W",            "Wi-Fi",              run("networkmanager_dmenu"))

    -- Menus (omarchy-menu tree, rofi-based)
    bind(mainMod .. " + SPACE",               "Omarchy menu",       run("omarchy-menu"))
    bind(mainMod .. " + ALT + SPACE",         "Apps menu",          run(menu))
    bind(mainMod .. " + ESCAPE",              "System menu",        run("omarchy-menu system"))
    bind(mainMod .. " + CTRL + C",            "Capture menu",       run("omarchy-menu capture"))
    bind(mainMod .. " + CTRL + O",            "Toggle menu",        run("omarchy-menu toggle"))
    bind(mainMod .. " + CTRL + E",            "Emoji picker",       run("rofimoji --action copy"))
    bind(mainMod .. " + CTRL + SPACE",        "Background switcher",run("omarchy-wallpaper"))
    bind(mainMod .. " + K",                   "Keybindings",        run("omarchy-menu-keybindings"))

    -- Notifications (swaync)
    bind(mainMod .. " + comma",               "Dismiss last notification", run("omarchy-notification dismiss"))
    bind(mainMod .. " + SHIFT + comma",       "Dismiss all notifications", run("omarchy-notification dismiss-all"))
    bind(mainMod .. " + CTRL + comma",        "Silence notifications",     run("omarchy-toggle silence"))
    bind(mainMod .. " + SHIFT + ALT + comma", "Notification history",      run("omarchy-notification panel"))

    -- Toggles
    bind(mainMod .. " + CTRL + I",            "Toggle locking on idle", run("omarchy-toggle idle"))
    bind(mainMod .. " + CTRL + N",            "Toggle nightlight",      run("omarchy-toggle nightlight"))
    bind(mainMod .. " + SHIFT + SPACE",       "Toggle bar",             run("omarchy-toggle bar"))
    bind(mainMod .. " + BACKSPACE",           "Toggle transparency",    run("omarchy-toggle transparency"))
    bind(mainMod .. " + SHIFT + BACKSPACE",   "Toggle window gaps",     run("omarchy-toggle gaps"))

    -- Info notifications
    bind(mainMod .. " + CTRL + ALT + T",      "Show time",    run("omarchy-notification time"))
    bind(mainMod .. " + CTRL + ALT + B",      "Show battery", run("omarchy-notification battery"))
    bind(mainMod .. " + CTRL + ALT + W",      "Show weather", run("omarchy-notification weather"))

    -- Window management (omarchy bindings/tiling.lua)
    bind(mainMod .. " + W",                   "Close window",        hl.dsp.window.close())
    bind(mainMod .. " + Q",                   "Close window",        hl.dsp.window.close())
    bind(mainMod .. " + J",                   "Toggle window split", hl.dsp.layout("togglesplit"))
    bind(mainMod .. " + P",                   "Pseudo window",       hl.dsp.window.pseudo())
    bind(mainMod .. " + T",                   "Toggle floating",     hl.dsp.window.float({ action = "toggle" }))
    bind(mainMod .. " + F",                   "Full screen",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))
    bind(mainMod .. " + ALT + F",             "Full width",          hl.dsp.window.fullscreen({ mode = "maximized" }))
    bind(mainMod .. " + O",                   "Pop window out (float & pin)", run('hyprctl --batch "dispatch togglefloating ; dispatch pin"'))
    bind(mainMod .. " + L",                   "Toggle workspace layout",      run("omarchy-toggle layout"))

    -- Focus / swap with arrows.
    for key, dir in pairs({ LEFT = "l", RIGHT = "r", UP = "u", DOWN = "d" }) do
        bind(mainMod .. " + " .. key,            "Focus " .. dir, hl.dsp.focus({ direction = dir }))
        -- move (not swap) so a window at the screen edge crosses monitors.
        bind(mainMod .. " + SHIFT + " .. key,    "Move window " .. dir, hl.dsp.window.move({ direction = dir }))
        bind(mainMod .. " + SHIFT + ALT + " .. key, "Move workspace to monitor " .. dir, hl.dsp.workspace.move({ monitor = dir }))
        bind(mainMod .. " + ALT + " .. key,      "Move window into group " .. dir, hl.dsp.window.move({ into_group = dir }))
    end

    -- Workspaces 1-10 (0 = ws 10), globally numbered, pinned to monitors by
    -- autoPinWorkspaces above. SHIFT moves + follows, SHIFT+ALT moves silently.
    for i = 1, 10 do
        local key = i % 10
        bind(mainMod .. " + " .. key,                  "Workspace " .. i,               hl.dsp.focus({ workspace = tostring(i) }))
        bind(mainMod .. " + SHIFT + " .. key,          "Move window to workspace " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
        bind(mainMod .. " + SHIFT + ALT + " .. key,    "Move window silently to workspace " .. i, hl.dsp.window.move({ workspace = tostring(i), follow = false }))
    end

    -- Workspace cycling + former workspace.
    bind(mainMod .. " + TAB",                 "Next workspace",     hl.dsp.focus({ workspace = "e+1" }))
    bind(mainMod .. " + SHIFT + TAB",         "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
    bind(mainMod .. " + CTRL + TAB",          "Former workspace",   hl.dsp.focus({ workspace = "previous" }))

    -- Window cycling (ALT+TAB).
    bind("ALT + TAB",                         "Next window",        hl.dsp.window.cycle_next())
    bind("ALT + TAB",                         "Reveal window",      hl.dsp.window.bring_to_top())
    bind("ALT + SHIFT + TAB",                 "Previous window",    hl.dsp.window.cycle_next({ next = false }))
    bind("ALT + SHIFT + TAB",                 "Reveal window",      hl.dsp.window.bring_to_top())

    -- Scratchpad.
    bind(mainMod .. " + S",                   "Toggle scratchpad",  hl.dsp.workspace.toggle_special("scratchpad"))
    bind(mainMod .. " + ALT + S",             "Move window to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))
    bind(mainMod .. " + grave",               "Toggle scratchpad",  hl.dsp.workspace.toggle_special("scratchpad"))
    bind(mainMod .. " + SHIFT + grave",       "Move window to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

    -- Monitor focus.
    bind("CTRL + ALT + TAB",                  "Next monitor",       hl.dsp.focus({ monitor = "+1" }))
    bind("CTRL + ALT + SHIFT + TAB",          "Previous monitor",   hl.dsp.focus({ monitor = "-1" }))

    -- Resize: -/= a step, ALT a little, CTRL a lot (code:20 = minus, 21 = equal).
    for mods, step in pairs({ [""] = 100, ["ALT + "] = 25, ["CTRL + "] = 300 }) do
        bind(mainMod .. " + " .. mods .. "code:20",            "Shrink window",  hl.dsp.window.resize({ x = -step, y = 0, relative = true }), { repeating = true })
        bind(mainMod .. " + " .. mods .. "code:21",            "Expand window",  hl.dsp.window.resize({ x = step,  y = 0, relative = true }), { repeating = true })
        bind(mainMod .. " + SHIFT + " .. mods .. "code:20",    "Shrink window vertically", hl.dsp.window.resize({ x = 0, y = -step, relative = true }), { repeating = true })
        bind(mainMod .. " + SHIFT + " .. mods .. "code:21",    "Expand window vertically", hl.dsp.window.resize({ x = 0, y = step,  relative = true }), { repeating = true })
    end

    -- Window groups.
    bind(mainMod .. " + G",                   "Toggle window grouping", hl.dsp.group.toggle())
    bind(mainMod .. " + ALT + G",             "Move window out of group", hl.dsp.window.move({ out_of_group = true }))
    bind(mainMod .. " + ALT + TAB",           "Next window in group",     hl.dsp.group.next())
    bind(mainMod .. " + ALT + SHIFT + TAB",   "Previous window in group", hl.dsp.group.prev())
    bind(mainMod .. " + CTRL + LEFT",         "Previous window in group", hl.dsp.group.prev())
    bind(mainMod .. " + CTRL + RIGHT",        "Next window in group",     hl.dsp.group.next())

    -- Mouse: scroll workspaces, drag/resize, cycle group windows.
    bind(mainMod .. " + mouse_down",          "Next workspace",     hl.dsp.focus({ workspace = "e+1" }))
    bind(mainMod .. " + mouse_up",            "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
    bind(mainMod .. " + ALT + mouse_down",    "Next window in group",     hl.dsp.group.next())
    bind(mainMod .. " + ALT + mouse_up",      "Previous window in group", hl.dsp.group.prev())
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- Universal clipboard (omarchy bindings/clipboard.lua): SUPER+C/V/X work
    -- everywhere; kitty gets CTRL+SHIFT translated by the script.
    bind(mainMod .. " + C",                   "Universal copy",     run("omarchy-clipboard copy"))
    bind(mainMod .. " + V",                   "Universal paste",    run("omarchy-clipboard paste"))
    bind(mainMod .. " + X",                   "Universal cut",      run("omarchy-clipboard cut"))
    bind(mainMod .. " + CTRL + V",            "Clipboard history",  run("sh -c 'cliphist list | rofi -dmenu | cliphist decode | wl-copy'"))

    -- Capture.
    bind("PRINT",                             "Screenshot region",  run("omarchy-capture screenshot region"))
    bind("SHIFT + PRINT",                     "Screenshot window",  run("omarchy-capture screenshot window"))
    bind("CTRL + PRINT",                      "Screenshot screen",  run("omarchy-capture screenshot output"))
    bind("ALT + PRINT",                       "Screenrecord",       run("omarchy-capture record"))
    bind(mainMod .. " + PRINT",               "Color picker",       run("omarchy-capture color"))
    bind(mainMod .. " + CTRL + PRINT",        "Extract text (OCR)", run("omarchy-capture ocr"))

    -- Zoom / lock.
    bind(mainMod .. " + CTRL + Z",            "Zoom in",            run("omarchy-zoom in"))
    bind(mainMod .. " + CTRL + ALT + Z",      "Reset zoom",         run("omarchy-zoom reset"))
    bind(mainMod .. " + CTRL + L",            "Lock screen",        run("hyprlock"))

    -- Hardware media keys (locked = works on lock screen); ALT = precise.
    hl.bind("XF86AudioRaiseVolume",        run("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume",        run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
    hl.bind("ALT + XF86AudioRaiseVolume",  run("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+"), { locked = true, repeating = true })
    hl.bind("ALT + XF86AudioLowerVolume",  run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"),      { locked = true, repeating = true })
    hl.bind("XF86AudioMute",               run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
    hl.bind("XF86AudioMicMute",            run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
    hl.bind("XF86MonBrightnessUp",         run("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown",       run("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
    hl.bind("ALT + XF86MonBrightnessUp",   run("brightnessctl -e4 -n2 set 1%+"),                  { locked = true, repeating = true })
    hl.bind("ALT + XF86MonBrightnessDown", run("brightnessctl -e4 -n2 set 1%-"),                  { locked = true, repeating = true })
    hl.bind("XF86AudioNext",  run("playerctl next"),       { locked = true })
    hl.bind("XF86AudioPause", run("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPlay",  run("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPrev",  run("playerctl previous"),   { locked = true })

    ----------------------------------------------------------------- WINDOW RULES
    hl.window_rule({
        name  = "suppress-maximize-events",
        match = { class = ".*" },
        suppress_event = "maximize",
    })

    hl.window_rule({
        name  = "fix-xwayland-drags",
        match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
        no_focus = true,
    })

    -- Floating terminal the Omarchy menu launches things in.
    hl.window_rule({
        name  = "omarchy-floating-terminal",
        match = { class = "^Omarchy-float$" },
        float = true,
        size  = { "60%", "70%" },
        center = true,
    })
    -- translucent kitty is handled by kitty's own background_opacity (desktop.nix)
  '';
in
{
  # Hyprland itself is enabled system-wide via programs.hyprland in
  # modules/common/base.nix; this only provides the user-side config file.
  # Pick .conf vs .lua per Hyprland version (0.52 ignores .lua, 0.55 ignores .conf).
  # headless-only bits (virt-1 monitor, hypremote, wayvnc) live in
  # modules/roles/headless.nix.
  xdg.configFile = lib.mkMerge [
    (lib.mkIf isAsahi   { "hypr/hyprland.conf".text = hyprlandConf; })
    (lib.mkIf (!isAsahi) { "hypr/hyprland.lua".text  = hyprlandLua;  })
  ];

  home.packages = with pkgs; [
    playerctl
    brightnessctl
    networkmanagerapplet
    wl-clipboard
    # On PATH so omarchy-capture (and the capture menu) can call it by name;
    # the binds route through omarchy-capture rather than the store path.
    screenshotScript
  ];
}
