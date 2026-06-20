{ config, pkgs, ... }:
{
  # neovim as a plain PACKAGE — deliberately NOT `programs.neovim`.
  # The HM neovim module generates its own ~/.config/nvim/init.lua, which
  # collides with the whole-directory out-of-store symlink below
  # ("Error installing file '.config/nvim/init.lua' outside $HOME").
  # Installing the package lets LazyVim own the config completely.
  home.packages = with pkgs; [
    neovim

    # build deps LazyVim/lazy.nvim expect on PATH
    gcc gnumake git curl unzip wget ripgrep fd
    tree-sitter   # CLI parser builder required by nvim-treesitter's `main` branch
    # cargo rustc   # only if you want blink.cmp's native Rust matcher to build

    # global Nix/Lua LSP + formatters for editing your config outside a dev shell
    lua-language-server stylua nixd alejandra
  ];

  home.sessionVariables.EDITOR = "nvim";
  home.shellAliases = { vi = "nvim"; vim = "nvim"; };

  # Whole config dir symlinked out-of-store — editable LazyVim config at ~/dotfiles/nvim
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/nvim";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}

