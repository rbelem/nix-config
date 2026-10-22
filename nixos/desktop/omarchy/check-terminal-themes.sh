#!/bin/sh
# Checks that the rendered terminal themes are accepted by the terminals.
#
# Each terminal has its own colour format and its own way of loading a
# theme file, and every one of them fails silently when it gets it wrong.
# This renders the theme into a throwaway home directory and asks each
# terminal to read it back.
#
# Usage: check-terminal-themes.sh <theme-dir> <foot> <alacritty> <kitty> <ghostty>
set -eu

theme_dir=$1
foot=$2
alacritty=$3
kitty=$4
ghostty=$5

home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT

# place <terminal> <theme-path> <config-path>
place() {
    terminal=$1
    theme_rel=$2
    config_rel=$3

    mkdir -p "$home/.config/$(dirname "$theme_rel")"
    cp "$theme_dir/theme/$terminal" "$home/.config/$theme_rel"
    mkdir -p "$home/.config/$(dirname "$config_rel")"
    cp "$theme_dir/config/$terminal" "$home/.config/$config_rel"
}

echo "foot reads the theme"
place foot foot/themes/omarchy foot/foot.ini
HOME=$home "$foot" --check-config

echo "alacritty reads the theme"
place alacritty alacritty/themes/omarchy.toml alacritty/alacritty.toml
alacritty_output=$(HOME=$home "$alacritty" --config-file "$home/.config/alacritty/alacritty.toml" -e true 2>&1 || true)
if printf '%s' "$alacritty_output" | grep -q "Config error"; then
    printf '%s\n' "$alacritty_output"
    exit 1
fi

echo "kitty reads the theme"
place kitty kitty/themes/omarchy.conf kitty/kitty.conf
HOME=$home "$kitty" +runpy "from kitty.config import load_config; load_config('$home/.config/kitty/kitty.conf')"

echo "ghostty reads the theme"
place ghostty ghostty/themes/omarchy ghostty/config
ghostty_output=$(HOME=$home "$ghostty" +show-config 2>&1 || true)
if ! printf '%s' "$ghostty_output" | grep -q "^background = "; then
    printf '%s\n' "$ghostty_output"
    exit 1
fi
