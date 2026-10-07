#!/usr/bin/env python3
"""Build gameplay-led marketing headers and social artwork.

The layouts use the production S2 identity and authentic iOS simulator
screenshots. No generated or illustrative gameplay is introduced.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
MARKETING = ROOT / "marketing"
MOBILE = ROOT / "packages" / "mobile"
ASSETS = MARKETING / "assets"
SCREENSHOTS = MOBILE / "output" / "app-store-screenshots" / "raw"

GRAPHITE = "#10151C"
PANEL = "#1B2430"
WHITE = "#EEF2F6"
STEEL = "#A9B4C2"
BLUE = "#2F6AA0"
MINT = "#6FD9B0"
CORAL = "#FF8A75"

BOLD = MOBILE / "assets" / "fonts" / "Sora-Bold.ttf"
REGULAR = MOBILE / "assets" / "fonts" / "Sora-Regular.ttf"
WORDMARK = ASSETS / "identity" / "wordmark.png"
MARK = ASSETS / "identity" / "mark.png"
GAMEPLAY = SCREENSHOTS / "07-strategic-placement.png"


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def background(size: tuple[int, int]) -> Image.Image:
    w, h = size
    image = Image.new("RGB", size, GRAPHITE)
    pixels = image.load()
    top = (20, 30, 40)
    bottom = (9, 15, 22)
    for y in range(h):
        t = y / max(h - 1, 1)
        row = tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(w):
            pixels[x, y] = row
    draw = ImageDraw.Draw(image, "RGBA")
    step = max(34, h // 20)
    for x in range(-h, w + h, step):
        draw.line((x, 0, x - h, h), fill=(111, 217, 176, 10), width=1)
    return image


def fit(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(max_size, Image.Resampling.LANCZOS)
    return copy


def paste_center(canvas: Image.Image, asset: Image.Image, xy: tuple[int, int]) -> None:
    x, y = xy
    canvas.paste(asset, (x - asset.width // 2, y - asset.height // 2), asset)


def phone(canvas: Image.Image, box: tuple[int, int, int, int]) -> None:
    x, y, w, h = box
    shot = Image.open(GAMEPLAY).convert("RGB")
    shot = fit(shot, (w, h))
    x += (w - shot.width) // 2
    y += (h - shot.height) // 2
    radius = max(18, shot.width // 16)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width, shot.height), radius, fill=255)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (x - 14, y - 14, x + shot.width + 14, y + shot.height + 14),
        radius + 14,
        fill=(0, 0, 0, 180),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    canvas.paste(shot.convert("RGBA"), (x, y), mask)
    ImageDraw.Draw(canvas).rounded_rectangle(
        (x - 3, y - 3, x + shot.width + 2, y + shot.height + 2),
        radius + 3,
        outline=STEEL,
        width=max(2, shot.width // 180),
    )


def wordmark(canvas: Image.Image, box: tuple[int, int, int, int]) -> None:
    x, y, w, h = box
    wm = fit(Image.open(WORDMARK).convert("RGBA"), (w, h))
    canvas.alpha_composite(wm, (x, y))


def copy_block(
    canvas: Image.Image,
    xy: tuple[int, int],
    headline_size: int,
    copy_size: int,
    status_size: int,
    compact: bool = False,
) -> None:
    x, y = xy
    draw = ImageDraw.Draw(canvas)
    headline = font(BOLD, headline_size)
    supporting = font(REGULAR, copy_size)
    status = font(BOLD, status_size)
    draw.text((x, y), "EVERY GAP IS A RISK.", font=headline, fill=WHITE)
    y += int(headline_size * 1.35)
    if not compact:
        draw.text(
            (x, y),
            "A real-time memory allocation puzzle",
            font=supporting,
            fill=STEEL,
        )
        y += int(copy_size * 1.9)
    label = "AUTHENTIC iPHONE GAMEPLAY"
    bounds = draw.textbbox((0, 0), label, font=status)
    pad_x = max(12, status_size)
    pad_y = max(7, status_size // 2)
    pill = (x, y, x + bounds[2] + pad_x * 2, y + bounds[3] + pad_y * 2)
    draw.rounded_rectangle(pill, radius=pad_y, fill=MINT)
    draw.text((x + pad_x, y + pad_y), label, font=status, fill=GRAPHITE)


def header(name: str, size: tuple[int, int], layout: str) -> None:
    w, h = size
    canvas = background(size).convert("RGBA")
    if layout == "wide":
        wordmark(canvas, (int(w * 0.055), int(h * 0.09), int(w * 0.38), int(h * 0.20)))
        copy_block(canvas, (int(w * 0.07), int(h * 0.42)), h // 12, h // 28, h // 38)
        phone(canvas, (int(w * 0.68), -int(h * 0.18), int(w * 0.22), int(h * 1.42)))
    elif layout == "slim":
        mark = fit(Image.open(MARK).convert("RGBA"), (int(h * 0.72), int(h * 0.72)))
        canvas.alpha_composite(mark, (int(w * 0.035), (h - mark.height) // 2))
        draw = ImageDraw.Draw(canvas)
        x = int(w * 0.035) + mark.width + int(h * 0.22)
        draw.text((x, int(h * 0.23)), "MEMORY SURVIVAL", font=font(BOLD, h // 5), fill=WHITE)
        draw.text((x, int(h * 0.57)), "EVERY GAP IS A RISK.", font=font(BOLD, h // 9), fill=MINT)
    elif layout == "youtube":
        # All essential content remains inside the central 1546 x 423 area.
        safe_left, safe_top = (w - 1546) // 2, (h - 423) // 2
        mark = fit(Image.open(MARK).convert("RGBA"), (330, 330))
        canvas.alpha_composite(mark, (safe_left + 30, safe_top + 46))
        x = safe_left + 410
        draw = ImageDraw.Draw(canvas)
        draw.text((x, safe_top + 82), "MEMORY SURVIVAL", font=font(BOLD, 74), fill=WHITE)
        draw.text((x, safe_top + 190), "EVERY GAP IS A RISK.", font=font(BOLD, 44), fill=MINT)
        draw.text(
            (x, safe_top + 265),
            "A real-time memory allocation puzzle",
            font=font(REGULAR, 30),
            fill=STEEL,
        )
    out = ASSETS / "headers" / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out, optimize=True)


def social(name: str, size: tuple[int, int], portrait: bool = False) -> None:
    w, h = size
    canvas = background(size).convert("RGBA")
    if portrait:
        wordmark(canvas, (int(w * 0.09), int(h * 0.055), int(w * 0.82), int(h * 0.12)))
        phone(canvas, (int(w * 0.26), int(h * 0.20), int(w * 0.48), int(h * 0.58)))
        copy_block(canvas, (int(w * 0.09), int(h * 0.83)), w // 18, w // 31, w // 40, compact=True)
    else:
        wordmark(canvas, (int(w * 0.055), int(h * 0.08), int(w * 0.44), int(h * 0.18)))
        copy_block(canvas, (int(w * 0.065), int(h * 0.46)), h // 12, h // 28, h // 39)
        phone(canvas, (int(w * 0.70), -int(h * 0.10), int(w * 0.22), int(h * 1.30)))
    out = ASSETS / "social" / f"{name}.png"
    canvas.convert("RGB").save(out, optimize=True)


def contact_sheet() -> None:
    files = sorted((ASSETS / "headers").glob("*.png")) + sorted(
        (ASSETS / "social").glob("gameplay-*.png")
    )
    thumbs = []
    for path in files:
        image = Image.open(path).convert("RGB")
        image.thumbnail((480, 260), Image.Resampling.LANCZOS)
        tile = Image.new("RGB", (500, 300), GRAPHITE)
        tile.paste(image, ((500 - image.width) // 2, 10))
        draw = ImageDraw.Draw(tile)
        draw.text((18, 272), path.name, font=font(REGULAR, 16), fill=WHITE)
        thumbs.append(tile)
    cols = 2
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 500, rows * 300), PANEL)
    for index, tile in enumerate(thumbs):
        sheet.paste(tile, ((index % cols) * 500, (index // cols) * 300))
    sheet.save(ASSETS / "campaign" / "final-asset-contact-sheet.png", optimize=True)


def main() -> None:
    required = (WORDMARK, MARK, GAMEPLAY, BOLD, REGULAR)
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise SystemExit("Missing required assets:\n" + "\n".join(missing))

    header("website-hero", (2400, 1200), "wide")
    header("apple-store-feature-5244x2950", (5244, 2950), "wide")
    header("apple-store-feature-3840x1646", (3840, 1646), "wide")
    header("x-header", (1500, 500), "wide")
    header("facebook-cover", (1640, 624), "wide")
    header("linkedin-cover", (1128, 191), "slim")
    header("youtube-channel-banner", (2560, 1440), "youtube")
    header("press-header", (2400, 800), "wide")
    header("email-header", (1200, 400), "wide")

    # Keep the stable campaign path current for existing website consumers.
    website_hero = Image.open(ASSETS / "headers" / "website-hero.png").convert("RGB")
    website_hero.save(ASSETS / "campaign" / "key-art-master.png", optimize=True)

    social("gameplay-landscape", (1600, 900))
    social("gameplay-square", (1080, 1080), portrait=True)
    social("gameplay-story", (1080, 1920), portrait=True)
    contact_sheet()


if __name__ == "__main__":
    main()
