"""Draws the RecLite app icon (a desktop monitor with a red recording light at
its lower right) and writes every size the app ships.

    python3 tool/icon/make_icon.py            # write into the repo
    python3 tool/icon/make_icon.py --out DIR  # preview into DIR only

Needs Pillow. Geometry lives in one place (SHAPES) and is drawn to PNG and SVG.
"""

import argparse
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Palette: neutral plate, graphite monitor, film-amber part strip, tally red.
PLATE_TOP = (250, 250, 250)
PLATE_BOTTOM = (226, 226, 226)
PLATE_EDGE = (205, 205, 205)
GRAPHITE = (38, 38, 38)
SCREEN_TOP = (58, 62, 68)
SCREEN_BOTTOM = (36, 39, 44)
STRIP_TRACK = (78, 82, 88)
AMBER = (240, 162, 75)
TALLY = (226, 46, 62)
TALLY_RING = (226, 46, 62, 90)
PAUSED = (222, 136, 32)  # amber, like the macOS menu bar's paused state

# Plate units: 0..1000.
PLATE_RADIUS = 225
BEZEL = (130, 225, 870, 705, 58)
SCREEN = (166, 261, 834, 669, 26)
NECK = (452, 705, 548, 786)
BASE = (318, 786, 682, 826, 20)
DOT = (768, 688, 138)  # cx, cy, r
DOT_CUT = 170  # plate-coloured gap around the light
DOT_RING = (206, 18)  # radius, width: the "live" ring
TRAY_DOT = (730, 700, 230, 268)  # cx, cy, r, gap: big light for the tray
STRIP_Y = (590, 616)
STRIP_SEGMENTS = [(206, 386, 1.0), (398, 578, 0.55)]


def _gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
        d.line([(0, y), (w, y)], fill=c + (255,))
    return img


def render(px, plate_scale, simple, light="record", big_light=False):
    """One icon of px×px. plate_scale is the plate's share of the canvas.

    light: "record" (red, the app icon), "pause" (amber) or None (idle tray).
    big_light: the tray's larger light, so the state reads at 16 px.
    """
    ss = 4
    n = px * ss
    canvas = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    plate = n * plate_scale
    off = (n - plate) / 2

    def u(v):
        return off + v * plate / 1000

    def box(x0, y0, x1, y1):
        return [u(x0), u(y0), u(x1), u(y1)]

    def r(v):
        return v * plate / 1000

    # Plate with a soft top-to-bottom light, like a desk under a window.
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        box(0, 0, 1000, 1000), radius=r(PLATE_RADIUS), fill=255
    )
    canvas.paste(_gradient((n, n), PLATE_TOP, PLATE_BOTTOM), (0, 0), mask)
    d = ImageDraw.Draw(canvas)
    if not simple:
        d.rounded_rectangle(
            box(0, 0, 1000, 1000),
            radius=r(PLATE_RADIUS),
            outline=PLATE_EDGE,
            width=max(1, round(r(4))),
        )

    # Monitor.
    x0, y0, x1, y1, rad = BEZEL
    d.rounded_rectangle(box(x0, y0, x1, y1), radius=r(rad), fill=GRAPHITE)
    sx0, sy0, sx1, sy1, srad = SCREEN
    smask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(smask).rounded_rectangle(
        box(sx0, sy0, sx1, sy1), radius=r(srad), fill=255
    )
    canvas.paste(_gradient((n, n), SCREEN_TOP, SCREEN_BOTTOM), (0, 0), smask)
    d = ImageDraw.Draw(canvas)
    d.rectangle(box(*NECK), fill=GRAPHITE)
    bx0, by0, bx1, by1, brad = BASE
    d.rounded_rectangle(box(bx0, by0, bx1, by1), radius=r(brad), fill=GRAPHITE)

    # The part strip on screen (RecLite's signature), dropped at tiny sizes.
    if not simple:
        ty0, ty1 = STRIP_Y
        for a, b, fill in STRIP_SEGMENTS:
            d.rounded_rectangle(
                box(a, ty0, b, ty1), radius=r(8), fill=STRIP_TRACK
            )
            d.rounded_rectangle(
                box(a, ty0, a + (b - a) * fill, ty1), radius=r(8), fill=AMBER
            )

    if light is None:
        return canvas.resize((px, px), Image.LANCZOS)

    # Recording light: cut out of the monitor, then the dot and its live ring.
    cx, cy, dr = DOT
    cut = DOT_CUT if not simple else DOT_CUT + 8
    dr = dr if not simple else dr + 22
    if big_light:
        cx, cy, dr, cut = TRAY_DOT
    d.ellipse(box(cx - cut, cy - cut, cx + cut, cy + cut), fill=PLATE_BOTTOM)
    if not simple and light == "record":
        ring_r, ring_w = DOT_RING
        ring = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        ImageDraw.Draw(ring).ellipse(
            box(cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r),
            outline=TALLY_RING,
            width=round(r(ring_w)),
        )
        canvas = Image.alpha_composite(canvas, ring)
        d = ImageDraw.Draw(canvas)
    d.ellipse(
        box(cx - dr, cy - dr, cx + dr, cy + dr),
        fill=TALLY if light == "record" else PAUSED,
    )

    return canvas.resize((px, px), Image.LANCZOS)


