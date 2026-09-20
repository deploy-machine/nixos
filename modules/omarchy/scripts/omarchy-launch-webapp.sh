# Launch a URL as a chromium app window. Used by menu-installed web apps
# and the Learn menu. Extra args (e.g. --class) pass through.
url="$1"
shift
exec chromium --app="$url" "$@"
