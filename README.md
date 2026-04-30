# voxtype-hyprland-overlay

A Hyprland companion for [VoxType](https://github.com/YOUR_VOXTYPE_REPO) that adds:

- **Recording overlay** — dims all monitors with a pulsing mic icon while you dictate
- **Active window cutout** — the target window stays visible with a highlight border so you always know where text will land
- **Audio feedback** — distinct beep tones on start and stop
- **Volume ducking** — gradually fades speaker volume while recording, restores on stop
- All features are **independently toggleable** and **fully configurable**

![Overlay demo](https://example.com/demo.gif)

## Dependencies

| Package | Purpose |
|---|---|
| `voxtype` | Voice-to-text daemon |
| `hyprctl` | Active window / monitor geometry |
| `pactl`, `paplay` | Volume control and audio playback |
| `python3` | Overlay script runtime |
| `python-gobject` | GTK4 bindings |
| `python-cairo` | Drawing overlay |
| `gtk4-layer-shell` | Wayland layer-shell protocol |
| `ffmpeg` | Generating default beep sounds (one-time) |

Arch Linux:
```bash
sudo pacman -S python-gobject python-cairo gtk4-layer-shell ffmpeg
```

## Install

```bash
git clone https://github.com/YOUR_REPO/voxtype-hyprland-overlay
cd voxtype-hyprland-overlay
bash install.sh
```

Then edit `~/.config/voxtype-overlay/config.sh` — at minimum set your `SPEAKER` device:

```bash
pactl list sinks short | awk '{print $2}'
```

Add the keybind to your Hyprland config (replace the path):

```
bind = Super, C, exec, /path/to/voxtype-toggle.sh
```

And disable VoxType's built-in hotkey in `~/.config/voxtype/config.toml`:

```toml
[hotkey]
enabled = false
```

## Configuration

All settings live in `~/.config/voxtype-overlay/config.sh`. The file is well-commented — open it to see every option. Key settings:

```bash
# Turn features on/off
AUDIO_ENABLED=true
DUCK_ENABLED=true
OVERLAY_ENABLED=true
BORDER_ENABLED=true

# Overlay darkness (0.0–1.0)
OVERLAY_OPACITY=0.55

# Border appearance
BORDER_COLOR="#33CCFF"   # any hex color
BORDER_WIDTH=4            # pixels

# What text shows below the mic icon
RECORDING_LABEL="RECORDING"

# Pulse animation speed and range
PULSE_SPEED=0.025
PULSE_MIN=0.35
PULSE_MAX=1.0

# Custom sounds (leave unset to use bundled beeps)
# START_SOUND="/path/to/start.wav"
# STOP_SOUND="/path/to/stop.wav"
```

## How it works

`voxtype-toggle.sh` checks `voxtype status` to determine direction, then:

1. Captures active window geometry via `hyprctl`
2. Launches `voxtype-overlay.py` — a GTK4 layer-shell window on every monitor
3. Plays a start beep and begins volume ducking in the background
4. Calls `voxtype record toggle` to start/stop transcription
5. On stop: kills the overlay, restores volume, plays stop beep

The overlay uses Cairo with `OPERATOR_CLEAR` to punch a transparent hole over the active window, then draws a colored border around it.

## Troubleshooting

**Overlay doesn't appear** — Check that `libgtk4-layer-shell.so` exists at `/usr/lib/libgtk4-layer-shell.so`. The toggle script sets `LD_PRELOAD` to ensure it loads before libwayland-client.

**No sound** — Run `pactl list sinks short` and verify `SPEAKER` in your config matches exactly.

**Cutout is offset** — Multi-monitor setups with mixed scaling or rotation may need `PADDING` adjustment in `voxtype-overlay.py`.
