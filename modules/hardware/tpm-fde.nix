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
#   2. After first boot, bind the volume to the TPM — with a PIN, so a
#      desk-visitor can't just power the machine on and get to a login
#      screen (TPM anti-hammering makes brute-forcing the PIN infeasible):
#        sudo systemd-cryptenroll /dev/nvmeXnYpZ \
#          --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes
#
#   3. Keep the original passphrase (keyslot 0) as the recovery path, and
#      back up the header off-machine:
#        sudo cryptsetup luksHeaderBackup /dev/nvmeXnYpZ \
#          --header-backup-file luks-header.img
#
# PCR 7 measures the Secure Boot policy, so the seal is only meaningful with
# Secure Boot ON and the kernel signed with your own keys (lanzaboote +
# sbctl). Until that lands, TPM+PIN still beats passphrase-only ergonomics,
# but an attacker who can boot their own OS can attempt the unseal (the PIN
# still stops them).
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
    pkgs.sbctl      # Secure Boot key management, pairs with a future lanzaboote setup
  ];
}
