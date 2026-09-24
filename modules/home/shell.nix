# /etc/nixos/shell.nix
# zsh + starship. Starship is shell-agnostic; cybr ships it for fish, here it
# drives zsh (you asked for zsh). Prompt = cybr "lucid", coloured by the active Omarchy theme.
#
# Requires in configuration.nix (system-level, for the login shell):
#   programs.zsh.enable = true;
#   users.users.simbaclaws.shell = pkgs.zsh;
#
# NOTE: stylix.targets.starship is disabled in home.nix so Stylix doesn't write a
# competing prompt config.
{ config, pkgs, inputs, ... }:
let c = import ./colors.nix inputs;
in
{
  home.packages = with pkgs; [ starship ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;
    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      share = true;
    };
    # starship owns the prompt (HM 25.05+ uses initContent; older HM: initExtra)
    initContent = ''eval "$(starship init zsh)"'';

    # `nrs` = "nixos rebuild switch". Wraps the two-step ritual this repo
    # needs on every rebuild:
    #   1. `nix flake update config-repo` — /etc/nixos uses a path: input to
    #      /home/simbaclaws/nixos, and Nix locks path inputs by content
    #      hash. Without this step the lock keeps serving stale content,
    #      so edits under this repo silently don't apply. Documented in
    #      the flake-lock-path-input-gotcha memory.
    #   2. `nixos-rebuild switch --impure` — --impure is needed on the
    #      Asahi host because apple-silicon-support pulls firmware from
    #      /etc/nixos at eval time; a pure build would refuse to read it.
    # Runs both under a single sudo so you're prompted for a password once.
    shellAliases = {
      nrs = "sudo sh -c 'nix flake update config-repo --flake /etc/nixos && nixos-rebuild switch --flake /etc/nixos --impure'";
    };
  };

  # Exact cybr prompt, glyphs preserved; palette follows the active theme.
  xdg.configFile."starship.toml".text = ''
# ---------------------------------------
# cybr-starship    lucid theme for starship
# Project:         https://github.com/cybrcore/cybr-starship
# Author:          scherrer-txt   |   License:     GPL-3.0
# Source:          ~/.config/starship/cybrcore.toml
# ---------------------------------------

scan_timeout = 100

format = """
$username\
[](fg:no1 bg:re2)\
$shell\
[](fg:re2 bg:re0)\
$directory\
[](fg:re0)\
$git_branch\
$git_status\
$c\
$elixir\
$elm\
$golang\
$gradle\
$haskell\
$java\
$julia\
$nim\
$rust\
$scala\
$docker_context\
$time\
$line_break$character
"""

palette = "omarchy"

[username]
show_always = true
style_user = "bg:no1 fg:re0"
format = '[ $user ]($style)'
disabled = false

[shell]
style = "bg:re2 fg:re0"
format = '[ $indicator ]($style)'
disabled = false

[directory]
style = "fg:re2 bg:re0"
format = "[ $path ](bold $style)"
truncation_length = 3
truncation_symbol = "…/"

[line_break]
disabled = false

[jobs]
disabled = true

[character]
success_symbol = "[❯ ](fg:re0)"
error_symbol = "[](fg:re0)"
vicmd_symbol = "[󰆤](fg:ye0)"
format = "$symbol"

[time]
disabled = false
time_format = "%R" # Hour:Minute Format
style = "fg:cy0 bg:cy2"
format = '[](fg:cy2)[ $time ]($style)[](fg:cy2)'

[custom.time_arrow]
disabled = false
command = 'echo -n ""'
when = 'true'
style = "fg:cy2"
format = '[ $output]($style)'

[custom.transient_time]
disabled = false
command = 'date "+%H:%M"'
when = 'true'
style = "fg:cy0 bg:cy2"
format = '[ $output ]($style)'

# Palette from the active Omarchy theme (modules/omarchy/theme.nix). Each
# segment is a pill: <x>0 is its colour, <x>2 the dark fill behind it.
# `re0` is the accent, so the directory block and the prompt caret land
# as the visual anchor.
[palettes.omarchy]
no0 = "#${c.bg}"
no1 = "#${c.bgAlt}"

re0 = "#${c.accent}"
re2 = "#${c.border}"

gr0 = "#${c.green}"
gr2 = "#${c.surface}"
ye0 = "#${c.yellow}"
ye2 = "#${c.surface}"
bl0 = "#${c.blue}"
bl2 = "#${c.surface}"
pu0 = "#${c.magenta}"
pu2 = "#${c.surface}"
cy0 = "#${c.cyan}"
cy2 = "#${c.selection}"
wh0 = "#${c.fg}"
wh2 = "#${c.surface}"
me0 = "#${c.danger}"
me2 = "#${c.surface}"
or0 = "#${c.orange}"
or2 = "#${c.surface}"

[git_branch]
symbol = ""
style = "bg:pu2 fg:pu0"
format = "[](fg:pu2)[ $symbol $branch ]($style)[](fg:pu2)"

[git_status]
style = "bg:pu0 fg:pu2"   # hlavní blok
format = "[](fg:pu0)[ $all_status$ahead_behind ]($style)[](fg:pu0)"

[c]
symbol = ""
style = "bg:bl2 fg:bl0"
format = "[](fg:pu2 bg:bl2)[ $symbol ($version) ]($style)"

[cpp]
symbol = ""
style = "bg:bl2 fg:bl0"
format = "[ $symbol ($version) ]($style)"

[elm]
symbol = ""
style = "bg:bl2 fg:bl0"
format = "[ $symbol ($version) ]($style)"

[golang]
symbol = ""
style = "bg:bl2 fg:bl0"
format = "[ $symbol ($version) ]($style)"

[gradle]
style = "bg:cy2 fg:cy0"
format = "[](fg:bl2 bg:cy2)[ $symbol ($version) ]($style)"

[julia]
symbol = ""
style = "bg:cy2 fg:cy0"
format = "[ $symbol ($version) ]($style)"

[java]
symbol = ""
style = "bg:or2 fg:or0"
format = "[](fg:cy2 bg:or2)[ $symbol ($version) ]($style)"

[rust]
symbol = ""
style = "bg:or2 fg:or0"
format = "[ $symbol ($version) ]($style)"

[python]
symbol = ""
style = "bg:ye2 fg:ye0"
format = "[](fg:or2 bg:ye2)[ $symbol ($version) ]($style)"

[nim]
symbol = "󰆥"
style = "bg:ye2 fg:ye0"
format = "[ $symbol ($version) ]($style)"

[haskell]
symbol = ""
style = "bg:pu2 fg:pu0"
format = "[](fg:ye2 bg:pu2)[ $symbol ($version) ]($style)"

[elixir]
symbol = ""
style = "bg:pu2 fg:pu0"
format = "[ $symbol ($version) ]($style)"

[scala]
symbol = ""
style = "bg:re2 fg:re0"
format = "[](fg:pu2 bg:re2)[ $symbol ($version) ]($style)"

[docker_context]
symbol = ""
style = "bg:bl2 fg:bl0"
format = "[](fg:re2 bg:bl2)[ $symbol $context ]($style)"
  '';
}

