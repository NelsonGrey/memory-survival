#!/usr/bin/env python3
"""Builds the S2 "Shrinking Safe Corridor" identity from code.

Everything is vector-first: the mark is plain polygons and rounded rects, and
all type is converted to outlines from Sora (SIL OFL, see Sora-OFL.txt) so no
SVG depends on an installed font. PNG exports are rasterised from the SVGs.

Usage (needs fonttools; rsvg-convert on PATH):
  python3 build_identity.py --font /path/to/Sora[wght].ttf --out DIR
Writes SVG masters to DIR/source and the exports to DIR/identity and
DIR/social. Pass --out marketing/assets to publish.
"""
import argparse, os, subprocess, sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

GRAPHITE, PANEL, WHITE, STEEL = "#10151C", "#1B2430", "#EEF2F6", "#A9B4C2"
BLUE, MINT, CORAL = "#2F6AA0", "#6FD9B0", "#FF8A75"
# Restrained bevel tints derived from the brand colours.
BLUE_HI, BLUE_LO = "#4F8DC4", "#244F78"
MINT_HI, MINT_LO = "#A4EBD0", "#45B58C"
CORAL_HI, CORAL_LO = "#FFB4A4", "#E2644E"

# ---------------------------------------------------------------- type
class Face:
    def __init__(self, path, wght):
        base = TTFont(path)
        self.font = instancer.instantiateVariableFont(base, {"wght": wght})
        self.cmap = self.font.getBestCmap()
        self.gs = self.font.getGlyphSet()
        self.upm = self.font["head"].unitsPerEm
        self.cap = self.font["OS/2"].sCapHeight / self.upm

    def width(self, text, size, tracking=0.0):
        w = 0.0
        for ch in text:
            w += self.font["hmtx"][self.cmap[ord(ch)]][0] * size / self.upm
            w += tracking * size
        return w - tracking * size

    def path(self, text, size, x, y, tracking=0.0, anchor="start"):
        """SVG path data for [text] with baseline at y."""
        total = self.width(text, size, tracking)
        if anchor == "middle":
            x -= total / 2
        elif anchor == "end":
            x -= total
        s = size / self.upm
        d, cx = [], x
        for ch in text:
            name = self.cmap[ord(ch)]
            pen = SVGPathPen(self.gs, ntos=lambda v: f"{v:.2f}".rstrip("0").rstrip("."))
            self.gs[name].draw(TransformPen(pen, (s, 0, 0, -s, cx, y)))
            d.append(pen.getCommands())
            cx += self.font["hmtx"][name][0] * s + tracking * size
        return " ".join(c for c in d if c)

def text(face, s, size, x, y, fill, tracking=0.0, anchor="start", opacity=None):
    op = f' fill-opacity="{opacity}"' if opacity is not None else ""
    return f'<path fill="{fill}"{op} d="{face.path(s, size, x, y, tracking, anchor)}"/>'

# A hairline that keeps the dark tile readable on dark pages.
EDGE = (f'<rect x="5" y="5" width="1014" height="1014" rx="219" fill="none" '
        f'stroke="{STEEL}" stroke-opacity="0.38" stroke-width="10"/>')

# ---------------------------------------------------------------- mark
def art(uid, ground=True, walls=True, cells=True):
    """The S2 artwork on a 1024 canvas: three contiguous cells in a narrow
    safe corridor, squeezed by two coral pressure walls. [uid] keeps clip
    ids unique when several copies share a document."""
    out = []
    if ground:
        out.append(f'<rect width="1024" height="1024" fill="{GRAPHITE}"/>')
    # The corridor the cells are still holding open.
    out.append(f'<rect x="352" y="196" width="320" height="632" rx="26" fill="{PANEL}"/>')
    if cells:
        # Three contiguous cells, wider than the corridor needs, so they
        # carry the icon. y0 centres the stack on the canvas.
        w, h, gap, x, y0 = 224, 180, 18, 400, 224
        cols = [(MINT, MINT_HI, MINT_LO), (BLUE, BLUE_HI, BLUE_LO), (BLUE, BLUE_HI, BLUE_LO)]
        defs = []
        for i, (base, hi, lo) in enumerate(cols):
            y = y0 + i * (h + gap)
            cid = f"{uid}c{i}"
            defs.append(f'<clipPath id="{cid}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="24"/></clipPath>')
            out.append(
                f'<g clip-path="url(#{cid})"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{base}"/>'
                f'<rect x="{x}" y="{y}" width="{w}" height="16" fill="{hi}"/>'
                f'<rect x="{x}" y="{y + h - 20}" width="{w}" height="20" fill="{lo}"/></g>')
        out.insert(1 if ground else 0, "<defs>" + "".join(defs) + "</defs>")
    if walls:
        # Left wall; the right one mirrors it.
        # The inner edge leans in toward the middle cell: the narrowest
        # point is 22 px from the stack, where the pressure is greatest.
        L = [(0, 90), (338, 230), (378, 390), (378, 634), (338, 794), (0, 934)]
        top = [(0, 90), (338, 230), (350, 270), (0, 132)]
        bot = [(0, 934), (338, 794), (350, 754), (0, 892)]
        def poly(pts, fill, mirror=False):
            p = [(1024 - px if mirror else px, py) for px, py in pts]
            return f'<polygon points="{" ".join(f"{a},{b}" for a, b in p)}" fill="{fill}"/>'
        for m in (False, True):
            out.append(poly(L, CORAL, m))
            out.append(poly(top, CORAL_HI, m))
            out.append(poly(bot, CORAL_LO, m))
    return "\n".join(out)

