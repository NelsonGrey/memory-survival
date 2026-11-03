# Game Center achievement icons

1024×1024 PNGs, one per achievement in `docs/GAME_CENTER_SETUP.md`, named
`<achievement ID>.png`. Each `.svg` is the source; `make_icons.py` generates them from the game's
real dark-theme palette (`lib/theme/game_theme.dart`). To change one, edit
the script, then `python3 make_icons.py` and
`rsvg-convert -w 1024 -h 1024 -o NAME.png NAME.svg` (needs `rsvg-convert`);
do not hand-edit the PNG.

Upload each PNG on its achievement's page in App Store Connect → Features →
Game Center (drag it onto the image field). There is no bulk-upload API; it is
one at a time in the UI.

| File | Achievement |
| --- | --- |
| `memory_survival_first_allocation.png` | First Allocation |
| `memory_survival_first_compaction.png` | Defragmented |
| `memory_survival_campaign_complete.png` | Memory Master |
| `leaderboard-1024.png` | Leaderboard image (1024×1024, no text) |
