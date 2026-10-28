#!/usr/bin/env python3
import ctypes.util, hashlib, json, os, signal, subprocess, sys, threading, urllib.parse, urllib.request

# gtk-layer-shell has to be loaded before anything else
if "GTK_LAYER_SHELL_LOADED" not in os.environ:
    _lib = ctypes.util.find_library("gtk-layer-shell")
    if _lib:
        os.environ["GTK_LAYER_SHELL_LOADED"] = "1"
        os.environ["LD_PRELOAD"] = (_lib + " " + os.environ.get("LD_PRELOAD", "")).strip()
        os.execv(sys.executable, [sys.executable] + sys.argv)
os.environ.pop("LD_PRELOAD", None)

PID_FILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "music-popup.pid")

# already open? then this click closes it
try:
    old = int(open(PID_FILE).read().strip())
    os.kill(old, 0)
    os.kill(old, signal.SIGTERM)
    sys.exit(0)
except (FileNotFoundError, ValueError, ProcessLookupError, PermissionError):
    pass

with open(PID_FILE, "w") as f:
    f.write(str(os.getpid()))


def cleanup():
    try:
        if open(PID_FILE).read().strip() == str(os.getpid()):
            os.remove(PID_FILE)
    except OSError:
        pass


try:
    import gi
    gi.require_version("Gtk", "3.0")
    gi.require_version("Gdk", "3.0")
    from gi.repository import GLib
    GLib.set_prgname("music-popup")
    from gi.repository import Gdk, GdkPixbuf, Gtk, Pango
    try:
        gi.require_version("GtkLayerShell", "0.1")
        from gi.repository import GtkLayerShell
    except Exception:
        GtkLayerShell = None
except Exception as e:
    print("music-popup needs python-gobject and gtk3:", e, file=sys.stderr)
    cleanup()
    sys.exit(1)

SEP = chr(31)
CACHE = os.path.expanduser("~/.cache/music-popup")
os.makedirs(CACHE, exist_ok=True)

CSS = b"""
window { background-color: #000000; color: #ffffff; }
window.layer { border: 2px solid #ffffff; }
label { color: #ffffff; }
.title { font-size: 16px; font-weight: bold; }
.artist { color: #9a9a9a; font-size: 12px; }
.time { color: #6b6b6b; font-size: 11px; }
button { background-image: none; background-color: transparent; border: none;
         box-shadow: none; text-shadow: none; color: #ffffff;
         padding: 8px 12px; border-radius: 10px; }
button:hover { background-color: #ffffff; color: #000000; }
button.play { background-color: #ffffff; color: #000000; border-radius: 999px; padding: 12px 16px; }
button.play:hover { background-color: #cfcfcf; }
button.dim { color: #6b6b6b; }
button.dim:hover { color: #000000; }
scale trough { background-image: none; background-color: #1a1a1a; min-height: 4px; border-radius: 4px; border: none; }
scale highlight { background-image: none; background-color: #ffffff; border-radius: 4px; border: none; }
scale slider { background-image: none; background-color: #ffffff; min-width: 12px; min-height: 12px;
               border-radius: 999px; border: none; box-shadow: none; margin: -4px; }
"""


def pc(*args):
    r = subprocess.run(["playerctl", *args], capture_output=True, text=True)
    return r.returncode, r.stdout.strip()


def fetch_art(url):
    if url.startswith("file://"):
        return urllib.parse.unquote(url[7:])
    path = os.path.join(CACHE, hashlib.md5(url.encode()).hexdigest())
    if not os.path.exists(path):
        req = urllib.request.Request(url, headers={"User-Agent": "music-popup"})
        with urllib.request.urlopen(req, timeout=5) as r, open(path, "wb") as f:
            f.write(r.read())
    return path


def fmt(sec):
    sec = max(0, int(sec))
    return f"{sec // 60}:{sec % 60:02d}"


def icon_button(icon, callback, cls=None):
    b = Gtk.Button()
    img = Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.LARGE_TOOLBAR)
    b.add(img)
    b.set_relief(Gtk.ReliefStyle.NONE)
    b.connect("clicked", callback)
    if cls:
        b.get_style_context().add_class(cls)
    return b, img


