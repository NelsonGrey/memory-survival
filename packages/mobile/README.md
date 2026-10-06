# memory_survival

Flutter client for Memory Survival (iOS + Android). See the
[repository README](../../README.md) for status and structure.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Layout under `lib/`:

- `app/` — `AppServices`: ads, consent, purchases, Game Center, settings, wired in dependency order.
- `shell/` — ads, consent, ad-removal entitlement, platform sign-in, and the standard banner-slot screen shell.
- `gamecenter/` — Game Center connection (player opt-in), leaderboard, achievements, cloud save.
- `engine/` — the deterministic allocation engine: rules (`Ruleset`, versioned), waves, request generator, scenarios, scripted bots.
- `game/` — the playable screen: controller, memory tower, request and arrival widgets.
- `screens/` — home, how to play, scenario select, settings (banner above the title bar via `AdTopScaffold`), Game Center widgets.
- `theme/` — gameplay palettes and the Material theme built from them.
- `settings/` — accessibility settings.
