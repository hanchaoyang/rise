<div align="center">
  <h1>Rise</h1>
  <p>Real-time gold price in your macOS menu bar.</p>

  <sub>Built with SwiftUI &middot; macOS 26+ &middot; Powered by <a href="https://twelvedata.com">Twelve Data</a></sub>
</div>

<br>

[中文](./README.zh-CN.md)

Rise displays the current XAU/USD price directly in your menu bar, auto-refreshed every 5 minutes. No windows, no dock icon — just the number you need.

## Get Started

1. Grab the latest `.dmg` from [Releases](https://github.com/hanchaoyang/rise/releases) and drag to **Applications**
2. Sign up at [twelvedata.com](https://twelvedata.com) to get a **free API key**
3. Click the price in your menu bar → **Settings** → paste your key → **Save**

The price appears within seconds.

| Action | Shortcut |
|---|---|
| Refresh price | Click price → **Refresh** |
| Remove API key | Clear the field in Settings → **Save** |

> The free tier gives you 800 calls per day. Rise uses roughly 288 — you'll never hit the limit.

## Build from Source

```bash
git clone https://github.com/hanchaoyang/rise.git
cd rise
xcodebuild -project rise.xcodeproj -scheme rise -configuration Release build
```

## Status Reference

<sub>The menu bar always shows your current state.</sub>

| Display | Status |
|---|---|
| `Gold $2,650.12` | All good — latest price fetched |
| `Gold ---` | Just launched, fetching data |
| `Gold No API Key` | Head to Settings and add your key |
| `Gold Invalid Key` | Your key was rejected — grab a new one at twelvedata.com |
| `Gold Rate Limited` | Free tier limit reached for today — resets automatically |
| `Gold Fetch Failed` | Network hiccup — try again or wait |

## License

MIT
