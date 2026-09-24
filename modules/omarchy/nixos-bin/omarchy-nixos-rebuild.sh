# The one rebuild every declarative action funnels through. The per-host
# /etc/nixos/flake.nix consumes the config repo as a `path:` input, so the
# lock must be refreshed first or the rebuild serves stale repo content.
echo ":: Refreshing config-repo input and rebuilding NixOS..."
sudo sh -c 'nix flake update config-repo --flake /etc/nixos && nixos-rebuild switch --flake /etc/nixos --impure'
echo ":: Done."
