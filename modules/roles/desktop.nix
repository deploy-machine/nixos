{ pkgs, ... }:
{
  # Conventional graphical login: greetd → tuigreet, user selects Hyprland.
  # Mutually exclusive with the headless and gaming-kiosk roles (they all set
  # services.greetd.settings).
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'uwsm start hyprland-uwsm.desktop'";
        user = "greeter";
      };
    };
  };
}
