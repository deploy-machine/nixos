{ config, lib, pkgs, ... }:
let c = import ./colors.nix;
in
{
  # ---------------- desktop packages ----------------
  # Default apps wired in via xdg.mimeApps below, plus the Wayland screenshot
  # / recording / picker / mixer toolchain bound to keys in hyprland.nix, and
  # the "every desktop should have this" GUI set. Two guards on the latter:
  #   - unrar is unfree; skipped on FOSS-only hosts.
  #   - onlyoffice + tutanota-desktop are upstream-binary x86_64-only;
  #     skipped on aarch64 (e.g. M1 / Asahi). Pick libreoffice-fresh /
  #     thunderbird in a host override if you need replacements there.
  home.packages = with pkgs; [
    mpv             # default video + audio player
    imv             # wayland-native image viewer
    zathura         # vim-like PDF viewer

    grim slurp      # screenshot primitives (grab + region selector)
    hyprshot        # convenience wrapper: window / region / output -> file + clipboard
    wf-recorder     # screen recording

    hyprpicker      # screen color eyedropper (clipboard-copies hex)
    cliphist        # clipboard history daemon (binary; service below)

    pavucontrol         # per-app audio mixer
    gnome-disk-utility  # partition / format / SMART (binary is `gnome-disks`)

    # Office / productivity
    gnome-calendar             # ICS + Evolution data server calendar
    qalculate-gtk              # full-featured desktop calculator
    gnome-text-editor          # GUI text editor (mime default for text/plain)

    # Security
    bitwarden-desktop          # password manager

    # System / files
    baobab                     # GUI disk-usage analyzer
    mission-center             # GUI system monitor (CPU/RAM/GPU/net)
    satty                      # screenshot annotator (used by the screenshot wrapper)
    p7zip zip                  # archive backends for thunar-archive-plugin

    # Media creation / editing
    gimp                       # raster image editor
    inkscape                   # vector image editor
    blender                    # 3D / animation / video sequencer
    obs-studio                 # screen recording + streaming
    audacity                   # audio editor

    # Media download
    yt-dlp                     # youtube + a thousand other sites
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    onlyoffice-desktopeditors  # docx/xlsx/pptx editor (x86_64 binary upstream)
    tutanota-desktop           # encrypted email (x86_64 Electron upstream)
  ] ++ lib.optionals (pkgs.stdenv.hostPlatform.isx86_64
                  && (pkgs.config.allowUnfree or false)) [
    # zoom-us is upstream x86_64 + unfree. On aarch64 (Asahi) it ships via the
    # muvm-zoom wrapper in modules/roles/gaming-asahi.nix instead.
    zoom-us
  ] ++ lib.optionals (pkgs.config.allowUnfree or false) [
    unrar                      # .rar extraction (unfree license)
  ];

  # Make sure ~/Pictures, ~/Videos, ~/Documents etc. exist — hyprshot
  # writes to $XDG_PICTURES_DIR, wf-recorder writes to ~/Videos in the bind.
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # ---------------- udiskie (automount) ----------------
  # Auto-mount removable drives the moment they're plugged in, regardless of
  # whether Thunar is open. Pairs with services.udisks2 + thunar-volman in
  # modules/roles/desktop.nix. tray = "auto" only shows the indicator when
  # something is actually mounted.
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "auto";
  };

  # ---------------- polkit auth agent ----------------
  # Pops up the GUI password dialog whenever something (udisks2, systemctl,
  # NetworkManager, …) hits a polkit rule that needs "active session +
  # password". Without this, requests from Thunar to mount a drive come back
  # as "not authorized" because polkit can't reach a user-facing agent.
  # Started by uwsm via graphical-session.target.
  systemd.user.services.hyprpolkitagent = {
    Unit = {
      Description = "Hyprland polkit authentication agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # ---------------- kitty ----------------
  # Full greyscale terminal. Every ANSI slot is a luminance step so TUI
  # apps still differentiate categories, but nothing renders in color.
  # color1/9 (ANSI red — errors) is the brightest so critical output
  # still stands out.
  programs.kitty = {
    enable = true;
    font = { name = "JetBrainsMono Nerd Font"; size = 12; };
    settings = {
      background = "#${c.bg}";
      foreground = "#${c.fg}";
      cursor = "#${c.fgBright}";
      cursor_text_color = "#${c.bg}";
      selection_background = "#${c.selection}";
      selection_foreground = "#${c.fgBright}";
      url_color = "#${c.fgBright}";
      active_border_color = "#${c.border}";
      inactive_border_color = "#${c.bgAlt}";
      active_tab_background = "#${c.bg}";
      active_tab_foreground = "#${c.fgBright}";
      inactive_tab_background = "#${c.bgAlt}";
      inactive_tab_foreground = "#${c.comment}";
      background_opacity = "0.92";
      window_padding_width = 8;

      # ANSI 16 — pure grey ramp. Normal (0..7) sits in the mid range;
      # bright (8..15) is one luminance step higher. color1/9 is the
      # brightest so `ls` errors, git-diff removals, and other "red"
      # signals still catch the eye.
      color0  = "#0a0a0a"; color8  = "#3a3a3a";
      color1  = "#d0d0d0"; color9  = "#e8e8e8";
      color2  = "#808080"; color10 = "#a0a0a0";
      color3  = "#c0c0c0"; color11 = "#d0d0d0";
      color4  = "#909090"; color12 = "#b0b0b0";
      color5  = "#a0a0a0"; color13 = "#c0c0c0";
      color6  = "#b0b0b0"; color14 = "#c8c8c8";
      color7  = "#b0b0b0"; color15 = "#d0d0d0";
    };
  };

  # ---------------- rofi ----------------
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    theme = "${config.xdg.configHome}/rofi/milkoutside.rasi";
  };

  xdg.configFile."rofi/milkoutside.rasi".text = ''
    /* Full greyscale launcher — prompt caret and selected row are
     * bright grey; everything else is a darker step. */
    * {
        bg:       #${c.bg};
        bg-alt:   #${c.bgAlt};
        surface:  #${c.surface};
        fg:       #${c.fg};
        accent:   #${c.red};
        border:   #${c.border};
        muted:    #${c.muted};
        background-color: transparent;
        text-color: @fg;
    }
    window {
        background-color: @bg;
        border: 1px;
        border-color: @border;
        border-radius: 8px;
        width: 600px;
        padding: 16px;
    }
    inputbar {
        background-color: @bg-alt;
        border-radius: 4px;
        padding: 10px;
        margin: 0 0 10px 0;
        children: [ prompt, entry ];
    }
    prompt { text-color: @accent; margin: 0 8px 0 0; }
    entry  { placeholder: "search…"; placeholder-color: @muted; }
    listview { lines: 8; scrollbar: false; }
    element { padding: 8px; border-radius: 4px; }
    element selected { background-color: @accent; text-color: @bg; }
    element-text { background-color: transparent; text-color: inherit; }
    element-icon { size: 1.2em; margin: 0 8px 0 0; }
  '';

  # ---------------- swaync (replaces dunst; cybr-style) ----------------
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      control-center-width = 380;
      notification-window-width = 380;
      timeout = 8;
      timeout-low = 4;
      timeout-critical = 0;
      fit-to-screen = true;
      widgets = [ "title" "dnd" "notifications" "mpris" ];
    };
    style = ''
      /* Full greyscale notifications. Bright grey is used for the
       * close-button and critical-notification border so the "look
       * at this" hint still lands by luminance.
       */
      * {
        font-family: "JetBrainsMono Nerd Font";
        background: transparent;
      }
      .control-center {
        background: #${c.bg};
        border: 1px solid #${c.border};
        border-radius: 12px;
        margin: 12px;
        padding: 10px;
      }
      .notification {
        background: #${c.bgAlt};
        border-left: 3px solid #${c.border};
        border-radius: 8px;
        margin: 6px;
        padding: 6px;
      }
      .notification-content { color: #${c.fg}; padding: 6px; }
      .summary { color: #${c.fgBright}; font-weight: bold; }
      .body { color: #${c.fgDim}; }
      .close-button {
        background: #${c.red};
        color: #${c.bg};
        border-radius: 4px;
      }
      .control-center .widget-title { color: #${c.fgDim}; }
      .control-center .notification.critical {
        border-left: 3px solid #${c.red};
      }
    '';
  };

  # ---------------- hyprlock (screen locker) ----------------
  # Triggered by ALT+CTRL+L (manual) or by hypridle on inactivity. Themed in
  # the milkoutside palette: pink/red outline around the input field, big
  # JetBrains-style clock on top.
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor         = true;
        grace               = 0;
        disable_loading_bar = true;
        no_fade_in          = false;
      };

      background = lib.mkForce [{
        monitor     = "";
        path        = "${config.home.homeDirectory}/Wallpapers/nixos.png";
        blur_passes = 3;
        blur_size   = 8;
      }];

      label = lib.mkForce [
        {
          monitor     = "";
          text        = "$TIME";
          color       = "rgba(${c.fgBright}ff)";
          font_size   = 96;
          font_family = "GeistMono Nerd Font Bold";
          position    = "0, 220";
          halign      = "center";
          valign      = "center";
        }
        {
          monitor     = "";
          text        = ''cmd[update:43200000] date +"%A, %d %B"'';
          color       = "rgba(${c.fg}cc)";
          font_size   = 22;
          font_family = "GeistMono Nerd Font";
          position    = "0, 140";
          halign      = "center";
          valign      = "center";
        }
      ];

      # Input field: grey outline; check_color (verifying passphrase)
      # is bright grey — a "doing something" hint via luminance only.
      input-field = lib.mkForce [{
        monitor           = "";
        size              = "320, 56";
        outline_thickness = 2;
        dots_size         = 0.2;
        dots_spacing      = 0.3;
        dots_center       = true;
        outer_color       = "rgba(${c.border}ff)";
        inner_color       = "rgba(${c.bgAlt}d9)";
        font_color        = "rgba(${c.fg}ff)";
        check_color       = "rgba(${c.red}ff)";
        fail_color        = "rgba(${c.danger}ff)";
        capslock_color    = "rgba(${c.warning}ff)";
        fade_on_empty     = false;
        placeholder_text  = "<i>Password…</i>";
        hide_input        = false;
        position          = "0, -80";
        halign            = "center";
        valign            = "center";
      }];
    };
  };

  # ---------------- hypridle (idle daemon) ----------------
  # 5 min: dim. 10 min: lock. 11 min: screen off. 30 min: suspend.
  # before_sleep_cmd ensures we lock *before* suspending so resuming a
  # closed laptop / desktop wake doesn't briefly show the unlocked session.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd         = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd  = "hyprctl dispatch dpms on";
      };
      listener = [
        { timeout = 300;  on-timeout = "brightnessctl -s set 10%"; on-resume = "brightnessctl -r"; }
        { timeout = 600;  on-timeout = "loginctl lock-session"; }
        { timeout = 660;  on-timeout = "hyprctl dispatch dpms off"; on-resume = "hyprctl dispatch dpms on"; }
        { timeout = 1800; on-timeout = "systemctl suspend"; }
      ];
    };
  };

  # ---------------- blueman tray applet ----------------
  # The system role enables services.blueman (the bluetoothd front-end);
  # this is the user-facing tray applet that surfaces pairing requests and
  # device toggles. Without it, the bluetoothd daemon runs but you have no
  # GUI handle on it from Hyprland.
  services.blueman-applet.enable = true;

  # ---------------- cliphist (clipboard history) ----------------
  # wl-paste --watch cliphist store runs as a user service. Recall via
  # ALT+SHIFT+V (piped through rofi in hyprland.nix).
  services.cliphist.enable = true;

  # ---------------- hyprsunset (blue-light filter) ----------------
  # Fixed warm temperature all day. Simpler than day/night transitions and
  # easy on the eyes; switch to settings.profile if you want it adaptive.
  services.hyprsunset = {
    enable = true;
    extraArgs = [ "-t" "4500" ];
  };

  # ---------------- default applications ----------------
  # Resolves what xdg-open / "Open With…" / chromium "download then open"
  # actually launches. chromium-browser.desktop only resolves when chromium
  # is installed (allowUnfree host); otherwise these handlers fall back to
  # whatever xdg-mime guesses.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = let
      image = "imv.desktop";
      pdf   = "org.pwmt.zathura.desktop";
      av    = "mpv.desktop";
      web   = "chromium-browser.desktop";
      files = "thunar.desktop";
      text  = "org.gnome.TextEditor.desktop";
    in {
      "inode/directory"          = files;

      "x-scheme-handler/http"    = web;
      "x-scheme-handler/https"   = web;
      "x-scheme-handler/about"   = web;
      "x-scheme-handler/unknown" = web;
      "text/html"                = web;

      "text/plain"               = text;
      "text/markdown"            = text;
      "application/json"         = text;
      "application/xml"          = text;

      "application/pdf"          = pdf;

      "image/jpeg"               = image;
      "image/png"                = image;
      "image/gif"                = image;
      "image/webp"               = image;
      "image/svg+xml"            = image;
      "image/bmp"                = image;
      "image/tiff"               = image;

      "video/mp4"                = av;
      "video/x-matroska"         = av;
      "video/webm"               = av;
      "video/x-msvideo"          = av;
      "video/quicktime"          = av;

      "audio/mpeg"               = av;
      "audio/flac"               = av;
      "audio/ogg"                = av;
      "audio/wav"                = av;
      "audio/x-vorbis+ogg"       = av;
    };
  };
}