def svg(w, h, body, title=None, desc=None, defs=""):
    t = f'<title id="t">{title}</title>' if title else ""
    d = f'<desc id="d">{desc}</desc>' if desc else ""
    role = ' role="img" aria-labelledby="t d"' if title else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}"{role}>'
            f'{t}{d}{defs}\n{body}\n</svg>\n')

def tile(uid, x, y, size, rounded=True):
    """The mark as a tile placed at (x, y) with edge [size]."""
    k = size / 1024
    clip = f'<clipPath id="{uid}r"><rect width="1024" height="1024" rx="224"/></clipPath>'
    inner = art(uid)
    body = (f'<g transform="translate({x} {y}) scale({k:.6f})">{clip}'
            f'<g clip-path="url(#{uid}r)">{inner}</g>{EDGE}</g>') if rounded else \
           f'<g transform="translate({x} {y}) scale({k:.6f})">{inner}</g>'
    return body

# ------------------------------------------------------------- lockups
def wordtype(face, x, y_first, size, anchor="start", tracking=-0.02, gap=None):
    gap = gap if gap is not None else size * face.cap * 0.30
    base2 = y_first + size * face.cap + gap
    return (text(face, "MEMORY", size, x, y_first, WHITE, tracking, anchor) + "\n" +
            text(face, "SURVIVAL", size, x, base2, MINT, tracking, anchor))

def horizontal(face):
    """1200x300: tile + two-line wordmark, centred. The type block is a
    little shorter than the tile so the two read as one lockup."""
    tile_size, gap_x = 284, 40
    k = face.width("SURVIVAL", 100.0, -0.02) / (100.0 * face.cap)  # width per unit cap
    cap = min((1160 - tile_size - gap_x) / k, tile_size * 0.92 / 2.3)
    size = cap / face.cap
    gap = cap * 0.30
    block = 2 * cap + gap
    text_w = face.width("SURVIVAL", size, -0.02)
    total = tile_size + gap_x + text_w
    x0 = (1200 - total) / 2
    ty = (300 - tile_size) / 2
    y1 = (300 - block) / 2 + cap
    body = tile("h", x0, ty, tile_size) + "\n" + wordtype(face, x0 + tile_size + gap_x, y1, size, gap=gap)
    return svg(1200, 300, body, "Memory Survival",
               "Memory Survival wordmark beside the safe-corridor mark")

def stacked(face):
    """720x860: tile over centred two-line wordmark."""
    size = 112.0
    size *= 600 / face.width("SURVIVAL", size, -0.02)
    cap = size * face.cap
    gap = cap * 0.30
    y1 = 40 + 360 + 56 + cap
    height = int(y1 + gap + cap + 40)
    body = tile("s", 180, 40, 360) + "\n" + wordtype(face, 360, y1, size, "middle", gap=gap)
    return svg(720, height, body, "Memory Survival",
               "Memory Survival stacked wordmark under the safe-corridor mark")

def wordtype_stacked(face):
    """Type alone, for use without the mark."""
    size = 112.0
    size *= 600 / face.width("SURVIVAL", size, -0.02)
    cap = size * face.cap
    gap = cap * 0.30
    body = wordtype(face, 360, 40 + cap, size, "middle", gap=gap)
    return svg(720, int(40 + 2 * cap + gap + 40), body, "Memory Survival",
               "Memory Survival type lockup without the mark")

# --------------------------------------------------------------- social
def pill(face, x, y, size, label="IN DEVELOPMENT"):
    tracking = 0.12
    w = face.width(label, size, tracking) + size * 1.9
    h = size * 2.6
    r = h * 0.22
    return (f'<rect x="{x}" y="{y}" width="{w:.1f}" height="{h:.1f}" rx="{r:.1f}" fill="{MINT}"/>' +
            text(face, label, size, x + size * 0.95, y + h / 2 + size * face.cap / 2, GRAPHITE, tracking)), w, h

