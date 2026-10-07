# Memory Survival iOS screenshots

Captured October 7, 2026 from the production Flutter UI on an iPhone 17 Pro
simulator. The deterministic capture uses local test services, an ad-free
entitlement, and no live account, advertising, purchase, or Game Center data.

- `raw/`: native simulator captures at 1206 x 2622 pixels.
- `iphone-6.1-6.3/`: App Store upload set at Apple's supported
  1206 x 2622 portrait size.
- `ios/fastlane/screenshots/en-US/`: mirror of that upload set for Fastlane.

The ten screens cover Home, How to play, Scenarios, Settings, an incoming
request, active memory, strategic placement, overclock pressure, a paused run,
and a leak request.

Reproduce the capture from `packages/mobile` with:

```sh
scripts/media/capture_app_store_screenshots.sh <simulator-udid>
```
