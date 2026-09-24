# TPM2-backed unlock for a LUKS2-encrypted root on x86_64 hosts.
#
# What this module does: switches the initrd to systemd (required — the old
# script-based initrd cannot do TPM2 unlock), enables TPM2 support inside it,
# and ships the userspace TPM stack (tpm2-tools, tss group, TCTI env) so
# enrollment commands work post-boot.
#
# What it does NOT do: create the LUKS volume or enroll the TPM. Those are
# one-time imperative steps:
#
#   1. Encrypt at install time (cryptsetup luksFormat before nixos-install).
#      nixos-generate-config detects the opened LUKS device and writes the
#      boot.initrd.luks.devices entry into hardware-configuration.nix itself.
#
#   2. After Secure Boot is enforcing with your own keys (secure-boot.nix),
#      bind the volume to the TPM — with a PIN, so a desk-visitor can't just
#      power the machine on and get to a login screen (TPM anti-hammering
#      makes brute-forcing the PIN infeasible):
#        sudo systemd-cryptenroll /dev/nvmeXnYpZ \
#          --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes
#      Enrolling before Secure Boot is on seals to the wrong PCR 7 value;
#      re-enroll with --wipe-slot=tpm2 added if that happened.
#
#   3. Keep the original passphrase (keyslot 0) as the recovery path, and
#      back up the header off-machine:
#        sudo cryptsetup luksHeaderBackup /dev/nvmeXnYpZ \
#          --header-backup-file luks-header.img
#
# PCR 7 measures the Secure Boot policy, so the seal is only meaningful with
# Secure Boot ON and the kernel signed with your own keys — import
# hardware.secure-boot alongside this module. Then only UKIs you signed can
# unseal; anything else (live USB, tampered initrd, SB disabled) changes
# PCR 7 and the TPM refuses.
#
# Why the PIN is not optional against a physical attacker: PCR 7 only says
# "a kernel signed by you booted". It does not prove the disk is yours — an
# attacker can swap in a LUKS volume they control, let your signed initrd
# boot *their* root, and ask the TPM for your key from there (the
# "filesystem confusion" attack). With --tpm2-with-pin the unseal also
# needs the PIN, which they don't have and can't hammer.
#
# Dual-boot with Windows/BitLocker on the same machine:
#   - Enroll custom Secure Boot keys ALONGSIDE Microsoft's, never instead of
#     them: `sbctl enroll-keys --microsoft`. Windows keeps booting with
#     Secure Boot intact.
#   - Any Secure Boot key change rotates PCR 7, which BitLocker also seals
#     against. Print/export the BitLocker recovery keys first, then suspend
#     BitLocker from Windows (`Suspend-BitLocker -MountPoint C:`) before
#     touching keys; on the next Windows boot it reseals to the new values.
#   - Do NOT clear the TPM itself — that discards BitLocker's keys too.
#     systemd-cryptenroll coexists with BitLocker without a TPM clear.
{ config, lib, pkgs, ... }:
{
  assertions = [{
    assertion = pkgs.stdenv.hostPlatform.isx86_64;
    message = "hardware.tpm-fde targets x86_64 hosts with a TPM 2.0. Apple Silicon has no TPM (the SEP is not usable from Linux) — on the Asahi host use plain LUKS with a passphrase instead.";
  }];

  # systemd initrd: prerequisite for systemd-cryptsetup's TPM2 path.
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.tpm2.enable = true;

  # Userspace TPM2 stack: tss group + udev rules for /dev/tpmrm0, and a
  # default TCTI so tpm2-tools work without per-command flags.
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };

  environment.systemPackages = [
    pkgs.tpm2-tools # tpm2_pcrread etc. — inspect PCR state when debugging seals
  ];

  warnings = lib.optional (!(config.boot.lanzaboote.enable or false))
    "hardware.tpm-fde without hardware.secure-boot: a PCR 7 seal is only meaningful with Secure Boot enforcing your own keys. Import nixosModules.hardware.secure-boot too.";
}
