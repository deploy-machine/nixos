# Scaffold a per-project dev environment from this repo's flake templates.
# The NixOS answer to omarchy-install-dev-env: instead of `mise use --global
# <tool>`, each project gets a reproducible devShell + direnv .envrc.
lang="${1-}"
if [ -z "$lang" ]; then
  echo "Usage: omarchy-dev-env <ruby|node|bun|deno|go|php|laravel|symfony|python|elixir|phoenix|rust|java|zig|ocaml|dotnet|clojure|scala>" >&2
  exit 1
fi

echo ":: New $lang project (flake template from $OMARCHY_REPO)"
dir=$(gum input --prompt "Project directory: " --value "$HOME/Projects/") || exit 0
[ -z "$dir" ] && exit 0

if [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
  echo "Directory '$dir' exists and is not empty." >&2
  exit 1
fi

mkdir -p "$(dirname "$dir")"
nix flake new -t "path:$OMARCHY_REPO#$lang" "$dir"

if command -v direnv >/dev/null; then
  direnv allow "$dir" 2>/dev/null || true
fi

echo
echo ":: Created $dir"
echo "   cd $dir      # direnv drops you into the devShell automatically"
echo "   nix develop  # or enter it manually"
echo
echo "   First entry downloads the toolchain; later entries are instant."
