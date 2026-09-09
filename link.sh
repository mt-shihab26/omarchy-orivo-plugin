#!/bin/bash

set -euo pipefail

# Symlinks ~/.config/omarchy/plugins/omarchy-orivo-plugin to this repo, so
# Omarchy picks up the plugin directly from the working tree during
# development. Pass --remove to unlink instead.

cd "$(dirname "${BASH_SOURCE[0]}")"
repo_dir="$(pwd)"
plugins_dir="$HOME/.config/omarchy/plugins"
target="$plugins_dir/omarchy-orivo-plugin"

if [ "${1:-}" = "--remove" ]; then
    if [ -L "$target" ]; then
        rm "$target"
        echo "removed $target"
    else
        echo "nothing to remove: $target is not a symlink"
    fi
    exit 0
fi

mkdir -p "$plugins_dir"

if [ -L "$target" ]; then
    rm "$target"
elif [ -e "$target" ]; then
    echo "error: $target already exists and is not a symlink" >&2
    exit 1
fi

ln -s "$repo_dir" "$target"
echo "linked $target -> $repo_dir"
