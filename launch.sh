#!/usr/bin/env bash
set -euo pipefail

# Resolve the project relative to this script, so it works from any directory.
project_dir="$(dirname -- "${BASH_SOURCE[0]}")"
engine=""

for candidate in redot godot4 godot; do
    if command -v "$candidate" >/dev/null 2>&1; then
        engine="$(command -v "$candidate")"
        break
    fi
done

if [[ -z "$engine" ]]; then
    printf 'Error: Redot or Godot 4.3+ must be installed and available on PATH.\n' >&2
    exit 1
fi

# Import assets and register scripts, including on a fresh checkout.
"$engine" --headless --editor --import --quiet --path "$project_dir"

# Forward engine options, e.g. ./launch.sh --fullscreen.
exec "$engine" --path "$project_dir" "$@"
