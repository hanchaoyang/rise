<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-light.png">
  <img alt="Rise" src="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-light.png">
</picture>

[中文](./README.zh-CN.md)

Rise — real-time gold price in your macOS menu bar. XAU/USD, auto-refreshed every 5 minutes. No windows, no dock icon, no distractions.

> **macOS 26+** &nbsp;|&nbsp; **SwiftUI** &nbsp;|&nbsp; Powered by [Twelve Data](https://twelvedata.com)

## Get Started

1. Download the latest `.dmg` from [Releases](https://github.com/hanchaoyang/rise/releases) and drag to Applications
2. Get a free API key at [twelvedata.com](https://twelvedata.com)
3. Click the price in your menu bar → **Settings** → paste your key → **Save**

That's it. The price appears within seconds.

| | |
|---|---|
| Refresh | Click price → **Refresh** |
| Remove key | Clear the field in Settings → **Save** |

> Free tier: 800 calls/day. Rise uses ~288 — no worries.

## Build from Source

```bash
git clone https://github.com/hanchaoyang/rise.git
cd rise
xcodebuild -project rise.xcodeproj -scheme rise -configuration Release build
```

## Status Reference

| Menu bar | Meaning |
|----------|---------|
| `Gold $2,650.12` | Price fetched successfully |
| `Gold ---` | Just launched, fetching |
| `Gold No API Key` | Configure your key in Settings |
| `Gold Invalid Key` | Key rejected — get a new one at twelvedata.com |
| `Gold Rate Limited` | Daily limit reached — resets automatically |
| `Gold Fetch Failed` | Network issue — retry or wait |

## License

MIT
