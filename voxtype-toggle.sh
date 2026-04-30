#!/bin/bash
# voxtype-toggle.sh — Hyprland recording overlay + audio feedback for VoxType
#
# Usage: bind this script to your compositor keybind instead of calling
#        `voxtype record toggle` directly.
#
# Hyprland example:
#   bind = Super, C, exec, /path/to/voxtype-toggle.sh
#
# Dependencies: voxtype, hyprctl, pactl, paplay, python3,
#               gtk4, gtk4-layer-shell, python-gobject, python-cairo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${VOXTYPE_OVERLAY_CONFIG:-$HOME/.config/voxtype-overlay/config.sh}"

# ── Defaults (overridden by config.sh) ─────────────────────────────────────────
SPEAKER=""
AUDIO_ENABLED=true
START_SOUND="$SCRIPT_DIR/sounds/beep-start.wav"
STOP_SOUND="$SCRIPT_DIR/sounds/beep-stop.wav"
SOUND_VOLUME=65536
DUCK_ENABLED=true
DUCK_VOLUME=15
DUCK_FADE_STEPS=20
DUCK_FADE_DELAY=0.025
OVERLAY_ENABLED=true
OVERLAY_OPACITY=0.55
BORDER_ENABLED=true
BORDER_COLOR="#33CCFF"
BORDER_WIDTH=4
RECORDING_LABEL="RECORDING"
LABEL_FONT_SIZE=18
MIC_ICON="/usr/share/icons/Papirus/128x128/devices/audio-input-microphone.svg"
MIC_ICON_SIZE=160
PULSE_ENABLED=true
PULSE_SPEED=0.025
PULSE_MIN=0.35
PULSE_MAX=1.0
PULSE_TICK_MS=40

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Resolve sound paths (allow config.sh overrides, else use bundled defaults)
START_SOUND="${START_SOUND:-$SCRIPT_DIR/sounds/beep-start.wav}"
STOP_SOUND="${STOP_SOUND:-$SCRIPT_DIR/sounds/beep-stop.wav}"

VOLUME_FILE="/tmp/voxtype-speaker-volume"
OVERLAY_PID_FILE="/tmp/voxtype-overlay-pid"

fade_volume() {
    local from=$1 to=$2
    local diff=$((to - from))
    for i in $(seq 1 "$DUCK_FADE_STEPS"); do
        pactl set-sink-volume "$SPEAKER" "$((from + diff * i / DUCK_FADE_STEPS))%"
        sleep "$DUCK_FADE_DELAY"
    done
}

launch_overlay() {
    local win_info
    win_info=$(hyprctl activewindow -j)

    local win_x win_y win_w win_h mon_id
    win_x=$(printf '%s' "$win_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['at'][0])")
    win_y=$(printf '%s' "$win_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['at'][1])")
    win_w=$(printf '%s' "$win_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['size'][0])")
    win_h=$(printf '%s' "$win_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['size'][1])")
    mon_id=$(printf '%s' "$win_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['monitor'])")

    local mon_x mon_y
    mon_x=$(hyprctl monitors -j | python3 -c "import sys,json; m=[m for m in json.load(sys.stdin) if m['id']==$mon_id][0]; print(m['x'])")
    mon_y=$(hyprctl monitors -j | python3 -c "import sys,json; m=[m for m in json.load(sys.stdin) if m['id']==$mon_id][0]; print(m['y'])")

    VOXTYPE_OVERLAY_OPACITY="$OVERLAY_OPACITY" \
    VOXTYPE_BORDER_ENABLED="$BORDER_ENABLED" \
    VOXTYPE_BORDER_COLOR="$BORDER_COLOR" \
    VOXTYPE_BORDER_WIDTH="$BORDER_WIDTH" \
    VOXTYPE_RECORDING_LABEL="$RECORDING_LABEL" \
    VOXTYPE_LABEL_FONT_SIZE="$LABEL_FONT_SIZE" \
    VOXTYPE_MIC_ICON="$MIC_ICON" \
    VOXTYPE_MIC_ICON_SIZE="$MIC_ICON_SIZE" \
    VOXTYPE_PULSE_ENABLED="$PULSE_ENABLED" \
    VOXTYPE_PULSE_SPEED="$PULSE_SPEED" \
    VOXTYPE_PULSE_MIN="$PULSE_MIN" \
    VOXTYPE_PULSE_MAX="$PULSE_MAX" \
    VOXTYPE_PULSE_TICK_MS="$PULSE_TICK_MS" \
    LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so \
        /usr/bin/python3 "$SCRIPT_DIR/voxtype-overlay.py" \
        "$win_x" "$win_y" "$win_w" "$win_h" "$mon_id" "$mon_x" "$mon_y" &

    echo $! > "$OVERLAY_PID_FILE"
}

kill_overlay() {
    if [ -f "$OVERLAY_PID_FILE" ]; then
        kill "$(cat "$OVERLAY_PID_FILE")" 2>/dev/null
        rm -f "$OVERLAY_PID_FILE"
    fi
}

# ── Main toggle logic ───────────────────────────────────────────────────────────
if [ "$(voxtype status 2>/dev/null)" = "idle" ]; then
    # Starting recording
    if [ -n "$SPEAKER" ] && [ "$DUCK_ENABLED" = "true" ]; then
        current=$(pactl get-sink-volume "$SPEAKER" | grep -oP '\d+(?=%)' | head -1)
        echo "$current" > "$VOLUME_FILE"
    fi

    [ "$OVERLAY_ENABLED" = "true" ] && launch_overlay

    if [ -n "$SPEAKER" ] && [ "$AUDIO_ENABLED" = "true" ] && [ -f "$START_SOUND" ]; then
        paplay --device="$SPEAKER" --volume="$SOUND_VOLUME" "$START_SOUND"
    fi

    if [ -n "$SPEAKER" ] && [ "$DUCK_ENABLED" = "true" ] && [ -f "$VOLUME_FILE" ]; then
        fade_volume "$current" "$DUCK_VOLUME" &
    fi
else
    # Stopping recording
    kill_overlay

    if [ -n "$SPEAKER" ] && [ "$DUCK_ENABLED" = "true" ] && [ -f "$VOLUME_FILE" ]; then
        saved=$(cat "$VOLUME_FILE")
        rm -f "$VOLUME_FILE"
        fade_volume "$DUCK_VOLUME" "$saved"
    fi

    if [ -n "$SPEAKER" ] && [ "$AUDIO_ENABLED" = "true" ] && [ -f "$STOP_SOUND" ]; then
        paplay --device="$SPEAKER" --volume="$SOUND_VOLUME" "$STOP_SOUND" &
    fi
fi

voxtype record toggle
