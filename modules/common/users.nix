{ config, lib, pkgs, username, ... }:
let
  authorizedKeysPath = /home + "/${username}/.ssh/authorized_keys";
in
{
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" "input" "uinput" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keyFiles =
      lib.optional (builtins.pathExists authorizedKeysPath) authorizedKeysPath;
    packages = [ ];
  };

  security.sudo.extraRules = [{
    users = [ username ];
    commands = [{
      command = "ALL";
      options = [ "NOPASSWD" ];
    }];
  }];

  # Mirror the user's nvim config into root's home so `sudo nvim` doesn't
  # surprise you with a fresh LazyVim setup.
  systemd.tmpfiles.rules = [
    "d /root/.config 0755 root root -"
    "L+ /root/.config/nvim - - - - /home/${username}/dotfiles/nvim"
  ];
}
