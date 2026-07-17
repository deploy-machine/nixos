# /etc/nixos/cli.nix
# Modern, visually-enhanced CLI tools.
#
# Stylix split: bat, fzf, yazi and lazygit are Stylix targets, so they theme to
# milkoutside automatically (don't set their colours here or it fights Stylix).
# lsd is pulled onto the grayscale ramp below; zoxide, dust, duf, procs, … still
# carry their own palettes, which look fine on GeistMono Nerd Font.
{ config, pkgs, lib, ... }:
let c = import ./colors.nix;
in
{
  # ls -> lsd : icons + colour. enableZshIntegration creates the alias family
  # (ls, ll = -l, la = -A, lt = --tree, lla = -lA, llt = -l --tree).
  # Colors mapped onto the koda-dark grey ramp from colors.nix. Icons stay on
  # the default (auto) so glyphs still render in the terminal.
  # Setting a non-empty `colors` makes home-manager flip color.theme to "custom".
  programs.lsd = {
    enable = true;
    enableZshIntegration = true;
    colors = {
      user  = "#${c.fg}";
      group = "#${c.dim}";
      permission = {
        read        = "#${c.fg}";
        write       = "#${c.fgDim}";
        exec        = "#${c.fgBright}";
        exec-sticky = "#${c.fgBright}";
        no-access   = "#${c.danger}";
        octal       = "#${c.fgDim}";
        acl         = "#${c.dim}";
        context     = "#${c.dim}";
      };
      date = {
        hour-old = "#${c.fgBright}";
        day-old  = "#${c.fg}";
        older    = "#${c.dim}";
      };
      size = {
        none   = "#${c.muted}";
        small  = "#${c.fgDim}";
        medium = "#${c.fg}";
        large  = "#${c.fgBright}";
      };
      inode = {
        valid   = "#${c.fg}";
        invalid = "#${c.muted}";
      };
      tree-edge = "#${c.border}";
      links = {
        valid   = "#${c.fg}";
        invalid = "#${c.danger}";
      };
      git-status = {
        default        = "#${c.fg}";
        unmodified     = "#${c.dim}";
        ignored        = "#${c.muted}";
        new-in-index   = "#${c.success}";
        new-in-workdir = "#${c.success}";
        typechange     = "#${c.warning}";
        deleted        = "#${c.danger}";
        renamed        = "#${c.info}";
        modified       = "#${c.warning}";
        conflicted     = "#${c.danger}";
      };
    };
  };

  # cat -> bat : syntax highlighting. bat is a Stylix target -> auto-themed.
  programs.bat.enable = true;

  # fuzzy finder : Ctrl-R history, Ctrl-T files, ALT-C cd. Stylix-themed.
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # smarter cd : `z partial` jumps to your most-used matching directory.
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];   # uncomment to make `cd` itself frecency-aware
  };
  
  programs.zsh.initContent = lib.mkOrder 1100 ''
    bindkey '^G' fzf-cd-widget
  '';

  # TUI file manager (Stylix-themed). `yy` opens it and cds to the dir you leave in.
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };

  # TUI git client (Stylix-themed)
  programs.lazygit.enable = true;

  # Drop-in visual upgrades, kept under their own names.
  home.packages = with pkgs; [
    dust       # dust     : disk usage as a colour tree    (better du)
    duf        # duf      : disk free as colour tables      (better df)
    procs      # procs    : colourful process table         (better ps)
    gping      # gping    : ping with a live line graph
    glow       # glow     : render Markdown in the terminal
    onefetch   # onefetch : git-repo summary art (run inside a repo)
    tealdeer   # tldr     : concise, example-first man pages
    delta      # delta    : syntax-highlighted git diffs    (wire into git, see notes)
  ];

  home.shellAliases = {
    cat = "bat --paging=never";   # cat-like: highlight, but never invoke the pager
    # optional muscle-memory swaps — uncomment any you want:
    du   = "dust";
    df   = "duf";
    ps   = "procs";
    ping = "gping";
  };
}

