{ config, lib, pkgs, ... }:
let
  c = import ./colors.nix;
  wallpaper = "${config.home.homeDirectory}/Wallpapers/nixos.png";

  # 26.05 renamed swww → awww; 25.11 still ships swww. The CLIs are
  # identical (`<bin> img <path>`, `<bin>-daemon`) so the autostart lines
  # below just interpolate this name. (pkgs.swww on 26.05 is an alias to
  # awww with a deprecation warning, so we check awww first.)
  wallpaperBin = if pkgs ? awww then "awww" else "swww";

  # Hyprland 0.55 (26.05 channel) loads ~/.config/hypr/hyprland.lua natively;
  # Hyprland 0.52 (25.11 channel, Asahi) does NOT — it silently ignores .lua
  # and generates an autogen .conf. Pick the right format per channel.
  # Asahi laptops also have an Apple Cmd key that maps to Super, so SUPER is
  # the natural modifier there; x86 keyboards lack it, so ALT stays.
  isAsahi = pkgs.stdenv.hostPlatform.isAarch64;
  mainMod = if isAsahi then "SUPER" else "ALT";

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
    exec-once = bash -c 'sleep 6 && ${wallpaperBin} img ${wallpaper}'
    exec-once = nm-applet --indicator
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
        col.active_border = rgb(${c.red}) rgb(${c.red1}) 45deg
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
            color = 0xaa${c.red}
            color_inactive = 0x661a1a1a
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

    gestures {
        workspace_swipe = true
        workspace_swipe_fingers = 3
    }

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
    # Programs (single-letter mnemonics).
    bind = $mainMod,         Q, killactive
    bind = $mainMod SHIFT,   Q, exit
    bind = $mainMod,         T, exec, $terminal
    bind = $mainMod,         R, exec, $menu
    bind = $mainMod SHIFT,   F, exec, $fileManager
    bind = $mainMod,         B, exec, chromium
    bind = $mainMod,         D, exec, vesktop
    bind = $mainMod,         A, exec, pavucontrol
    bind = $mainMod,         P, exec, bitwarden
    bind = $mainMod,         N, exec, swaync-client -t -sw
    bind = $mainMod,         C, exec, hyprpicker -a

    # Window management
    bind = $mainMod,         F, fullscreen
    bind = $mainMod,         V, togglefloating
    bind = $mainMod SHIFT,   T, togglesplit

    # Focus: vim h/j/k/l + arrow fallback.
    bind = $mainMod,         h, movefocus, l
    bind = $mainMod,         l, movefocus, r
    bind = $mainMod,         k, movefocus, u
    bind = $mainMod,         j, movefocus, d
    bind = $mainMod,      left, movefocus, l
    bind = $mainMod,     right, movefocus, r
    bind = $mainMod,        up, movefocus, u
    bind = $mainMod,      down, movefocus, d

    # Move (within current monitor; cross-monitor "throw" is implicit via
    # the pinned workspace layout — SHIFT+N moves the window to ws N).
    bind = $mainMod SHIFT,   h, movewindow, l
    bind = $mainMod SHIFT,   l, movewindow, r
    bind = $mainMod SHIFT,   k, movewindow, u
    bind = $mainMod SHIFT,   j, movewindow, d
    bind = $mainMod SHIFT, left, movewindow, l
    bind = $mainMod SHIFT, right, movewindow, r
    bind = $mainMod SHIFT, up,    movewindow, u
    bind = $mainMod SHIFT, down,  movewindow, d

    # Workspaces 1-10 (0 = ws 10). Workspaces are globally numbered and
    # pinned to specific monitors via the pin script in autostart.
    bind = $mainMod,         1, workspace, 1
    bind = $mainMod,         2, workspace, 2
    bind = $mainMod,         3, workspace, 3
    bind = $mainMod,         4, workspace, 4
    bind = $mainMod,         5, workspace, 5
    bind = $mainMod,         6, workspace, 6
    bind = $mainMod,         7, workspace, 7
    bind = $mainMod,         8, workspace, 8
    bind = $mainMod,         9, workspace, 9
    bind = $mainMod,         0, workspace, 10
    bind = $mainMod SHIFT,   1, movetoworkspace, 1
    bind = $mainMod SHIFT,   2, movetoworkspace, 2
    bind = $mainMod SHIFT,   3, movetoworkspace, 3
    bind = $mainMod SHIFT,   4, movetoworkspace, 4
    bind = $mainMod SHIFT,   5, movetoworkspace, 5
    bind = $mainMod SHIFT,   6, movetoworkspace, 6
    bind = $mainMod SHIFT,   7, movetoworkspace, 7
    bind = $mainMod SHIFT,   8, movetoworkspace, 8
    bind = $mainMod SHIFT,   9, movetoworkspace, 9
    bind = $mainMod SHIFT,   0, movetoworkspace, 10

    # Scroll through workspaces with $mainMod + scroll wheel.
    bind = $mainMod, mouse_down, workspace, e+1
    bind = $mainMod, mouse_up,   workspace, e-1

    # Drag / resize with $mainMod + LMB/RMB.
    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow

    # Screenshots: hyprshot --raw -> satty -> ~/Pictures + clipboard + notification.
    bind = $mainMod,         S, exec, ${screenshotScript}/bin/screenshot region
    bind = $mainMod SHIFT,   S, exec, ${screenshotScript}/bin/screenshot output
    bind = $mainMod CTRL,    S, exec, ${screenshotScript}/bin/screenshot window

    # Screen recording toggle (R is rofi, so this is on SHIFT+R).
    bind = $mainMod SHIFT,   R, exec, sh -c "pgrep wf-recorder >/dev/null && pkill -SIGINT wf-recorder || (mkdir -p $HOME/Videos && wf-recorder -f $HOME/Videos/$(date +%F-%H%M%S).mp4)"

    # Clipboard history (cliphist watcher started by the HM service).
    bind = $mainMod SHIFT,   V, exec, sh -c 'cliphist list | rofi -dmenu | cliphist decode | wl-copy'

    # Manual screen lock.
    bind = $mainMod CTRL,    L, exec, hyprlock

    # Hardware media keys (l = locked, e = repeat).
    bindle = , XF86AudioRaiseVolume,  exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
    bindle = , XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindl  = , XF86AudioMute,         exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindl  = , XF86AudioMicMute,      exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    bindle = , XF86MonBrightnessUp,   exec, brightnessctl -e4 -n2 set 5%+
    bindle = , XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-
    bindl  = , XF86AudioNext,         exec, playerctl next
    bindl  = , XF86AudioPause,        exec, playerctl play-pause
    bindl  = , XF86AudioPlay,         exec, playerctl play-pause
    bindl  = , XF86AudioPrev,         exec, playerctl previous

    ######################################################## WINDOW RULES
    windowrulev2 = suppressevent maximize, class:.*
    windowrulev2 = nofocus, class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0
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
      hl.exec_cmd("bash -c 'sleep 6 && ${wallpaperBin} img ${wallpaper}'")
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
            end
        end
    end

    -- Call inline so `hyprctl reload` re-pins immediately (monitors are already
    -- up). The event hooks below cover cold boot (monitors come up after the
    -- config parses) and hot-plug.
    autoPinWorkspaces()
    hl.on("monitor.added",   autoPinWorkspaces)
    hl.on("monitor.removed", autoPinWorkspaces)

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
                -- signature milkoutside red gradient
                active_border   = { colors = {"rgb(${c.red})", "rgb(${c.red1})"}, angle = 45 },
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
                color          = 0xaa${c.red},   -- red neon glow on the active window
                color_inactive = 0x661a1a1a,
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
    -- Adopted from the omarchy hyprland setup, but everything goes through
    -- Hyprland's native Lua dispatchers (hl.dsp.*) — Hyprland 0.55's
    -- `hyprctl dispatch` evaluates its argument as Lua (`hl.dispatch(<arg>)`),
    -- so shelling out with `hl.dsp.exec_cmd("hyprctl dispatch movewindow l")`
    -- becomes `return hl.dispatch(movewindow l)` and silently errors out.
    local mainMod = "${mainMod}"

    -- Programs (single-letter mnemonics: Q=quit, T=terminal, R=rofi,
    -- B=browser, D=discord, A=audio, P=password, N=notifications,
    -- C=color picker, S=screenshot, F=fullscreen, V=float; SHIFT+F=files).
    hl.bind(mainMod .. " + Q",          hl.dsp.window.close())                          -- Quit focused window
    hl.bind(mainMod .. " + SHIFT + Q",  hl.dsp.exit())                                  -- Quit Hyprland session
    hl.bind(mainMod .. " + T",          hl.dsp.exec_cmd(terminal))                      -- Terminal
    hl.bind(mainMod .. " + R",          hl.dsp.exec_cmd(menu))                          -- Rofi launcher
    hl.bind(mainMod .. " + SHIFT + F",  hl.dsp.exec_cmd(fileManager))                   -- File manager
    hl.bind(mainMod .. " + B",          hl.dsp.exec_cmd("chromium"))                    -- Browser
    hl.bind(mainMod .. " + D",          hl.dsp.exec_cmd("vesktop"))                     -- Discord (nixcord)
    hl.bind(mainMod .. " + A",          hl.dsp.exec_cmd("pavucontrol"))                 -- Audio mixer
    hl.bind(mainMod .. " + P",          hl.dsp.exec_cmd("bitwarden"))                   -- Password manager
    hl.bind(mainMod .. " + N",          hl.dsp.exec_cmd("swaync-client -t -sw"))        -- Notification center toggle
    hl.bind(mainMod .. " + C",          hl.dsp.exec_cmd("hyprpicker -a"))               -- Color picker

    -- Window management
    hl.bind(mainMod .. " + F",          hl.dsp.window.fullscreen())                     -- Fullscreen
    hl.bind(mainMod .. " + V",          hl.dsp.window.float({ action = "toggle" }))     -- toggle float
    hl.bind(mainMod .. " + SHIFT + T",  hl.dsp.layout("togglesplit"))                   -- swap dwindle split axis

    -- Focus: vim-motion (h/j/k/l) plus arrow-key fallback.
    local function focus(key, dir)
        hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
    end
    focus("h", "l"); focus("l", "r"); focus("k", "u"); focus("j", "d")
    focus("left", "l"); focus("right", "r"); focus("up", "u"); focus("down", "d")

    -- Move: mainMod + SHIFT + dir slides the focused window inside the current
    -- monitor. Cross-monitor "throw" is implicit via the pinned workspace
    -- layout — mainMod+SHIFT+N below moves the window to ws N, which lives on
    -- whichever monitor owns N.
    local function mv(key, dir)
        hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
    end
    mv("h", "l"); mv("l", "r"); mv("k", "u"); mv("j", "d")
    mv("left", "l"); mv("right", "r"); mv("up", "u"); mv("down", "d")

    -- Workspaces 1-10 (0 = ws 10). Workspaces are globally numbered and pinned
    -- to specific monitors via hl.workspace_rule in monitors.lua (per-host).
    -- mainMod+N focuses ws N — focus jumps to whichever monitor owns it.
    for i = 1, 10 do
        local key = i % 10
        hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
        hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
    end

    -- Scroll through workspaces with mainMod + scroll wheel.
    hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

    -- Drag / resize with mainMod + LMB/RMB.
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- Screenshots: hyprshot --raw -> satty (annotate UI) -> ~/Pictures/
    -- and clipboard, then a click-to-open notification. Hit Enter inside
    -- satty to save without annotating.
    --   mainMod+S            region
    --   mainMod+SHIFT+S      whole monitor
    --   mainMod+CTRL+S       focused window
    hl.bind(mainMod .. " + S",            hl.dsp.exec_cmd("${screenshotScript}/bin/screenshot region"))
    hl.bind(mainMod .. " + SHIFT + S",    hl.dsp.exec_cmd("${screenshotScript}/bin/screenshot output"))
    hl.bind(mainMod .. " + CTRL + S",     hl.dsp.exec_cmd("${screenshotScript}/bin/screenshot window"))

    -- Screen recording toggle (R is rofi, so this lives on SHIFT+R). First
    -- press starts wf-recorder writing to ~/Videos/<timestamp>.mp4; second
    -- press sends SIGINT so wf-recorder finalises the file cleanly.
    hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(
        'sh -c "pgrep wf-recorder >/dev/null && pkill -SIGINT wf-recorder || ' ..
        '(mkdir -p $HOME/Videos && wf-recorder -f $HOME/Videos/$(date +%F-%H%M%S).mp4)"'
    ))

    -- Clipboard history. cliphist's wl-paste watcher is started by the
    -- home-manager service; this just fans the list through rofi.
    hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(
        "sh -c 'cliphist list | rofi -dmenu | cliphist decode | wl-copy'"
    ))

    -- Manual screen lock. hypridle also calls hyprlock on the 10-minute
    -- idle listener; this is the explicit "I'm leaving" hotkey.
    hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"))

    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
    hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
    hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
    hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
    hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

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
  ];
}
