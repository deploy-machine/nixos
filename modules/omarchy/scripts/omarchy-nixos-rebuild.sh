# The one rebuild ritual every menu action funnels through. Mirrors the
# `nrs` shell alias: the per-host /etc/nixos/flake.nix consumes this repo as
# a `path:` input, so the lock must be refreshed first or the rebuild serves
# stale repo content.
echo ":: Refreshing config-repo input and rebuilding NixOS..."
sudo sh -c 'nix flake update config-repo --flake /etc/nixos && nixos-rebuild switch --flake /etc/nixos --impure'
echo ":: Done."
