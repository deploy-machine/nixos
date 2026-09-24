# UEFI Secure Boot with your own keys, via lanzaboote.
#
# What this module does: replaces systemd-boot's installer with lanzaboote,
# which builds one signed UKI (kernel + initrd + cmdline in a single PE
# binary) per generation, and locks down the pre-boot paths a physical
# attacker would use to get a root shell without the disk key:
#   - no boot-menu cmdline editor (init=/bin/sh, rd.break, …)
#   - no passwordless emergency shell in the initrd
#
# What it does NOT do: create or enroll keys. Those are one-time imperative
# steps, deliberately kept manual because enrolling rotates PCR 7 — which
# BitLocker on a dual-boot disk also seals against (see tpm-fde.nix):
#
#   1. Before the first rebuild with this module: `sudo sbctl create-keys`
#      (writes /var/lib/sbctl). The rebuild fails without them.
#   2. Rebuild + reboot, then check every ESP entry is signed:
#        sudo sbctl verify   # only systemd-boot's own *.efi may show unsigned
#   3. Dual-boot only: export the BitLocker recovery key and run
#      `Suspend-BitLocker -MountPoint C: -RebootCount 0` from Windows
#      (0 = until resumed; a count can run out mid-procedure). After step 6,
#      boot Windows once and `Resume-BitLocker -MountPoint C:` to reseal.
#   4. Firmware setup: set an admin/supervisor password, then clear/reset
#      Secure Boot keys so the firmware enters Setup Mode. Boot NixOS.
#   5. sudo sbctl enroll-keys --microsoft
#      KEEP --microsoft: it enrolls Microsoft's UEFI CA, which signs Windows
#      AND the option ROMs of GPUs/NICs. Without it an NVIDIA/AMD card's
#      GOP driver is rejected and the machine can come up with no display.
#   6. Firmware setup: enable Secure Boot (mode "User"/"Custom"). Reboot,
#      then `bootctl status` should say "Secure Boot: enabled (user)".
#   7. Only now enroll the TPM (tpm-fde.nix) — PCR 7 has its final value.
{ config, lib, pkgs, inputs, ... }:
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  assertions = [{
    assertion = pkgs.stdenv.hostPlatform.isx86_64;
    message = "hardware.secure-boot targets x86_64 UEFI hosts. Apple Silicon boots via m1n1/U-Boot and has no UEFI Secure Boot.";
  }];

  # lanzaboote replaces the systemd-boot module; both enabled would race on
  # the ESP. It still installs systemd-boot itself as the menu.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # lanzaboote's loader.conf inherits this (NixOS defaults it true).
  # systemd-stub ignores cmdline overrides under Secure Boot anyway, but the
  # editor has no business being reachable either way.
  boot.loader.systemd-boot.editor = false;

  # Explicit rather than relying on the default: an initrd root shell on
  # failure would hand an attacker at the keyboard everything pre-unlock.
  boot.initrd.systemd.emergencyAccess = false;

  environment.systemPackages = [
    pkgs.sbctl # key creation, enrollment, `sbctl verify` / `sbctl status`
  ];
}