class Popup(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.set_title("music-popup")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(300, -1)
        self.set_border_width(18)
        self.art_url = None
        self.seeking = False
        self.vol_busy = False
        self.connect("key-press-event", self.on_key)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.add(box)

        self.cover = Gtk.Image()
        self.cover.set_size_request(220, 220)
        box.pack_start(self.cover, False, False, 0)

        self.title = Gtk.Label()
        self.title.get_style_context().add_class("title")
        self.title.set_ellipsize(Pango.EllipsizeMode.END)
        self.title.set_max_width_chars(26)
        box.pack_start(self.title, False, False, 0)

        self.artist = Gtk.Label()
        self.artist.get_style_context().add_class("artist")
        self.artist.set_ellipsize(Pango.EllipsizeMode.END)
        self.artist.set_max_width_chars(30)
        box.pack_start(self.artist, False, False, 0)

        self.prog = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 1)
        self.prog.set_draw_value(False)
        self.prog.connect("button-press-event", self.on_seek_press)
        self.prog.connect("button-release-event", self.on_seek_release)
        box.pack_start(self.prog, False, False, 0)

        times = Gtk.Box()
        self.t_cur = Gtk.Label(label="0:00")
        self.t_len = Gtk.Label(label="0:00")
        for t in (self.t_cur, self.t_len):
            t.get_style_context().add_class("time")
        times.pack_start(self.t_cur, False, False, 0)
        times.pack_end(self.t_len, False, False, 0)
        box.pack_start(times, False, False, 0)

        row = Gtk.Box(spacing=4)
        row.set_halign(Gtk.Align.CENTER)
        self.b_shuffle, _ = icon_button("media-playlist-shuffle-symbolic", self.on_shuffle, "dim")
        b_prev, _ = icon_button("media-skip-backward-symbolic", lambda _b: self.act("previous"))
        self.b_play, self.img_play = icon_button("media-playback-start-symbolic", lambda _b: self.act("play-pause"), "play")
        b_next, _ = icon_button("media-skip-forward-symbolic", lambda _b: self.act("next"))
        self.b_loop, self.img_loop = icon_button("media-playlist-repeat-symbolic", self.on_loop, "dim")
        for b in (self.b_shuffle, b_prev, self.b_play, b_next, self.b_loop):
            row.pack_start(b, False, False, 0)
        box.pack_start(row, False, False, 4)

        self.vol = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 0.05)
        self.vol.set_draw_value(False)
        self.vol.connect("change-value", self.on_vol)
        self.vol.connect("button-press-event", self.on_vol_press)
        self.vol.connect("button-release-event", self.on_vol_release)
        box.pack_start(self.vol, False, False, 0)

    # ---- actions ----
    def soon(self):
        GLib.timeout_add(200, lambda: (self.refresh(), False)[1])

    def act(self, cmd):
        pc(cmd)
        self.soon()

    def on_shuffle(self, _b):
        pc("shuffle", "toggle")
        self.soon()

    def on_loop(self, _b):
        cur = pc("loop")[1]
        pc("loop", {"None": "Playlist", "Playlist": "Track", "Track": "None"}.get(cur, "None"))
        self.soon()

    def on_seek_press(self, *_):
        self.seeking = True
        return False

    def on_seek_release(self, scale, _e):
        pc("position", str(scale.get_value()))
        self.seeking = False
        return False

    def on_vol(self, _s, _scroll, value):
        pc("volume", f"{max(0.0, min(1.0, value)):.2f}")
        return False

    def on_vol_press(self, *_):
        self.vol_busy = True
        return False

    def on_vol_release(self, *_):
        self.vol_busy = False
        return False

    def on_key(self, _w, event):
        if event.keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            Gtk.main_quit()
        return False

    # ---- cover art ----
    def load_art(self, url):
        try:
            path = fetch_art(url) if url else None
        except Exception:
            path = None
        GLib.idle_add(self.set_cover, url, path)

    def set_cover(self, url, path):
        if url != self.art_url:
            return False
        pb = None
        if path:
            try:
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, 220, 220, True)
            except Exception:
                pb = None
        if pb:
            self.cover.set_from_pixbuf(pb)
        else:
            self.cover.set_from_icon_name("audio-x-generic-symbolic", Gtk.IconSize.DIALOG)
        return False

    # ---- periodic update ----
    def refresh(self):
        fmt_str = SEP.join(["{{status}}", "{{artist}}", "{{title}}",
                            "{{mpris:artUrl}}", "{{mpris:length}}", "{{volume}}"])
        rc, out = pc("metadata", "--format", fmt_str)
        if rc != 0 or not out:
            return False
        status, artist, title, art, length, vol = (out.split(SEP) + [""] * 6)[:6]

        self.title.set_text(title or "Nothing playing")
        self.artist.set_text(artist)
        self.img_play.set_from_icon_name(
            "media-playback-pause-symbolic" if status == "Playing" else "media-playback-start-symbolic",
            Gtk.IconSize.LARGE_TOOLBAR)

        try:
            total = int(length) / 1e6
        except ValueError:
            total = 0
        rc2, pos = pc("position")
        try:
            cur = float(pos) if rc2 == 0 else 0
        except ValueError:
            cur = 0
        if not self.seeking:
            self.prog.set_range(0, max(total, 1))
            self.prog.set_value(min(cur, max(total, 1)))
        self.t_cur.set_text(fmt(cur))
        self.t_len.set_text(fmt(total))

        if not self.vol_busy:
            try:
                self.vol.set_value(float(vol))
            except ValueError:
                pass

        sh = pc("shuffle")[1]
        ctx = self.b_shuffle.get_style_context()
        ctx.remove_class("dim") if sh == "On" else ctx.add_class("dim")
        lp = pc("loop")[1]
        ctx = self.b_loop.get_style_context()
        ctx.remove_class("dim") if lp in ("Track", "Playlist") else ctx.add_class("dim")
        self.img_loop.set_from_icon_name(
            "media-playlist-repeat-song-symbolic" if lp == "Track" else "media-playlist-repeat-symbolic",
            Gtk.IconSize.LARGE_TOOLBAR)

        if art != self.art_url:
            self.art_url = art
            threading.Thread(target=self.load_art, args=(art,), daemon=True).start()
        return True


