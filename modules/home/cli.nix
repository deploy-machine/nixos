# /etc/nixos/cli.nix
# Modern, visually-enhanced CLI tools.
#
# Stylix split: bat, fzf, yazi and lazygit are Stylix targets, so they theme to
# milkoutside automatically (don't set their colours here or it fights Stylix).
# lsd, zoxide, dust, duf, procs, … carry their own palettes, which look great now
# that GeistMono Nerd Font is the system monospace.
{ config, pkgs, lib, ... }:
{
  # ls -> lsd : icons + colour. enableZshIntegration creates the alias family
  # (ls, ll = -l, la = -A, lt = --tree, lla = -lA, llt = -l --tree).
  programs.lsd = {
    enable = true;
    enableZshIntegration = true;
    # lsd's default theme is good; tweak via settings/colors if you ever want to.
    # settings = { date = "relative"; };
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

