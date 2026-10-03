# Asset Provenance Register

Satisfies MAS-BR-009: every visual, audio, UI, code, writing, and level asset
is original or backed by a retained license record. Add a row whenever a
third-party asset enters the repository, and keep the license text beside the
asset.

## Fonts

| Asset | Files | Source | License | License text | Retrieved |
| --- | --- | --- | --- | --- | --- |
| Sora (Regular 400, SemiBold 600, Bold 700) | `packages/mobile/assets/fonts/Sora-*.ttf` | Google Fonts static instances (fonts.gstatic.com/s/sora/v17); upstream https://github.com/sora-xor/sora-font. Copied from the Intercept Echo repo, which retrieved them 2026-09-24. | SIL Open Font License 1.1 | `packages/mobile/assets/fonts/Sora-OFL.txt` | 2026-10-03 |

Notes:

- The font is bundled unmodified. The OFL allows bundling in a commercial
  app; it forbids selling the font on its own.
- The OFL text is registered with `LicenseRegistry` in
  `packages/mobile/lib/main.dart`, so it appears on the in-app licences page.

SHA-256 of the bundled files:

```
a50f5d254fc0fb83125fceffb72a95d036b8ce964a77fb8cc42ecb9ce16b0427  Sora-Bold.ttf
1b547e90e4c49aa12e9a35ca8acc91732e188aa9fdbe08d2299ea4d4cae72145  Sora-Regular.ttf
4e79171a1720d04b72eb68bd7604f85888c31c05bb6b432147d4524e9439af30  Sora-SemiBold.ttf
```

## Code

`lib/shell/` and `lib/gamecenter/` were ported from the first-party Intercept
Echo repo (same owner). No third-party code was added.

## Visual identity, audio, and levels

Not yet created. The current palettes are plain placeholders; the original
visual metaphor and audio identity (MAS-BR-009) are still to be designed.
