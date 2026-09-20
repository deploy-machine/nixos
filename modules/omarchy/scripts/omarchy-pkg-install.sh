# Declarative package install: search nixpkgs, append the chosen attribute
# to modules/omarchy/apps.json in the config repo, rebuild. The NixOS analog
# of omarchy-pkg-install (which shells out to pacman).
apps_json="$OMARCHY_REPO/modules/omarchy/apps.json"

query=$(gum input --placeholder "Search nixpkgs..." --prompt "󰉉 ") || exit 0
[ -z "$query" ] && exit 0

echo ":: Searching nixpkgs for '$query' (first run can take a moment)..."
# nix search exits non-zero on zero matches; don't let pipefail kill the
# script before the "no matches" message below.
results=$(nix search nixpkgs "$query" --json 2>/dev/null |
  jq -r 'to_entries[] | (.key | sub("^legacyPackages\\.[^.]+\\.";"")) + "\t" + (.value.description // "")' || true)

if [ -z "$results" ]; then
  echo "No packages matched '$query'."
  exit 1
fi

choice=$(echo "$results" | fzf --delimiter='\t' \
  --with-nth=1,2 --prompt="install > " \
  --header="Enter installs declaratively (edits apps.json + rebuild)") || exit 0
attr=$(echo "$choice" | cut -f1)
[ -z "$attr" ] && exit 0

if jq -e --arg p "$attr" '.packages | index($p)' "$apps_json" >/dev/null; then
  echo "'$attr' is already in apps.json."
  exit 0
fi

tmp=$(mktemp)
jq --arg p "$attr" '.packages = (.packages + [$p] | sort | unique)' "$apps_json" >"$tmp"
mv "$tmp" "$apps_json"
echo ":: Added '$attr' to $apps_json"
echo ":: Note: the search index is nixpkgs-unstable; if the rebuild reports"
echo "   an unknown attribute, your system channel doesn't ship it yet."

omarchy-nixos-rebuild
