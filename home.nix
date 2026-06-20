{ config, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./desktop.nix
    ./neovim.nix
    ./shell.nix
    ./cli.nix
    ./nixcord.nix
  ];

  home.username = "simbaclaws";
  home.homeDirectory = "/home/simbaclaws";
  home.stateVersion = "26.05"; # set once, then leave it

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    nerd-fonts.geist-mono     # cybr/Stylix monospace: bar, prompt, terminal glyphs
    nerd-fonts.jetbrains-mono # kept as a secondary monospace
    nerd-fonts.symbols-only   # glyph fallback so no icon ever renders as tofu
    # cybr-style terminal stack (Stylix themes these automatically)
    cava        # audio visualizer
    btop        # system monitor
    fastfetch   # system info
  ];

  # --- Stylix scope control --------------------------------------------------
  # Stylix auto-enables every supported target. These already have bespoke
  # milkoutside/cybr configs and would conflict or get double-themed, so exclude
  # them. EVERYTHING ELSE (gtk, qt, console, cursor, bat, btop, cava, fzf, mpv,
  # firefox, chromium, vscode, …) is themed by Stylix from the palette in stylix.nix.
  stylix.targets = {
    waybar.enable   = false;  # custom cybr powerline bar  -> waybar.nix
    kitty.enable    = false;  # milkoutside kitty          -> desktop.nix
    rofi.enable     = false;  # milkoutside rofi           -> desktop.nix
    swaync.enable   = false;  # milkoutside swaync         -> desktop.nix
    starship.enable = false;  # cybr prompt                -> shell.nix
    hyprland.enable = false;  # raw-lua hyprland, hand-coloured
    neovim.enable   = false;  # milkoutside.nvim via LazyVim
  };

  # From earlier, fold in if you want them here:
  # programs.git = { enable = true; userName = "Hylke Hellinga"; userEmail = "you@example.com"; };
  # programs.direnv = { enable = true; nix-direnv.enable = true; };
}

