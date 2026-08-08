<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-light.png">
  <img alt="Rise" src="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-light.png">
</picture>

[中文](./README.zh-CN.md)

# Rise

> A lightweight macOS menu bar app that displays real-time gold prices.

Rise sits quietly in your menu bar, showing the current XAU/USD (Gold) price at a glance. No windows, no distractions — just the number you need, updated every 5 minutes.

---

## Features

- **Live gold price** — Real-time XAU/USD quotes in the menu bar
- **Auto-refresh** — Automatically updates every 5 minutes
- **Manual refresh** — Click "Refresh" to fetch the latest price anytime
- **Status indicators** — Clear feedback for no key, invalid key, rate limits, and network errors
- **API key management** — Add, update, or remove your Twelve Data API key in Settings
- **Lightweight** — Menu bar only, zero Dock presence

## System Requirements

- macOS 26 or later
- A free [Twelve Data](https://twelvedata.com) API key

## Installation

### Download (Recommended)

Download the latest version from the [Releases](https://github.com/hanchaoyang/rise/releases) page. Open the `.dmg`, drag `Rise.app` to your Applications folder, and launch it.

> **Note:** Rise runs only in the menu bar — you won't see a Dock icon. Look for the gold price text in your menu bar.

### Build from Source

```bash
git clone https://github.com/hanchaoyang/rise.git
cd rise
xcodebuild -project rise.xcodeproj -scheme rise -configuration Release build
```

The built app will be at `~/Library/Developer/Xcode/DerivedData/rise-*/Build/Products/Release/rise.app`.

## Configuration

Rise needs a free API key from Twelve Data to fetch gold prices.

1. Go to [twelvedata.com](https://twelvedata.com) and create a free account
2. Copy your API key from the [dashboard](https://twelvedata.com/apikey)
3. Click the gold price in your menu bar → **Settings**
4. Paste your API key and click **Save**

The menu bar should update within a few seconds. If your key is invalid, you'll see `Gold Invalid Key`.

### Removing an API Key

Open **Settings**, clear the text field, and click **Save**. The app will return to its initial "No API Key" state.

## Usage

| Action | How |
|--------|-----|
| View price | Glance at the menu bar |
| Refresh now | Click the price → **Refresh** |
| Change API key | Click the price → **Settings** |
| About | Click the price → **About** |
| Quit | Click the price → **Quit** |

The free tier of Twelve Data allows **800 API calls per day**. At 5-minute intervals, Rise makes ~288 calls per day, well within the free limit.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| State | `@Observable` (Observation framework) |
| Networking | `URLSession` |
| Persistence | `UserDefaults` |
| Logging | `OSLog` |
| Min target | macOS 26 |

## Project Structure

```
rise/
├── RiseApp.swift              # @main entry point — menu bar + scenes
├── MenuContentView.swift      # Dropdown menu (Refresh, Settings, About, Quit)
├── SettingsView.swift         # API key configuration
├── AboutView.swift            # App info + GitHub link
├── PriceService.swift         # Singleton — fetch, cache, polling
├── Constants.swift            # API URL, intervals, window sizes
├── Logger+Extensions.swift    # OSLog category extensions
└── Assets.xcassets/           # App icon and accent color
```

## Troubleshooting

| Menu bar shows | Meaning | What to do |
|---------------|---------|------------|
| `Gold ---` | Just launched, fetching | Wait a moment |
| `Gold No API Key` | No key configured | Set your API key in Settings |
| `Gold Invalid Key` | Your key was rejected | Check your key at [twelvedata.com/apikey](https://twelvedata.com/apikey) or generate a new one |
| `Gold Rate Limited` | Too many requests | Wait — the free tier resets daily |
| `Gold Fetch Failed` | Network or server error | Check your internet connection, or wait and retry |

## License

MIT © [Han Chaoyang](https://github.com/hanchaoyang)
