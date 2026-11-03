#!/usr/bin/env python3
"""Generates the 3 Game Center achievement icons for Memory Survival,
using the game's real dark-theme palette (lib/theme/game_theme.dart).
"""
import os

PAGE = "#10151C"
FREE = "#1B2430"
FREE_BORDER = "#7D8DA3"
USED = "#2F6AA0"
OK = "#6FD9B0"
TEXT = "#EEF2F6"

SIZE = 1024
CELL = 96
GAP = 16
CELLS = 8
START_X = (SIZE - (CELLS * CELL + (CELLS - 1) * GAP)) / 2


def strip(y, used):
    """A row of 8 memory cells; `used` is the set of occupied cell indexes."""
    parts = []
    for i in range(CELLS):
        x = START_X + i * (CELL + GAP)
        if i in used:
            parts.append(
                f'<rect x="{x}" y="{y}" width="{CELL}" height="{CELL}" rx="14" fill="{USED}"/>'
            )
        else:
            parts.append(
                f'<rect x="{x + 2}" y="{y + 2}" width="{CELL - 4}" height="{CELL - 4}" rx="12" '
                f'fill="{FREE}" stroke="{FREE_BORDER}" stroke-width="4"/>'
            )
    return "".join(parts)


def arrow_down(cx, y_top, y_bottom, color=OK):
    return (
        f'<path d="M{cx} {y_top} L{cx} {y_bottom - 36}" stroke="{color}" stroke-width="30" '
        f'stroke-linecap="round" fill="none"/>'
        f'<path d="M{cx - 58} {y_bottom - 76} L{cx} {y_bottom} L{cx + 58} {y_bottom - 76} Z" '
        f'fill="{color}" stroke="{color}" stroke-width="12" stroke-linejoin="round"/>'
    )


def write(name, body, filename=None):
    path = os.path.join(os.path.dirname(__file__), filename or f"memory_survival_{name}.svg")
    with open(path, "w") as f:
        f.write(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
            f'viewBox="0 0 {SIZE} {SIZE}"><rect width="{SIZE}" height="{SIZE}" fill="{PAGE}"/>'
            + body
            + "</svg>"
        )
    print("wrote", path)


# First allocation: an arrow drops a process into a free run of memory.
cx = START_X + 2 * (CELL + GAP) + CELL / 2  # centre of cells 1-3 block
write(
    "first_allocation",
    arrow_down(cx + 0, 170, 470) + strip(560, {1, 2, 3}),
)

# First compaction: a fragmented row is packed into one contiguous block.
write(
    "first_compaction",
    strip(230, {0, 2, 3, 5, 7})
    + arrow_down(SIZE / 2, 400, 600)
    + strip(690, {0, 1, 2, 3, 4}),
)

# Campaign complete: every cell used and a check mark above.
check = (
    f'<circle cx="512" cy="330" r="190" fill="{OK}"/>'
    f'<path d="M420 335 L492 410 L612 262" stroke="{PAGE}" stroke-width="44" '
    f'stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
)
write("campaign_complete", check + strip(640, set(range(CELLS))))


def podium(base, top, star_color, y_bottom=880):
    """Leaderboard podium: three columns of stacked cells (2nd, 1st, 3rd)
    with a star above the winner. Wording-free so it needs no localising."""
    cell, gap, col_gap = 150, 18, 36
    heights = [3, 4, 2]
    total_w = 3 * cell + 2 * col_gap
    start_x = (SIZE - total_w) / 2
    parts = []
    for c, h in enumerate(heights):
        x = start_x + c * (cell + col_gap)
        for r in range(h):
            y = y_bottom - cell - r * (cell + gap)
            color = top if (r == h - 1 and h == 4) else base
            parts.append(
                f'<rect x="{x:.1f}" y="{y}" width="{cell}" height="{cell}" rx="22" fill="{color}"/>'
            )
    import math
    cx = SIZE / 2
    cy = y_bottom - 4 * cell - 3 * gap - 100
    pts = []
    for i in range(10):
        ang = math.radians(-90 + i * 36)
        rad = 70 if i % 2 == 0 else 30
        pts.append(f"{cx + rad * math.cos(ang):.1f},{cy + rad * math.sin(ang):.1f}")
    parts.append(f'<polygon points="{" ".join(pts)}" fill="{star_color}"/>')
    return "".join(parts)


# Leaderboard icon (App Store Connect leaderboard image).
write("leaderboard", podium(USED, OK, OK), filename="leaderboard-1024.svg")
