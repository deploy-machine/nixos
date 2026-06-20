{ config, lib, pkgs, username, ... }:
let
  authorizedKeysPath = /home + "/${username}/.ssh/authorized_keys";
in
{
  users.users.${username} = {
    isNormalUser = true;
    # Pin the UID so /run/user/<UID>/bus has a predictable path. Needed by
    # the home-manager service env override below; also keeps the user's
    # systemd runtime dir consistent across reinstalls.
    uid = 1000;
    description = username;
    extraGroups = [ "networkmanager" "wheel" "input" "uinput" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keyFiles =
      lib.optional (builtins.pathExists authorizedKeysPath) authorizedKeysPath;
    packages = [ ];
    # Keep the user's systemd manager alive at boot (i.e. without a login). This
    # gives home-manager-<user>.service a live user-bus to talk to during
    # nixos-rebuild switch even before the first graphical login — fixes the
    # "DBus.Error.ServiceUnknown: The name is not activatable" failure that
    # bites fresh installs.
    linger = true;
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
