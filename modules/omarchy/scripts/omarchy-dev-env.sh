# Scaffold a per-project dev environment from the nix-templates/dev set
# (plus this repo's framework starters), baked into the store at build time.
# The NixOS answer to omarchy-install-dev-env: instead of `mise use --global
# <tool>`, each project gets a reproducible devShell + direnv .envrc, with
# LSP, linters, formatters and scanners already wired into VS Code/Neovim.
lang="${1-}"
if [ -z "$lang" ] || [ ! -d "$OMARCHY_DEV_TEMPLATES/$lang" ]; then
  echo "Usage: omarchy-dev-env <template>" >&2
  echo "Templates: $(cut -f1 "$OMARCHY_DEV_TEMPLATES/index.tsv" | tr '\n' ' ')" >&2
  exit 1
fi

echo ":: New $lang project"
dir=$(gum input --prompt "Project directory: " --value "$HOME/Projects/") || exit 0
[ -z "$dir" ] && exit 0

if [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
  echo "Directory '$dir' exists and is not empty." >&2
  exit 1
fi

# Same as `nix flake new -t`, minus the flake evaluation: copy the template
# out of the store and make it writable.
mkdir -p "$dir"
cp -r --no-preserve=mode,ownership "$OMARCHY_DEV_TEMPLATES/$lang/." "$dir/"

if command -v direnv >/dev/null; then
  direnv allow "$dir" 2>/dev/null || true
fi

echo
echo ":: Created $dir"
echo "   cd $dir      # direnv drops you into the devShell automatically"
echo "   nix develop  # or enter it manually"
echo
echo "   lint / fmt / scan   run every linter, formatter and security scanner"
echo "   Neovim: needs vim.o.exrc = true to load .nvim.lua (then :trust)"
echo "   VS Code: install mkhl.direnv; the project recommends the rest"
echo
echo "   First entry downloads the toolchain; later entries are instant."
