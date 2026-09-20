# Update / maintenance flows (the NixOS analog of omarchy-update).
case "${1-}" in
system)
  # Apply the current state of the config repo.
  omarchy-nixos-rebuild
  ;;
inputs)
  # Bump the repo's own flake inputs (nixpkgs, home-manager, stylix, ...),
  # then rebuild against them.
  cd "$OMARCHY_REPO"
  if [ "$(uname -m)" != "x86_64" ]; then
    echo "⚠  Asahi host: bumping nixpkgs-25-11 can miss the Asahi binary cache"
    echo "   and force a ~30-60 min local kernel/Mesa rebuild."
    gum confirm "Bump flake inputs anyway?" || exit 0
  fi
  nix flake update
  git -C "$OMARCHY_REPO" diff --stat flake.lock || true
  omarchy-nixos-rebuild
  ;;
rollback)
  echo ":: System generations:"
  sudo nix-env -p /nix/var/nix/profiles/system --list-generations | tail -n 10
  echo
  gum confirm "Roll back to the previous generation?" || exit 0
  sudo nixos-rebuild switch --rollback
  ;;
clean)
  echo ":: Deleting generations older than 14 days and collecting garbage..."
  sudo nix-collect-garbage --delete-older-than 14d
  nix-collect-garbage --delete-older-than 14d
  echo ":: Done. (Run 'nix store optimise' for extra dedup if you want.)"
  ;;
*)
  echo "Usage: omarchy-update <system|inputs|rollback|clean>" >&2
  exit 1
  ;;
esac
