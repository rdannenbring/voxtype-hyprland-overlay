#!/bin/bash
# install.sh — Set up voxtype-hyprland-overlay
#
# Creates config directory, generates sounds, and prints the keybind to add.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/voxtype-overlay"

echo "==> Checking dependencies..."
missing=()
for cmd in voxtype hyprctl pactl paplay python3 ffmpeg; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
for mod in gi cairo; do
    python3 -c "import $mod" 2>/dev/null || missing+=("python-$mod")
done
[ ${#missing[@]} -gt 0 ] && echo "Missing: ${missing[*]}" && echo "Install these before continuing." && exit 1
echo "    All dependencies found."

echo "==> Generating sounds..."
bash "$SCRIPT_DIR/sounds/generate.sh"

echo "==> Creating config directory..."
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.sh" ]; then
    cp "$SCRIPT_DIR/config.sh" "$CONFIG_DIR/config.sh"
    echo "    Config written to $CONFIG_DIR/config.sh"
    echo "    *** Edit it to set your SPEAKER device. ***"
    echo "    Run: pactl list sinks | grep -E 'Name:|Description:'"
    echo "    or:  wpctl status"
else
    echo "    Config already exists at $CONFIG_DIR/config.sh — not overwriting."
fi

chmod +x "$SCRIPT_DIR/voxtype-toggle.sh"
chmod +x "$SCRIPT_DIR/voxtype-overlay.py"
chmod +x "$SCRIPT_DIR/voxtype-osd-sync.sh"

echo "==> Applying OSD settings to voxtype config..."
bash "$SCRIPT_DIR/voxtype-osd-sync.sh"

echo ""
echo "==> Done. Add this to your Hyprland config:"
echo ""
echo "    bind = Super, C, exec, $SCRIPT_DIR/voxtype-toggle.sh"
echo ""
echo "    Also set [hotkey] enabled = false in ~/.config/voxtype/config.toml"
echo "    if you haven't already."
