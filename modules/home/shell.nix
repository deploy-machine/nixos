# /etc/nixos/shell.nix
# zsh + starship. Starship is shell-agnostic; cybr ships it for fish, here it
# drives zsh (you asked for zsh). Prompt = cybr "lucid" recoloured to milkoutside.
#
# Requires in configuration.nix (system-level, for the login shell):
#   programs.zsh.enable = true;
#   users.users.simbaclaws.shell = pkgs.zsh;
#
# NOTE: stylix.targets.starship is disabled in home.nix so Stylix doesn't write a
# competing prompt config.
{ config, pkgs, ... }:
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
  };

  # Exact cybr prompt, glyphs preserved, palette = milkoutside.
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

palette = "milkoutside"

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

[palettes.milkoutside]
no0 = "#040607"
no1 = "#0f0f15"

re0 = "#f93a82"
re2 = "#2e0f1f"

gr0 = "#92cf9c"
gr2 = "#16271b"

ye0 = "#f8e063"
ye2 = "#332D10"

bl0 = "#63c3dd"
bl2 = "#0c2329"

pu0 = "#9d7cd8"
pu2 = "#1f1733"

cy0 = "#7dcfff"
cy2 = "#11242f"

wh0 = "#8a8a8a"
wh2 = "#1E2025"

me0 = "#4D5A80"
me2 = "#0D1120"

or0 = "#ffad00"
or2 = "#332300"

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

