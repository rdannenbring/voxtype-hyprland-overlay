# voxtype-hyprland-overlay

A Hyprland companion for [VoxType](https://github.com/YOUR_VOXTYPE_REPO) that adds:

- **Recording overlay** — dims all monitors with a pulsing mic icon while you dictate
- **Active window cutout** — the target window stays visible with a highlight border so you always know where text will land
- **Audio feedback** — distinct beep tones on start and stop
- **Volume ducking** — gradually fades speaker volume while recording, restores on stop
- All features are **independently toggleable** and **fully configurable**

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
git clone https://github.com/rdannenbring/voxtype-hyprland-overlay
cd voxtype-hyprland-overlay
bash install.sh
```

Then edit `~/.config/voxtype-overlay/config.sh` — at minimum set your `SPEAKER` device.

Run one of the following to list available output devices:

```bash
# Option 1 — pactl (PipeWire/PulseAudio), shows ALSA sink names
pactl list sinks | grep -E 'Name:|Description:'

# Option 2 — wpctl (WirePlumber), shows friendly names alongside sink IDs
wpctl status

# Option 3 — pactl short form (tab-separated: id, name, driver, format, state)
pactl list sinks short
```

Look for the **Name:** value (e.g. `alsa_output.pci-0000_80_1f.3.analog-stereo`) from option 1 or 3, or use the friendly name shown by `wpctl status` to identify the right device. Set that name as `SPEAKER` in your config.

Add the keybind to your Hyprland config (replace the path):

```
bind = Super, C, exec, /path/to/voxtype-toggle.sh
```

And disable VoxType's built-in hotkey in `~/.config/voxtype/config.toml`:

```toml
[hotkey]
enabled = false
```

## Settings reference

All settings live in `~/.config/voxtype-overlay/config.sh`.

---

### Speaker device

```bash
SPEAKER="alsa_output.pci-0000_80_1f.3.analog-stereo"
```

The ALSA sink name used for audio feedback and volume ducking. Run `pactl list sinks short | awk '{print $2}'` to list available devices. Leave empty (`SPEAKER=""`) to disable all audio features and use the overlay only.

---

### Audio feedback

```bash
AUDIO_ENABLED=true
```

Whether to play a sound when recording starts and stops. Requires `SPEAKER` to be set.

```bash
START_SOUND="/path/to/start.wav"
STOP_SOUND="/path/to/stop.wav"
```

Paths to WAV files for the start and stop tones. When unset, the bundled beeps from `sounds/` are used. You can supply any WAV file — a spoken word, a sound effect, whatever you prefer.

```bash
SOUND_VOLUME=65536
```

Playback volume for the feedback sounds. Range is `0`–`65536`, where `65536` is 100%. This is independent of the speaker's main volume, so the beeps stay audible even when ducking is active.

---

### Volume ducking

```bash
DUCK_ENABLED=true
```

When enabled, the speaker volume is gradually faded down to `DUCK_VOLUME` as soon as recording starts, then faded back to its original level when recording stops. Useful for keeping background music from competing with your voice.

```bash
DUCK_VOLUME=15
```

The volume percentage to duck to while recording (0–100). `15` means 15% of the speaker's maximum.

```bash
DUCK_FADE_STEPS=20
DUCK_FADE_DELAY=0.025
```

Controls the fade curve. Total fade duration = `DUCK_FADE_STEPS × DUCK_FADE_DELAY` seconds (default: 20 × 0.025 = 0.5 s). More steps with a shorter delay gives a smoother fade; fewer steps with a longer delay gives a more stepped feel.

---

### Overlay

```bash
OVERLAY_ENABLED=true
```

Whether to show the dim overlay at all. Disable this if you only want audio features.

```bash
OVERLAY_OPACITY=0.55
```

How dark the overlay is. `0.0` is fully transparent (invisible), `1.0` is solid black. `0.55` is a comfortable dim that's clearly visible without being jarring.

---

### Window highlight border

```bash
BORDER_ENABLED=true
```

Whether to draw a colored border around the active window's cutout. The border makes it obvious which window will receive the transcribed text.

```bash
BORDER_COLOR="#33CCFF"
```

Color of the highlight border as a hex value. Any standard hex color works — e.g. `"#FF4444"` for red, `"#33FF88"` for green, `"#FFAA00"` for amber.

```bash
BORDER_WIDTH=4
```

Thickness of the border in pixels.

---

### Mic widget

```bash
RECORDING_LABEL="RECORDING"
```

The text displayed below the mic icon during recording. Change it to anything you like — `"Listening..."`, `"🎙 Speak now"`, or leave it empty (`""`) to show no label.

```bash
LABEL_FONT_SIZE=18
```

Font size of the label in points.

```bash
MIC_ICON="/usr/share/icons/Papirus/128x128/devices/audio-input-microphone.svg"
```

Path to the icon shown in the center of the overlay. Supports SVG, PNG, and animated GIF. Any size works — use `MIC_ICON_SIZE` to scale it. To use an animated GIF, point this at your GIF and set `PULSE_ENABLED=false` so the built-in pulse doesn't conflict with the GIF's own animation.

```bash
MIC_ICON_SIZE=160
```

Display size of the icon in pixels (width and height).

---

### Pulse animation

The pulse animation fades the mic icon's opacity up and down continuously while recording to draw attention to it.

```bash
PULSE_ENABLED=true
```

Set to `false` to disable the pulse — recommended when using an animated GIF as `MIC_ICON`, since GTK4 will play the GIF's animation automatically.

```bash
PULSE_SPEED=0.025
```

How much the opacity changes per tick. Higher values make the pulse faster and more dramatic; lower values make it slow and subtle. Typical range: `0.01`–`0.05`.

```bash
PULSE_MIN=0.35
PULSE_MAX=1.0
```

The opacity range the pulse oscillates between. `PULSE_MIN=0.35` means the icon fades to 35% opacity at its dimmest. Setting `PULSE_MIN` close to `PULSE_MAX` produces a very subtle shimmer.

```bash
PULSE_TICK_MS=40
```

Milliseconds between each pulse step. Lower values produce a smoother animation; higher values produce a more stepped effect. `40` ms (25 fps) is a good balance.

---

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