def bg(w, h, uid):
    """Plain graphite field: the mark carries the picture."""
    return f'<rect width="{w}" height="{h}" fill="{GRAPHITE}"/>'

def lockup_small(face, x, y, tile_size, size):
    """Tile + one-line 'MEMORY SURVIVAL' for corners of social cards."""
    t = tile("l" + str(int(x)) + str(int(y)), x, y, tile_size)
    cap = size * face.cap
    tx = x + tile_size + tile_size * 0.28
    base = y + tile_size / 2 + cap / 2
    w1 = face.width("MEMORY ", size, 0.04)
    return (t + text(face, "MEMORY", size, tx, base, WHITE, 0.04) +
            text(face, "SURVIVAL", size, tx + w1, base, MINT, 0.04))

HEAD, COPY = "Every gap is a risk.", "A real-time memory allocation puzzle."

def card_landscape(face, reg, w, h):
    s = h / 630
    m = 72 * s
    tsz = 400 * s
    body = bg(w, h, "bg") + lockup_small(face, m, m * 0.8, 52 * s, 28 * s)
    hs = 88 * s
    cap = hs * face.cap
    y1 = h * 0.50
    body += text(face, "Every gap", hs, m, y1, WHITE, -0.025)
    body += text(face, "is a risk.", hs, m, y1 + cap * 1.42, WHITE, -0.025)
    body += text(face, COPY, 29 * s, m + 2 * s, y1 + cap * 1.42 + 62 * s, STEEL, 0.0)
    p, _, ph = pill(reg, m + 2 * s, h - m * 0.8 - 50 * s, 19 * s)
    body += p
    body += tile("t", w - tsz - m * 1.1, (h - tsz) / 2, tsz)
    return svg(w, h, body, "Memory Survival — Every gap is a risk.",
               "A real-time memory allocation puzzle. In development.")

def card_square(face, reg, w, h):
    tsz = 440
    body = bg(w, h, "bg") + tile("t", (w - tsz) / 2, 96, tsz)
    hs = 104
    cap = hs * face.cap
    y1 = 96 + tsz + 56 + cap
    body += text(face, "Every gap is a risk.", hs, w / 2, y1, WHITE, -0.025, "middle")
    body += text(face, COPY, 36, w / 2, y1 + 70, STEEL, 0, "middle")
    p, pw, ph = pill(reg, 0, 0, 22)
    px = (w - pw) / 2
    body += pill(reg, px, y1 + 120, 22)[0]
    body += lockup_center(face, w, h - 76)
    return svg(w, h, body, "Memory Survival — Every gap is a risk.",
               "A real-time memory allocation puzzle. In development.")

def lockup_center(face, w, y, size=30):
    cap = size * face.cap
    w1 = face.width("MEMORY ", size, 0.04)
    w2 = face.width("SURVIVAL", size, 0.04)
    x = (w - (w1 + w2)) / 2
    return (text(face, "MEMORY", size, x, y, WHITE, 0.04) +
            text(face, "SURVIVAL", size, x + w1, y, MINT, 0.04))

def card_story(face, reg, w, h):
    tsz = 620
    body = bg(w, h, "bg") + tile("t", (w - tsz) / 2, 330, tsz)
    hs = 112
    cap = hs * face.cap
    y1 = 330 + tsz + 130 + cap
    body += text(face, "Every gap", hs, w / 2, y1, WHITE, -0.025, "middle")
    body += text(face, "is a risk.", hs, w / 2, y1 + cap * 1.42, WHITE, -0.025, "middle")
    yc = y1 + cap * 1.42 + 80
    body += text(face, COPY, 36, w / 2, yc, STEEL, 0, "middle")
    p, pw, ph = pill(reg, 0, 0, 24)
    body += pill(reg, (w - pw) / 2, yc + 70, 24)[0]
    body += lockup_center(face, w, 330 - 90, 38)
    return svg(w, h, body, "Memory Survival — Every gap is a risk.",
               "A real-time memory allocation puzzle. In development.")

