{ config, pkgs, ... }:
let c = import ./colors.nix;
in
{
  # ---------------- kitty ----------------
  programs.kitty = {
    enable = true;
    font = { name = "JetBrainsMono Nerd Font"; size = 12; };
    settings = {
      background = "#${c.bg}";
      foreground = "#${c.fg}";
      cursor = "#${c.red}";
      cursor_text_color = "#${c.bg}";
      selection_background = "#${c.selection}";
      selection_foreground = "#${c.fg}";
      url_color = "#${c.cyan}";
      active_border_color = "#${c.red}";
      inactive_border_color = "#${c.border}";
      active_tab_background = "#${c.bg}";
      active_tab_foreground = "#${c.red}";
      inactive_tab_background = "#${c.bgAlt}";
      inactive_tab_foreground = "#${c.comment}";
      background_opacity = "0.92";

      # 16 terminal colors (milkoutside terminal table)
      color0 = "#000000"; color8 = "#303030";
      color1 = "#f93a82"; color9 = "#f93a82";
      color2 = "#92cf9c"; color10 = "#5dd48c";
      color3 = "#f8e063"; color11 = "#ffad00";
      color4 = "#63c3dd"; color12 = "#4fd1e0";
      color5 = "#e79cfb"; color13 = "#ff007c";
      color6 = "#7dcfff"; color14 = "#62b9e8";
      color7 = "#e0e0e0"; color15 = "#e8e8e8";
    };
  };

  # ---------------- rofi ----------------
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    theme = "${config.xdg.configHome}/rofi/milkoutside.rasi";
  };

  xdg.configFile."rofi/milkoutside.rasi".text = ''
    * {
        bg:      #${c.bg};
        bg-alt:  #${c.bgAlt};
        fg:      #${c.fg};
        accent:  #${c.red};
        muted:   #${c.comment};
        background-color: transparent;
        text-color: @fg;
    }
    window {
        background-color: @bg;
        border: 2px;
        border-color: @accent;
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
      * {
        font-family: "JetBrainsMono Nerd Font";
        background: transparent;
      }
      .control-center {
        background: #${c.bg};
        border: 2px solid #${c.red};
        border-radius: 12px;
        margin: 12px;
        padding: 10px;
      }
      .notification {
        background: #${c.bgAlt};
        border-left: 3px solid #${c.red};
        border-radius: 8px;
        margin: 6px;
        padding: 6px;
      }
      .notification-content { color: #${c.fg}; padding: 6px; }
      .summary { color: #${c.red}; font-weight: bold; }
      .body { color: #${c.fgDim}; }
      .close-button {
        background: #${c.red};
        color: #${c.bg};
        border-radius: 4px;
      }
      .control-center .widget-title { color: #${c.cyan}; }
      .control-center .notification.critical {
        border-left: 3px solid #${c.red1};
      }
    '';
  };
}

