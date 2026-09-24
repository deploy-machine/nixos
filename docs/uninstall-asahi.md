# Uninstalling Asahi Linux from the MacBook Pro (16-inch, M1 Pro, 2021)

Reclaims the ~463 GB used by Asahi NixOS and returns the disk to macOS-only.
A copy of this file is also placed on the Asahi EFI partition so it can be
mounted and read from macOS (`diskutil mount disk0s4` → shows up as `EFI`).
That partition is one of the ones you delete below, so **read the whole file
first** — this repo copy is the durable one.

Official reference (verify against it before running anything):
<https://asahilinux.org/docs/platform/partitioning-cheatsheet/>

## Before you start

- [ ] Home directory + anything else you care about on the Linux side is
      backed up externally. The Linux partitions are unrecoverable after this.
- [ ] `~/nixos` (the config repo) is pushed to GitHub
      (`github.com/deploy-machine/nixos`) — the per-machine `/etc/nixos`
      flake references it by local path and dies with the partition.
- [ ] You are booted into **macOS**, logged in as an admin user.
- [ ] FileVault: enable it (System Settings → Privacy & Security) if not
      already on — it's the point of reclaiming this machine.

## Identify the partitions — do not skip

Run `diskutil list disk0` and match against this layout (as seen from Linux
on 2026-09-24):

| Linux name | macOS name (expected) | Size    | What it is                  | Action     |
|------------|----------------------|---------|-----------------------------|------------|
| nvme0n1p1  | disk0s1              | 500 MB  | iBoot/iSCPreboot containers | **KEEP**   |
| nvme0n1p2  | disk0s2              | 463 GB  | macOS APFS container        | **KEEP**   |
| nvme0n1p3  | disk0s3              | 2.3 GB  | Asahi stub (APFS, m1n1/U-Boot) | delete  |
| nvme0n1p4  | disk0s4              | 477 MB  | Asahi EFI system partition  | delete     |
| nvme0n1p5  | disk0s5              | 460 GB  | Asahi NixOS root (ext4)     | delete     |
| nvme0n1p6  | disk0s6              | 5 GB    | recoveryOS (Apple)          | **KEEP**   |

Rules from the official docs:

- **Never** delete the first partition (iBoot) or the last one (recoveryOS).
- **Never** use Disk Utility's whole-disk "Erase" or "Partition" pie UI for
  this — use `diskutil` on exactly the identified slices.
- The Asahi stub is an APFS *container*; delete it with
  `diskutil apfs deleteContainer`, not `eraseVolume`.
- If the numbering on your machine differs from the table, stop and re-map
  by size/type first. Sizes above are exact enough to match unambiguously.

## Delete and reclaim

```sh
# 1. The Asahi stub APFS container (~2.3 GB)
diskutil apfs deleteContainer disk0s3

# 2. The Asahi ESP (contains this file!) and the Linux root
diskutil eraseVolume free free disk0s4
diskutil eraseVolume free free disk0s5

# 3. Grow the macOS container into all freed space
diskutil apfs resizeContainer disk0s2 0

# 4. Confirm: disk0s2 should now be ~926 GB, no gaps
diskutil list disk0
```

If `resizeContainer` complains about non-contiguous free space, re-check
that all three Asahi slices were actually freed (`diskutil list`).

## Afterwards

- The boot picker entry for Asahi disappears on its own once the stub is gone.
- Check FileVault status: `fdesetup status` → "FileVault is On."
- recoveryOS still works (it lives in the kept 5 GB slice + iBoot).

## Tip

Doing this with Claude Code on macOS: paste this file in and ask it to
verify the `diskutil list` output matches the table before running the
delete commands. The identifiers are the only thing that can go wrong here.
