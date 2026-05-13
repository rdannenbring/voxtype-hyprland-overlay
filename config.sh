#!/bin/bash
# voxtype-overlay configuration
# Copy to ~/.config/voxtype-overlay/config.sh and customize

# ── Speaker device ─────────────────────────────────────────────────────────────
# Run: pactl list sinks short | awk '{print $2}'
# Leave empty to disable all audio features (overlay-only mode)
SPEAKER="alsa_output.pci-0000_80_1f.3.analog-stereo"

# ── Audio feedback ─────────────────────────────────────────────────────────────
AUDIO_ENABLED=true
# Paths to WAV files played on start/stop. Defaults to sounds/ next to this script.
# START_SOUND="/path/to/custom-start.wav"
# STOP_SOUND="/path/to/custom-stop.wav"

# Playback volume (0–65536, 65536 = 100%)
SOUND_VOLUME=65536

# ── Volume ducking ─────────────────────────────────────────────────────────────
DUCK_ENABLED=true
DUCK_VOLUME=15        # percent to duck to while recording (0–100)
DUCK_FADE_STEPS=20    # number of steps in the fade
DUCK_FADE_DELAY=0.025 # seconds between steps (total = steps × delay)

# ── Overlay ────────────────────────────────────────────────────────────────────
OVERLAY_ENABLED=true
OVERLAY_OPACITY=0.55  # 0.0 (invisible) – 1.0 (fully black)

# ── Window highlight border ────────────────────────────────────────────────────
BORDER_ENABLED=true
BORDER_COLOR="#33CCFF" # hex color, e.g. "#FF4444" for red, "#33FF88" for green
BORDER_WIDTH=4         # pixels

# ── Voxtype built-in OSD (audio waveform visualizer) ──────────────────────────
# The OSD shows a live input waveform at the bottom of your screen while recording.
# Requires voxtype 0.7.0+. Change takes effect after running: voxtype-osd-sync.sh
# or reinstalling. frontend: "gtk4" or "native"
VOXTYPE_OSD_ENABLED=false
VOXTYPE_OSD_FRONTEND="gtk4"
VOXTYPE_OSD_POSITION="bottom-center"

# ── Mic widget ─────────────────────────────────────────────────────────────────
RECORDING_LABEL="RECORDING"
LABEL_FONT_SIZE=18    # points
# Path to any SVG or PNG icon. Defaults to Papirus mic icon.
# MIC_ICON="/path/to/custom-icon.svg"
MIC_ICON_SIZE=160     # pixels

# Mic icon pulse animation (opacity oscillation)
# Set PULSE_ENABLED=false when using an animated GIF as MIC_ICON —
# GTK4 will play the GIF's own animation automatically.
PULSE_ENABLED=true
PULSE_SPEED=0.025     # opacity change per tick (higher = faster)
PULSE_MIN=0.35        # minimum opacity (0.0–1.0)
PULSE_MAX=1.0         # maximum opacity (0.0–1.0)
PULSE_TICK_MS=40      # milliseconds between ticks (lower = smoother/faster)
