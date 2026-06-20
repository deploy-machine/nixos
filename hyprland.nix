{ config, lib, pkgs, ... }:
let
  c = import ./colors.nix;
  wallpaper = "${config.home.homeDirectory}/Wallpapers/nixos.png";
in
{
  # Hyprland 0.55 loads ~/.config/hypr/hyprland.lua (native Lua) and does NOT fall
  # back to hyprland.conf. home-manager's Lua generator still mistranslates the
  # hyprlang $variables, so we write the native Lua config directly instead of using
  # wayland.windowManager.hyprland.settings. Hyprland itself is enabled system-wide
  # via programs.hyprland in configuration.nix; this only provides the config file.
  xdg.configFile."hypr/hyprland.lua".text = ''
    -- milkoutside / cyberpunk Hyprland config (native Lua, Hyprland 0.55+)

    local terminal    = "kitty"
    local fileManager = "dolphin"
    local menu        = "rofi -show drun -show-icons"

    ----------------------------------------------------------------- AUTOSTART
    hl.on("hyprland.start", function ()
      hl.exec_cmd("awww-daemon")
      hl.exec_cmd("bash -c 'sleep 6 && awww img ${wallpaper}'")
      hl.exec_cmd("nm-applet --indicator")
      hl.exec_cmd("sleep 6 && systemctl --user start wayvnc.service")
      hl.exec_cmd("waybar")
      hl.exec_cmd("swaync")
    end)
    -- waybar + swaync autostart via their home-manager systemd user services.

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
            kb_options = "",
            kb_rules   = "",
            follow_mouse = 1,
            sensitivity = 0,
            touchpad = {
                natural_scroll = false,
            },
        },
    })

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
    local mainMod = "ALT"

    hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
    hl.bind(mainMod .. " + C", hl.dsp.window.close())
    hl.bind(mainMod .. " + M", hl.dsp.exit())
    hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
    hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
    hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
    hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

    hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
    hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
    hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

    for i = 1, 10 do
        local key = i % 10
        hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
        hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
    end

    hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

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

  home.packages = with pkgs; [
    playerctl
    brightnessctl
    networkmanagerapplet
    kdePackages.dolphin
    wl-clipboard
  ];
}