WIDTH = 300        # card width
BOTTOM_GAP = 10    # gap between the card and the bar
NUDGE_X = 0        # move the card left (-) or right (+)
WS_BTN = 32        # width of one workspace button
CHAR_W = 8.4       # width of one character of the song title


def group_center_x():
    ids = {1, 2, 3}
    try:
        for w in json.loads(subprocess.check_output(["hyprctl", "workspaces", "-j"], text=True)):
            if w["id"] > 0:
                ids.add(w["id"])
    except Exception:
        pass
    title = pc("metadata", "--format", "{{title}}")[1]
    chars = min(len(title), 25)
    left = len(ids) * WS_BTN + 6
    group = (24 + CHAR_W * chars) + 104
    return left + group / 2 + NUDGE_X


provider = Gtk.CssProvider()
provider.load_from_data(CSS)
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider,
                                         Gtk.STYLE_PROVIDER_PRIORITY_USER)

win = Popup()
win.connect("destroy", Gtk.main_quit)

if GtkLayerShell is not None and GtkLayerShell.is_supported():
    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_namespace(win, "music-popup")
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.ON_DEMAND)
    GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.BOTTOM, True)
    GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.LEFT, True)
    GtkLayerShell.set_margin(win, GtkLayerShell.Edge.LEFT, max(4, int(group_center_x() - WIDTH / 2)))
    GtkLayerShell.set_margin(win, GtkLayerShell.Edge.BOTTOM, BOTTOM_GAP)
    win.get_style_context().add_class("layer")

if not win.refresh():
    cleanup()
    sys.exit(0)

win.show_all()


def tick():
    ok = win.refresh()
    if not ok:
        Gtk.main_quit()
    return ok


GLib.timeout_add(1000, tick)
Gtk.main()
cleanup()
