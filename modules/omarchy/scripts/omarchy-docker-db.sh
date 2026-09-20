# Toggle a development database container on/off. Declarative twist on
# omarchy-install-docker-dbs: edits modules/omarchy/dbs.json and rebuilds,
# so the container is managed by virtualisation.oci-containers (systemd
# unit docker-<name>.service) instead of a loose `docker run`.
dbs_json="$OMARCHY_REPO/modules/omarchy/dbs.json"
valid="mysql mariadb postgres redis mongodb mssql"

action="${1-toggle}"
db="${2-}"

if [ "$action" = "status" ]; then
  jq -r '.enabled[]' "$dbs_json"
  exit 0
fi

if [ -z "$db" ] || ! echo "$valid" | grep -qw "$db"; then
  echo "Usage: omarchy-docker-db toggle <mysql|mariadb|postgres|redis|mongodb|mssql>" >&2
  exit 1
fi

tmp=$(mktemp)
if jq -e --arg d "$db" '.enabled | index($d)' "$dbs_json" >/dev/null; then
  jq --arg d "$db" '.enabled -= [$d]' "$dbs_json" >"$tmp"
  mv "$tmp" "$dbs_json"
  echo ":: Disabled $db (container + unit removed on rebuild; its data volume is kept)"
else
  if [ "$db" = "mysql" ] && jq -e '.enabled | index("mariadb")' "$dbs_json" >/dev/null; then
    echo "mariadb is enabled and uses the same port (3306). Disable it first." >&2
    exit 1
  fi
  if [ "$db" = "mariadb" ] && jq -e '.enabled | index("mysql")' "$dbs_json" >/dev/null; then
    echo "mysql is enabled and uses the same port (3306). Disable it first." >&2
    exit 1
  fi
  if [ "$db" = "mssql" ] && [ "$(uname -m)" != "x86_64" ]; then
    echo "The MSSQL server image is x86_64-only; it will not run on this machine." >&2
    exit 1
  fi
  jq --arg d "$db" '.enabled = (.enabled + [$d] | unique)' "$dbs_json" >"$tmp"
  mv "$tmp" "$dbs_json"
  echo ":: Enabled $db (bound to 127.0.0.1, dev credentials — see modules/omarchy/system.nix)"
fi

omarchy-nixos-rebuild
