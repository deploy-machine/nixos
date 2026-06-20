{ config, inputs, hostname, username, ... }:
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs username hostname; };
    users.${username} = { imports = [ ../home ]; };
  };

  # home-manager-<user>.service runs `dconf write` for stylix's GTK theming.
  # The service is a system unit using systemd's User= directive, so it
  # doesn't inherit the user's session-bus address from `systemd --user`.
  # Without DBUS_SESSION_BUS_ADDRESS pointed at /run/user/<uid>/bus, dconf
  # fails with "GDBus.Error.ServiceUnknown: The name is not activatable".
  # Linger (set in users.nix) keeps the user manager running so the socket
  # exists; this env tells home-manager where to find it.
  systemd.services."home-manager-${username}".environment.DBUS_SESSION_BUS_ADDRESS =
    "unix:path=/run/user/${toString config.users.users.${username}.uid}/bus";
}
