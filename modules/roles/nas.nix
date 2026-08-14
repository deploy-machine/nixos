# SMB shares from the NAS at 10.0.10.2 (LAN, also reachable over the
# tailnet via its subnet route), mounted under /mnt/nas/<share>.
#
# These are systemd *automounts*, not hard fstab mounts: nothing is touched
# at boot, the share mounts on first access, and it unmounts again after 60s
# idle. That makes the module safe on laptops that roam off-network — a
# missing NAS costs a quick timeout on access instead of hanging boot.
#
# One-time setup per host — create the credentials file (never committed):
#     sudo sh -c 'umask 077; printf "username=YOUR_NAS_USER\npassword=YOUR_NAS_PASSWORD\n" > /etc/nas-credentials'
{ lib, pkgs, ... }:
let
  nas    = "10.0.10.2";
  shares = [ "Data" "Media" "Backups" ];
in
{
  # mount.cifs helper used by the generated mount units.
  environment.systemPackages = [ pkgs.cifs-utils ];

  fileSystems = lib.listToAttrs (map (share: {
    name = "/mnt/nas/${lib.toLower share}";
    value = {
      device = "//${nas}/${share}";
      fsType = "cifs";
      options = [
        "credentials=/etc/nas-credentials"
        # Files show up as the desktop user (uid 1000, group users) since
        # SMB has no unix ownership to preserve.
        "uid=1000"
        "gid=100"
        "file_mode=0664"
        "dir_mode=0775"
        "iocharset=utf8"
        # On-demand automount instead of mount-at-boot.
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=10s"
        "_netdev"
      ];
    };
  }) shares);
}