def card_banner(face, reg, w, h, safe_x0, safe_x1, tsz, hs, cs, ps, below=False):
    """Wide banner: content kept inside [safe_x0, safe_x1]."""
    body = bg(w, h, "bg")
    ty = (h - tsz) / 2
    body += tile("t", safe_x0, ty, tsz)
    tx = safe_x0 + tsz + tsz * 0.2
    cap = hs * face.cap
    p, pw, ph = pill(reg, 0, 0, ps)
    if below:
        # Headline, copy and status stacked and centred on the tile.
        block = cap + cs * 1.9 + ph * 1.35
        y1 = h / 2 - block / 2 + cap
        body += text(face, HEAD, hs, tx, y1, WHITE, -0.025)
        body += text(face, COPY, cs, tx + 2, y1 + cs * 1.9, STEEL, 0)
        body += pill(reg, tx, y1 + cs * 1.9 + ph * 0.5, ps)[0]
    else:
        y1 = h / 2 - cap * 0.05
        body += text(face, HEAD, hs, tx, y1, WHITE, -0.025)
        body += text(face, COPY, cs, tx + 2, y1 + cs * 1.9, STEEL, 0)
        body += pill(reg, safe_x1 - pw, h / 2 - ph / 2, ps)[0]
    return svg(w, h, body, "Memory Survival — Every gap is a risk.",
               "A real-time memory allocation puzzle. In development.")

# ----------------------------------------------------------------- main
def sh(*a):
    subprocess.run(a, check=True)

def png(svg_path, png_path, w, h=None):
    sh("rsvg-convert", "-w", str(w), "-h", str(h or w), "-o", png_path, svg_path)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--font", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    bold, reg, semi = Face(a.font, 700), Face(a.font, 400), Face(a.font, 600)
    src, ident, soc = (os.path.join(a.out, d) for d in ("source", "identity", "social"))
    for d in (src, ident, soc):
        os.makedirs(d, exist_ok=True)
    W = lambda name, content: open(os.path.join(src, name), "w").write(content)

    # Masters. The mark is a rounded tile with transparent corners; the app
    # icon is full-bleed because iOS and Google Play apply their own masks.
    W("s2-mark.svg", svg(1024, 1024,
        f'<defs><clipPath id="r"><rect width="1024" height="1024" rx="224"/></clipPath></defs>'
        f'<g clip-path="url(#r)">{art("m")}</g>{EDGE}', "Memory Survival mark",
        "Three contiguous memory cells held open between two advancing pressure walls"))
    W("s2-app-icon.svg", svg(1024, 1024, art("a"), "Memory Survival app icon",
        "Full-bleed square app icon: a safe corridor of three cells between pressure walls"))
    W("s2-app-icon-foreground.svg", svg(1024, 1024, art("f", ground=False),
        "Memory Survival adaptive icon foreground", ""))
    W("s2-wordmark-horizontal.svg", horizontal(bold))
    W("s2-wordmark-stacked.svg", stacked(bold))
    W("s2-wordtype-stacked.svg", wordtype_stacked(bold))

    # Social cards (SVG masters + PNG exports).
    cards = {
        "og-image": (1200, 630, lambda w, h: card_landscape(semi, reg, w, h)),
        "x-landscape": (1600, 900, lambda w, h: card_landscape(semi, reg, w, h)),
        "instagram-square": (1080, 1080, lambda w, h: card_square(semi, reg, w, h)),
        "story": (1080, 1920, lambda w, h: card_story(semi, reg, w, h)),
        "linkedin-banner": (1128, 191, lambda w, h: card_banner(bold, reg, w, h, 330, 1090, 128, 44, 17, 11)),
        "youtube-banner": (2560, 1440, lambda w, h: card_banner(bold, reg, w, h, 560, 2000, 340, 96, 38, 24, below=True)),
    }
    for name, (w, h, fn) in cards.items():
        W(f"s2-social-{name}.svg", fn(w, h))
        png(os.path.join(src, f"s2-social-{name}.svg"), os.path.join(soc, f"{name}.png"), w, h)

    # Identity exports.
    S = lambda n: os.path.join(src, n)
    I = lambda n: os.path.join(ident, n)
    import shutil
    shutil.copy(S("s2-mark.svg"), I("mark.svg"))
    shutil.copy(S("s2-wordmark-horizontal.svg"), I("wordmark.svg"))
    shutil.copy(S("s2-wordmark-stacked.svg"), I("wordmark-stacked.svg"))
    png(S("s2-mark.svg"), I("mark.png"), 512)
    png(S("s2-wordmark-horizontal.svg"), I("wordmark.png"), 1200, 300)
    png(S("s2-app-icon.svg"), I("app-icon-1024.png"), 1024)
    png(S("s2-app-icon.svg"), I("app-icon-512.png"), 512)
    png(S("s2-app-icon.svg"), I("apple-touch-icon.png"), 180)
    png(S("s2-mark.svg"), I("favicon-32x32.png"), 32)
    png(S("s2-mark.svg"), I("favicon-16x16.png"), 16)

if __name__ == "__main__":
    main()
