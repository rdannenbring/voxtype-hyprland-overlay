#!/bin/bash
# voxtype-osd-sync.sh — Apply OSD settings from config.sh to voxtype's config.toml
#
# Run this after changing VOXTYPE_OSD_* settings in config.sh.
# Restarts the voxtype daemon so changes take effect immediately.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${VOXTYPE_OVERLAY_CONFIG:-$HOME/.config/voxtype-overlay/config.sh}"
VOXTYPE_CONFIG="$HOME/.config/voxtype/config.toml"

# Defaults
VOXTYPE_OSD_ENABLED=false
VOXTYPE_OSD_FRONTEND="gtk4"
VOXTYPE_OSD_POSITION="bottom-center"

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

if [ ! -f "$VOXTYPE_CONFIG" ]; then
    echo "voxtype config not found at $VOXTYPE_CONFIG"
    exit 1
fi

python3 - <<PYEOF
import re

config_path = "$VOXTYPE_CONFIG"
enabled     = "$VOXTYPE_OSD_ENABLED".lower()
frontend    = "$VOXTYPE_OSD_FRONTEND"
position    = "$VOXTYPE_OSD_POSITION"

with open(config_path) as f:
    content = f.read()

osd_block = f"""[osd]
enabled = {enabled}
frontend = "{frontend}"
position = "{position}"
"""

# Replace existing [osd] block or append if absent
if re.search(r'^\[osd\]', content, re.MULTILINE):
    content = re.sub(
        r'\[osd\].*?(?=\n\[|\Z)',
        osd_block.rstrip(),
        content,
        flags=re.DOTALL
    )
else:
    content = content.rstrip() + "\n\n" + osd_block

with open(config_path, 'w') as f:
    f.write(content)

print(f"OSD set to: enabled={enabled}, frontend={frontend}, position={position}")
PYEOF

echo "Restarting voxtype daemon..."
systemctl --user restart voxtype
echo "Done."
