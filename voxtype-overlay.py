#!/usr/bin/python3
"""
voxtype-overlay.py — Wayland layer-shell recording overlay for VoxType

Shows a dimmed overlay across all monitors with a pulsing mic icon while
recording. The active window is kept unobscured with a highlighted border
so you can see where transcribed text will land.

Configuration is read from environment variables set by voxtype-toggle.sh.
"""
import os
import sys
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gtk4LayerShell, GLib, Gdk
import cairo


# ── Config from environment (with defaults) ─────────────────────────────────────

def _bool(key, default):
    return os.environ.get(key, str(default)).lower() in ('1', 'true', 'yes')

def _float(key, default):
    try:
        return float(os.environ.get(key, default))
    except (ValueError, TypeError):
        return float(default)

def _int(key, default):
    try:
        return int(os.environ.get(key, default))
    except (ValueError, TypeError):
        return int(default)

def _hex_color(key, default):
    raw = os.environ.get(key, default).lstrip('#')
    try:
        r = int(raw[0:2], 16) / 255
        g = int(raw[2:4], 16) / 255
        b = int(raw[4:6], 16) / 255
        return (r, g, b, 1.0)
    except (ValueError, IndexError):
        return (0.2, 0.8, 1.0, 1.0)


OVERLAY_OPACITY    = _float('VOXTYPE_OVERLAY_OPACITY', 0.55)
BORDER_ENABLED     = _bool('VOXTYPE_BORDER_ENABLED', True)
BORDER_COLOR       = _hex_color('VOXTYPE_BORDER_COLOR', '#33CCFF')
BORDER_WIDTH       = _int('VOXTYPE_BORDER_WIDTH', 4)
RECORDING_LABEL    = os.environ.get('VOXTYPE_RECORDING_LABEL', 'RECORDING')
LABEL_FONT_SIZE    = _int('VOXTYPE_LABEL_FONT_SIZE', 18)
MIC_ICON           = os.environ.get(
    'VOXTYPE_MIC_ICON',
    '/usr/share/icons/Papirus/128x128/devices/audio-input-microphone.svg'
)
MIC_ICON_SIZE      = _int('VOXTYPE_MIC_ICON_SIZE', 160)
PULSE_SPEED        = _float('VOXTYPE_PULSE_SPEED', 0.025)
PULSE_MIN          = _float('VOXTYPE_PULSE_MIN', 0.35)
PULSE_MAX          = _float('VOXTYPE_PULSE_MAX', 1.0)
PULSE_TICK_MS      = _int('VOXTYPE_PULSE_TICK_MS', 40)

PADDING = 8  # px padding added around the cutout window


# ── Active-window geometry from CLI args ────────────────────────────────────────
# Args: win_x win_y win_w win_h monitor_id monitor_x monitor_y

def parse_args():
    if len(sys.argv) >= 8:
        return {
            'win_x': int(sys.argv[1]),
            'win_y': int(sys.argv[2]),
            'win_w': int(sys.argv[3]),
            'win_h': int(sys.argv[4]),
            'mon_id': int(sys.argv[5]),
            'mon_x': int(sys.argv[6]),
            'mon_y': int(sys.argv[7]),
        }
    return None

ARGS = parse_args()

CSS = f"""
window {{ background: none; }}
.mic-label {{ color: white; font-size: {LABEL_FONT_SIZE}px; font-weight: bold; }}
""".encode()


# ── Overlay window (one per monitor) ───────────────────────────────────────────

class RecordingOverlay(Gtk.ApplicationWindow):
    def __init__(self, app, monitor, monitor_id, mon_x, mon_y):
        super().__init__(application=app)
        self.set_decorated(False)

        self.cutout = None
        if ARGS and monitor_id == ARGS['mon_id']:
            cx = ARGS['win_x'] - mon_x - PADDING
            cy = ARGS['win_y'] - mon_y - PADDING
            cw = ARGS['win_w'] + PADDING * 2
            ch = ARGS['win_h'] + PADDING * 2
            self.cutout = (cx, cy, cw, ch)

        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_monitor(self, monitor)
        for edge in (Gtk4LayerShell.Edge.TOP, Gtk4LayerShell.Edge.BOTTOM,
                     Gtk4LayerShell.Edge.LEFT, Gtk4LayerShell.Edge.RIGHT):
            Gtk4LayerShell.set_anchor(self, edge, True)
        Gtk4LayerShell.set_exclusive_zone(self, -1)
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.NONE)

        overlay = Gtk.Overlay()

        drawing = Gtk.DrawingArea()
        drawing.set_draw_func(self._draw)
        overlay.set_child(drawing)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        box.set_halign(Gtk.Align.CENTER)
        box.set_valign(Gtk.Align.CENTER)

        self._icon = Gtk.Image.new_from_file(MIC_ICON)
        self._icon.set_pixel_size(MIC_ICON_SIZE)
        box.append(self._icon)

        label = Gtk.Label(label=RECORDING_LABEL)
        label.add_css_class('mic-label')
        box.append(label)

        overlay.add_overlay(box)
        self.set_child(overlay)

        self._pulse_val = PULSE_MAX
        self._pulse_dir = -1
        GLib.timeout_add(PULSE_TICK_MS, self._pulse)

    def _draw(self, area, cr, width, height):
        # Clear entire surface to transparent
        cr.set_operator(cairo.OPERATOR_CLEAR)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)

        # Dark overlay
        cr.set_source_rgba(0, 0, 0, OVERLAY_OPACITY)
        cr.rectangle(0, 0, width, height)
        cr.fill()

        if self.cutout:
            cx, cy, cw, ch = self.cutout

            # Transparent cutout for active window
            cr.set_operator(cairo.OPERATOR_CLEAR)
            cr.rectangle(cx, cy, cw, ch)
            cr.fill()
            cr.set_operator(cairo.OPERATOR_OVER)

            # Highlight border around cutout
            if BORDER_ENABLED:
                cr.set_source_rgba(*BORDER_COLOR)
                cr.set_line_width(BORDER_WIDTH)
                half = BORDER_WIDTH / 2
                cr.rectangle(cx + half, cy + half, cw - BORDER_WIDTH, ch - BORDER_WIDTH)
                cr.stroke()

    def _pulse(self):
        self._pulse_val += self._pulse_dir * PULSE_SPEED
        if self._pulse_val <= PULSE_MIN:
            self._pulse_dir = 1
        elif self._pulse_val >= PULSE_MAX:
            self._pulse_dir = -1
        self._icon.set_opacity(max(PULSE_MIN, min(PULSE_MAX, self._pulse_val)))
        return True


# ── Application ─────────────────────────────────────────────────────────────────

class OverlayApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='com.voxtype.hyprland-overlay')

    def do_activate(self):
        display = Gdk.Display.get_default()

        css = Gtk.CssProvider()
        css.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            display, css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        monitors = display.get_monitors()
        for i in range(monitors.get_n_items()):
            monitor = monitors.get_item(i)
            geo = monitor.get_geometry()
            win = RecordingOverlay(self, monitor, i, geo.x, geo.y)
            win.present()


if __name__ == '__main__':
    app = OverlayApp()
    app.run()