def svg():
    """The same drawing as a 1024 SVG (full-bleed plate), for editing."""
    s = 1024 / 1000

    def v(x):
        return round(x * s, 1)

    def rr(x0, y0, x1, y1, rad, fill):
        return (
            f'<rect x="{v(x0)}" y="{v(y0)}" width="{v(x1 - x0)}" '
            f'height="{v(y1 - y0)}" rx="{v(rad)}" fill="{fill}"/>'
        )

    def hexc(c):
        return "#%02X%02X%02X" % c[:3]

    cx, cy, dr = DOT
    ring_r, ring_w = DOT_RING
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" '
        'width="1024" height="1024">',
        "<defs>",
        f'<linearGradient id="plate" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{hexc(PLATE_TOP)}"/>'
        f'<stop offset="1" stop-color="{hexc(PLATE_BOTTOM)}"/></linearGradient>',
        f'<linearGradient id="screen" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{hexc(SCREEN_TOP)}"/>'
        f'<stop offset="1" stop-color="{hexc(SCREEN_BOTTOM)}"/></linearGradient>',
        "</defs>",
        f'<rect x="0" y="0" width="1024" height="1024" rx="{v(PLATE_RADIUS)}" '
        f'fill="url(#plate)" stroke="{hexc(PLATE_EDGE)}" stroke-width="4"/>',
        rr(*BEZEL, hexc(GRAPHITE)),
        rr(*SCREEN[:4], SCREEN[4], "url(#screen)"),
        rr(*NECK, 0, hexc(GRAPHITE)),
        rr(*BASE, hexc(GRAPHITE)),
    ]
    for a, b, fill in STRIP_SEGMENTS:
        parts.append(rr(a, STRIP_Y[0], b, STRIP_Y[1], 8, hexc(STRIP_TRACK)))
        parts.append(
            rr(a, STRIP_Y[0], a + (b - a) * fill, STRIP_Y[1], 8, hexc(AMBER))
        )
    parts += [
        f'<circle cx="{v(cx)}" cy="{v(cy)}" r="{v(DOT_CUT)}" '
        f'fill="{hexc(PLATE_BOTTOM)}"/>',
        f'<circle cx="{v(cx)}" cy="{v(cy)}" r="{v(ring_r)}" fill="none" '
        f'stroke="{hexc(TALLY)}" stroke-opacity="0.35" '
        f'stroke-width="{v(ring_w)}"/>',
        f'<circle cx="{v(cx)}" cy="{v(cy)}" r="{v(dr)}" fill="{hexc(TALLY)}"/>',
        "</svg>",
    ]
    return "\n".join(parts) + "\n"


# Windows and in-app: plate nearly fills the square. macOS: Apple's 824/1024
# grid so the icon sits right next to other Dock icons.
FULL = 0.94
MAC = 824 / 1024
SIMPLE_BELOW = 40


def icon(px, scale, light="record", tray=False):
    return render(
        px, scale, simple=tray or px < SIMPLE_BELOW, light=light, big_light=tray
    )


# Windows tray (notification area): small sizes for 100-300% scaling.
TRAY_SIZES = [16, 20, 24, 32, 40, 48]
TRAY_ICONS = {"tray_idle": None, "tray_recording": "record", "tray_paused": "pause"}


def save_ico(path, sizes, light, tray=False):
    images = [icon(px, FULL, light, tray) for px in sizes]
    images[-1].save(
        path,
        format="ICO",
        sizes=[(px, px) for px in sizes],
        append_images=images[:-1],
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", help="preview folder instead of the repo")
    args = parser.parse_args()

    if args.out:
        os.makedirs(args.out, exist_ok=True)
        for px in (1024, 256, 64, 32, 24, 16):
            icon(px, FULL).save(os.path.join(args.out, f"full_{px}.png"))
            icon(px, MAC).save(os.path.join(args.out, f"mac_{px}.png"))
        for name, light in TRAY_ICONS.items():
            for px in TRAY_SIZES:
                icon(px, FULL, light, tray=True).save(
                    os.path.join(args.out, f"{name}_{px}.png")
                )
        with open(os.path.join(args.out, "reclite_icon.svg"), "w") as f:
            f.write(svg())
        return

    icon(256, FULL).save(os.path.join(ROOT, "assets", "reclite_icon.png"))
    with open(os.path.join(ROOT, "assets", "reclite_icon.svg"), "w") as f:
        f.write(svg())

    mac_dir = os.path.join(
        ROOT, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    for px in (16, 32, 64, 128, 256, 512, 1024):
        icon(px, MAC).save(os.path.join(mac_dir, f"app_icon_{px}.png"))

    resources = os.path.join(ROOT, "windows", "runner", "resources")
    save_ico(
        os.path.join(resources, "app_icon.ico"),
        [16, 20, 24, 32, 40, 48, 64, 96, 128, 256],
        "record",
    )
    for name, light in TRAY_ICONS.items():
        save_ico(
            os.path.join(resources, f"{name}.ico"), TRAY_SIZES, light, tray=True
        )


if __name__ == "__main__":
    main()
