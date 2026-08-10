# RISE 国际化设计方案

---

## 一、项目现状

| 属性 | 值 |
|------|-----|
| 平台 | macOS 26.0（SwiftUI） |
| 架构 | `@Observable` + `@MainActor`，无 ViewModel 层 |
| 存储 | `UserDefaults`（API Key） |
| 依赖 | 零外部依赖，纯 Apple 原生 API |
| 已有本地化配置 | `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`、`SWIFT_EMIT_LOC_STRINGS = YES`、`STRING_CATALOG_GENERATE_SYMBOLS = YES`、`developmentRegion = en` |
| 源代码文件 | 6 个 Swift 文件 |

---

## 二、需求逐条对照

| # | 要求 | 实现 |
|---|------|------|
| 1 | 设置窗口增加语言选项，位于 API Key 输入框下方，下拉列表，保存实时切换 | SettingsView 中在 TextField 和 Save 按钮之间插入 `
.pickerStyle(.menu)` Picker；Save 按钮同时执行 `updateAPIKey` + `currentLanguage = selectedLanguage`；`@Observable` 驱动 UI 即时重渲染 |
| 2 | 必须支持扩展 | `SupportedLanguage` enum +1 case、`.xcstrings` +1 列，无需改视图代码 |
| 3 | 只翻译文字，日志不翻译 | 菜单栏 Gold + 状态（6 个）、菜单文字（4 个）、窗口内文字（8 个），共 18 个唯一 key；窗口标题与菜单文字共享 `About`、`Settings` 二键；PriceService 中所有 Logger 输出不动 |
| 4 | 最小化改造，不影响业务代码 | 新增 2 文件，修改 5 文件；`PriceService.swift`、`Logger+Extensions.swift` 零改动；Save 按钮仅增加 1 行 `loc.currentLanguage = selectedLanguage` |
| 5 | 生产级主流国际化方案 | Apple String Catalog（`.xcstrings`）+ `Bundle.localizedString` + `@Observable`，零外部依赖 |
| 6 | 代码风格与项目一致 | `// MARK: -`、`///` 文档注释、`@MainActor @Observable`、4 空格缩进、PascalCase/camelCase |
| 7 | 干净整洁优雅 | 80 行新增代码，零协议、零依赖注入、零抽象层 |
| 8 | 语言选项为对应语言文字 | `displayName` 返回 `"English"` / `"简体中文"` / `"繁體中文"` |
| 9 | macOS 26 最新 API | `@Observable`、`.xcstrings`、`Locale(identifier:)`、`.pickerStyle(.menu)`、`.onChange(of:_:)` 双参数 |

---

## 三、架构总览

```
┌─────────────────────────────────────────┐
│           Localizable.xcstrings         │  ← 翻译数据库
│  key = 英文原文, en / zh-Hans / zh-Hant │
└──────────────┬──────────────────────────┘
               │ 读取（Bundle.localizedString）
┌──────────────▼──────────────────────────┐
│        LocalizationManager (单例)       │  ← @Observable，驱动 UI
│  currentLanguage → AppleLanguages       │
│  localizedString(forKey:) → Bundle...   │
└──────────────┬──────────────────────────┘
               │ .localized
┌──────────────▼──────────────────────────┐
│   riseApp / MenuContentView /           │  ← 视图层
│   SettingsView / AboutView              │     仅替换字符串，不动逻辑
└─────────────────────────────────────────┘
```

### 运行时切换流程

```
用户在 SettingsView 的 Picker 中选择语言
 → @State selectedLanguage 更新（仅本地状态，未写入全局）
用户点击 Save
 → PriceService.shared.updateAPIKey(apiKey)
 → LocalizationManager.shared.currentLanguage = selectedLanguage
   → didSet: UserDefaults["appLanguage"] = rawValue
   → didSet: AppleLanguages = [rawValue]
   → @Observable 触发所有读取 currentLanguage 的视图重渲染
 → 菜单栏文字即时更新（riseApp.priceLabel 重算）
 → 菜单内容即时更新（MenuContentView 重渲染）
 → Settings 窗口标题即时更新（onChange）
 → About 窗口标题即时更新（onChange）
 → isSaved = true（显示"Saved"反馈）
```

### 为什么 `AppleLanguages` 能实时生效

`Bundle.localizedString(forKey:value:table:)` 底层调用 `CFBundleCopyLocalizedString`，该方法每次调用时实时读取 `UserDefaults` 中的 `AppleLanguages` 数组，因此无需重启 App。

---

## 四、新增文件

### 4.1 `rise/LocalizationManager.swift`

**完整代码：**

```swift
import Foundation

// MARK: - Localization Manager

/// Singleton that manages runtime language switching.
///
/// Persists the selected language to `UserDefaults` and sets `AppleLanguages`
/// so that `Bundle.localizedString` resolves translations from the correct
/// language in the app's String Catalog. Conforms to `Observable` so that
/// SwiftUI views automatically refresh when the language changes.
@Observable
final class LocalizationManager {

    /// Shared singleton instance.
    static let shared = LocalizationManager()

    // MARK: - Supported Languages

    /// Languages available in the Settings picker.
    enum SupportedLanguage: String, CaseIterable, Identifiable {
        case english            = "en"
        case simplifiedChinese  = "zh-Hans"
        case traditionalChinese = "zh-Hant"

        var id: String { rawValue }

        /// Display name in the language itself (e.g. "English", "简体中文").
        var displayName: String {
            switch self {
            case .english:            return "English"
            case .simplifiedChinese:  return "简体中文"
            case .traditionalChinese: return "繁體中文"
            }
        }
    }

    // MARK: - Properties

    /// Currently active language. Changing this property persists the selection
    /// and updates `AppleLanguages` so that all subsequent `.localized` lookups
    /// return strings in the new language.
    var currentLanguage: SupportedLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Constants.languageStorageKey)
            UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        }
    }

    /// All languages offered in the Settings picker.
    let availableLanguages = SupportedLanguage.allCases

    // MARK: - Initialization

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Constants.languageStorageKey),
           let language = SupportedLanguage(rawValue: saved) {
            currentLanguage = language
        } else {
            currentLanguage = .english
        }
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
    }

    // MARK: - String Lookup

    /// Returns the translation for `key` in the currently active language.
    ///
    /// The `_ = currentLanguage` line establishes an `@Observable` dependency
    /// so that SwiftUI views calling this method are re-evaluated when the
    /// language changes.
    func localizedString(forKey key: String) -> String {
        _ = currentLanguage
        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}
```

**设计要点：**

- `SupportedLanguage.Identifiable`：使 `ForEach` 能直接遍历枚举 case，无需 `\.rawValue` 作为 id
- `displayName`：返回 `"English"` / `"简体中文"` / `"繁體中文"`，满足第 8 条要求
- `_ = currentLanguage`：强制建立 `@Observable` 追踪依赖链，这是 Swift 5.9+ Observation 框架的惯用写法
- `Bundle.main.localizedString(forKey:value:table:)`：
  - 第二个参数 `value` 传 `nil`：若 key 无翻译则返回 key 本身（即英文原文），实现英文 fallback
  - `table` 传 `nil`：使用默认的 `Localizable` 表（即 `Localizable.xcstrings`）
  - 底层调用 `CFBundleCopyLocalizedString`，每次实时读取 `AppleLanguages`

---

### 4.2 `rise/Localizable.xcstrings`

**在 Xcode 中**：File → New → File → Resource → String Catalog → 命名为 `Localizable`，保存到 `rise/` 目录，勾选 target `rise`。

**完整翻译表（20 个 key）：**

| Key | English (en) | 简体中文 (zh-Hans) | 繁體中文 (zh-Hant) |
|-----|-------------|-------------------|-------------------|
| `Gold  ---` | Gold  --- | 黄金  --- | 黃金  --- |
| `Gold  No API Key` | Gold  No API Key | 黄金  未设置 API Key | 黃金  未設定 API Key |
| `Gold  Invalid Key` | Gold  Invalid Key | 黄金  API Key 无效 | 黃金  API Key 無效 |
| `Gold  Rate Limited` | Gold  Rate Limited | 黄金  请求过于频繁 | 黃金  請求過於頻繁 |
| `Gold  $%@` | Gold  $%@ | 黄金  $%@ | 黃金  $%@ |
| `Gold  Fetch Failed` | Gold  Fetch Failed | 黄金  获取失败 | 黃金  獲取失敗 |
| `Refresh` | Refresh | 刷新 | 重新整理 |
| `Settings` | Settings | 设置 | 設定 |
| `About` | About | 关于 | 關於 |
| `Quit` | Quit | 退出 | 結束 |
| `Twelve Data API Key` | Twelve Data API Key | Twelve Data API Key | Twelve Data API Key |
| `Enter API Key` | Enter API Key | 请输入 API Key | 請輸入 API Key |
| `Save` | Save | 保存 | 儲存 |
| `Saved` | Saved | 已保存 | 已儲存 |
| `Register at twelvedata.com for a free API Key` | Register at twelvedata.com for a free API Key | 在 twelvedata.com 注册即可获取免费 API Key | 在 twelvedata.com 注册即可獲取免費 API Key |
| `Language` | Language | 语言 | 語言 |
| `Version %@` | Version %@ | 版本 %@ | 版本 %@ |
| `GitHub Repository` | GitHub Repository | GitHub 仓库 | GitHub 倉庫 |

**关于 `"Twelve Data API Key"` 不翻译为中文的原因：** "Twelve Data" 是第三方服务的品牌名，保持品牌一致性。

**关于 `"Gold  $%@"` 格式字符串：** `%@` 是 `String(format:)` 的占位符。调用时：

```swift
String(format: "Gold  $%@".localized, formatted)
```

英文下生成 `"Gold  $2651.23"`，中文下生成 `"黄金  $2651.23"`。价格数字不变。

**`.xcstrings` JSON 内容（供手动创建使用）：**

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Gold  ---" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Gold  ---" } },
        "zh-Hans" : { "stringUnit" : { "value" : "黄金  ---" } },
        "zh-Hant" : { "stringUnit" : { "value" : "黃金  ---" } }
      }
    },
    "Gold  No API Key" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Gold  No API Key" } },
        "zh-Hans" : { "stringUnit" : { "value" : "黄金  未设置 API Key" } },
        "zh-Hant" : { "stringUnit" : { "value" : "黃金  未設定 API Key" } }
      }
    },
    "Gold  Invalid Key" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Gold  Invalid Key" } },
        "zh-Hans" : { "stringUnit" : { "value" : "黄金  API Key 无效" } },
        "zh-Hant" : { "stringUnit" : { "value" : "黃金  API Key 無效" } }
      }
    },
    "Gold  Rate Limited" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Gold  Rate Limited" } },
        "zh-Hans" : { "stringUnit" : { "value" : "黄金  请求过于频繁" } },
        "zh-Hant" : { "stringUnit" : { "value" : "黃金  請求過於頻繁" } }
      }
    },
    "Gold  $%@" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Gold  $%@" } },
        "zh-Hans" : { "stringUnit" : { "value" : "黄金  $%@" } },
        "zh-Hant" : { "stringUnit" : { "value" : "黃金  $%@" } }
      }
    },
    "Gold  Fetch Failed" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Gold  Fetch Failed" } },
        "zh-Hans" : { "stringUnit" : { "value" : "黄金  获取失败" } },
        "zh-Hant" : { "stringUnit" : { "value" : "黃金  獲取失敗" } }
      }
    },
    "Refresh" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Refresh" } },
        "zh-Hans" : { "stringUnit" : { "value" : "刷新" } },
        "zh-Hant" : { "stringUnit" : { "value" : "重新整理" } }
      }
    },
    "Settings" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Settings" } },
        "zh-Hans" : { "stringUnit" : { "value" : "设置" } },
        "zh-Hant" : { "stringUnit" : { "value" : "設定" } }
      }
    },
    "About" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "About" } },
        "zh-Hans" : { "stringUnit" : { "value" : "关于" } },
        "zh-Hant" : { "stringUnit" : { "value" : "關於" } }
      }
    },
    "Quit" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Quit" } },
        "zh-Hans" : { "stringUnit" : { "value" : "退出" } },
        "zh-Hant" : { "stringUnit" : { "value" : "結束" } }
      }
    },
    "Twelve Data API Key" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Twelve Data API Key" } },
        "zh-Hans" : { "stringUnit" : { "value" : "Twelve Data API Key" } },
        "zh-Hant" : { "stringUnit" : { "value" : "Twelve Data API Key" } }
      }
    },
    "Enter API Key" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Enter API Key" } },
        "zh-Hans" : { "stringUnit" : { "value" : "请输入 API Key" } },
        "zh-Hant" : { "stringUnit" : { "value" : "請輸入 API Key" } }
      }
    },
    "Save" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Save" } },
        "zh-Hans" : { "stringUnit" : { "value" : "保存" } },
        "zh-Hant" : { "stringUnit" : { "value" : "儲存" } }
      }
    },
    "Saved" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Saved" } },
        "zh-Hans" : { "stringUnit" : { "value" : "已保存" } },
        "zh-Hant" : { "stringUnit" : { "value" : "已儲存" } }
      }
    },
    "Register at twelvedata.com for a free API Key" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Register at twelvedata.com for a free API Key" } },
        "zh-Hans" : { "stringUnit" : { "value" : "在 twelvedata.com 注册即可获取免费 API Key" } },
        "zh-Hant" : { "stringUnit" : { "value" : "在 twelvedata.com 注册即可獲取免費 API Key" } }
      }
    },
    "Language" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Language" } },
        "zh-Hans" : { "stringUnit" : { "value" : "语言" } },
        "zh-Hant" : { "stringUnit" : { "value" : "語言" } }
      }
    },
    "Version %@" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "Version %@" } },
        "zh-Hans" : { "stringUnit" : { "value" : "版本 %@" } },
        "zh-Hant" : { "stringUnit" : { "value" : "版本 %@" } }
      }
    },
    "GitHub Repository" : {
      "localizations" : {
        "en" : { "stringUnit" : { "value" : "GitHub Repository" } },
        "zh-Hans" : { "stringUnit" : { "value" : "GitHub 仓库" } },
        "zh-Hant" : { "stringUnit" : { "value" : "GitHub 倉庫" } }
      }
    }
  },
  "version" : "1.0"
}
```

> **推荐在 Xcode 中使用 String Catalog 编辑器（GUI 界面）创建和管理 `.xcstrings` 文件。** Xcode 编辑器提供自动补全、状态标记（绿勾 = 已翻译 / 红叉 = 未翻译）、搜索筛选等功能。手动编辑 JSON 可行但存在格式错误风险。

---

## 五、修改文件

### 5.1 `rise/Constants.swift`

**改动前：**

```swift
import Foundation

enum Constants {
    static let apiKeyStorageKey = "apiKey"
    static let goldSymbol = "XAU/USD"
    static let apiBaseURL = "https://api.twelvedata.com/price"
    static let refreshInterval: TimeInterval = 300
    static let settingsWindowWidth: CGFloat = 440
    static let settingsWindowHeight: CGFloat = 220
    static let aboutWindowWidth: CGFloat = 280
    static let aboutWindowHeight: CGFloat = 220
    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
}
```

**改动后：**

```swift
import Foundation

enum Constants {
    static let apiKeyStorageKey = "apiKey"
    static let languageStorageKey = "appLanguage"
    static let goldSymbol = "XAU/USD"
    static let apiBaseURL = "https://api.twelvedata.com/price"
    static let refreshInterval: TimeInterval = 300
    static let settingsWindowWidth: CGFloat = 440
    static let settingsWindowHeight: CGFloat = 300
    static let aboutWindowWidth: CGFloat = 280
    static let aboutWindowHeight: CGFloat = 220
    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
}
```

**变更：**
- 新增 `languageStorageKey = "appLanguage"`
- `settingsWindowHeight: 220 → 300`（新增语言选择区域需要额外 80pt）

---

### 5.2 `rise/riseApp.swift`

**改动后的完整代码：**

```swift
import SwiftUI

/// Entry point of the application.
///
/// Displays the current gold price in the macOS menu bar via `MenuBarExtra`
/// and provides a settings window for configuring the Twelve Data API key
/// along with an about window.
@main
struct RiseApp: App {
    private let priceService = PriceService.shared
    private let loc = LocalizationManager.shared

    var body: some Scene {
        // MARK: - Menu Bar

        MenuBarExtra {
            MenuContentView()
        } label: {
            Text(priceLabel)
        }

        // MARK: - Settings

        Settings {
            SettingsView()
        }
        .defaultSize(width: Constants.settingsWindowWidth, height: Constants.settingsWindowHeight)

        // MARK: - About

        Window("About", id: "about") {
            AboutView()
        }
        .defaultSize(width: Constants.aboutWindowWidth, height: Constants.aboutWindowHeight)
    }

    // MARK: - Price Label

    /// Human-readable menu bar label derived from the current price status.
    private var priceLabel: String {
        switch priceService.status {
        case .initial:
            return loc.localizedString(forKey: "Gold  ---")
        case .noKey:
            return loc.localizedString(forKey: "Gold  No API Key")
        case .unauthorized:
            return loc.localizedString(forKey: "Gold  Invalid Key")
        case .rateLimited:
            return loc.localizedString(forKey: "Gold  Rate Limited")
        case .value(let v):
            let formatted = v.formatted(
                .number.precision(.fractionLength(2)).grouping(.never)
            )
            let template = loc.localizedString(forKey: "Gold  $%@")
            return String(format: template, formatted)
        case .error:
            return loc.localizedString(forKey: "Gold  Fetch Failed")
        }
    }
}
```

**逐行对照变动：**

| 原代码 | 新代码 | 说明 |
|--------|--------|------|
| `private let priceService = ...` | 保持不变 | — |
| — | `private let loc = LocalizationManager.shared` | 新增，触发 `@Observable` 追踪 |
| `case .initial: return "Gold  ---"` | `return loc.localizedString(forKey: "Gold  ---")` | 本地化 |
| `case .noKey: return "Gold  No API Key"` | `return loc.localizedString(forKey: "Gold  No API Key")` | 本地化 |
| `case .unauthorized: return "Gold  Invalid Key"` | `return loc.localizedString(forKey: "Gold  Invalid Key")` | 本地化 |
| `case .rateLimited: return "Gold  Rate Limited"` | `return loc.localizedString(forKey: "Gold  Rate Limited")` | 本地化 |
| `return "Gold  $\(formatted)"` | `let template = loc.localizedString(forKey: "Gold  $%@")` + `return String(format: template, formatted)` | 格式字符串先翻译再插值 |
| `case .error: return "Gold  Fetch Failed"` | `return loc.localizedString(forKey: "Gold  Fetch Failed")` | 本地化 |
| `Window("About", id: "about")` | 保持不变 | `"About"` 已在 `.xcstrings` 中翻译，`LocalizableStringKey` 自动解析 |

---

### 5.3 `rise/MenuContentView.swift`

**改动后的完整代码：**

```swift
import SwiftUI

// MARK: - Menu Content

/// Dropdown menu shown when the user clicks the menu bar item.
struct MenuContentView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    private let priceService = PriceService.shared
    private let loc = LocalizationManager.shared

    var body: some View {
        // Refresh — fetches the latest price immediately
        Button {
            Task { await priceService.fetchPrice() }
        } label: {
            Text(verbatim: loc.localizedString(forKey: "Refresh"))
        }
        .disabled(priceService.isLoading)

        // Open settings window (brings app to foreground first)
        Button {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        } label: {
            Text(verbatim: loc.localizedString(forKey: "Settings"))
        }

        // About this application
        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "about")
            DispatchQueue.main.async {
                NSApp.windows.first { $0.identifier?.rawValue == "about" }
                    ?.makeKeyAndOrderFront(nil)
            }
        } label: {
            Text(verbatim: loc.localizedString(forKey: "About"))
        }

        Divider()

        // Terminate the application completely
        Button {
            NSApp.terminate(nil)
        } label: {
            Text(verbatim: loc.localizedString(forKey: "Quit"))
        }
    }
}
```

**逐行对照变动：**

| 原代码 | 新代码 | 说明 |
|--------|--------|------|
| — | `private let loc = LocalizationManager.shared` | 新增 |
| `Button("Refresh") { ... }` | `Button { ... } label: { Text(verbatim: loc.localizedString(forKey: "Refresh")) }` | 本地化，使用 `Text(verbatim:)` |
| `Button("Settings") { ... }` | `Button { ... } label: { Text(verbatim: loc.localizedString(forKey: "Settings")) }` | 本地化 |
| `Button("About") { ... }` | `Button { ... } label: { Text(verbatim: loc.localizedString(forKey: "About")) }` | 本地化 |
| `$0.title == "About"` | `$0.identifier?.rawValue == "about"` | 窗口匹配改用 identifier，语言无关 |
| `Button("Quit") { ... }` | `Button { ... } label: { Text(verbatim: loc.localizedString(forKey: "Quit")) }` | 本地化 |

**为什么使用 `Button(action:label:)` + `Text(verbatim:)` 而非 `Button(title:)`：**

`Button("Refresh")` 使用 `LocalizableStringKey` 作为 label。`LocalizableStringKey` 的解析依赖视图层级中的 `.environment(\.locale, ...)`。而 `MenuBarExtra` 菜单的环境传播路径与主窗口不同，存在不可靠性。使用 `Text(verbatim:)` + `.localized` 确保 100% 走自定义本地化链。

**为什么 About 窗口匹配改用 identifier：**

原代码：
```swift
NSApp.windows.first { $0.title == "About" }?.makeKeyAndOrderFront(nil)
```
问题：语言切换后，`$0.title` 是 `"关于"` 或 `"關於"`，不再匹配 `"About"`。

改为：
```swift
NSApp.windows.first { $0.identifier?.rawValue == "about" }?.makeKeyAndOrderFront(nil)
```

`Window("About", id: "about")` 会将 `id: "about"` 设置为 `NSWindow.identifier`（`NSUserInterfaceItemIdentifier`），完全独立于当前语言。

---

### 5.4 `rise/SettingsView.swift`

**改动后的完整代码：**

```swift
import SwiftUI
import OSLog

// MARK: - Settings View

/// Settings window that allows the user to enter and save their Twelve Data API
/// key and select the application language.
///
/// The key and language are persisted via `UserDefaults`. The API key is used
/// by `PriceService` for all price requests. After saving, an immediate fetch
/// is triggered so the menu bar reflects the latest data without waiting for
/// the timer. Language changes take effect immediately after saving.
struct SettingsView: View {

    // MARK: - State

    /// Local copy of the key for editing in the text field, initialized from
    /// persistent storage.
    @State private var apiKey = UserDefaults.standard.string(forKey: Constants.apiKeyStorageKey) ?? ""

    /// Tracks whether the key has been saved during this session.
    @State private var isSaved = false

    /// Language selected in the picker. Initialized from the current language
    /// and applied only when the user taps Save.
    @State private var selectedLanguage = LocalizationManager.shared.currentLanguage

    /// Cached reference to the Settings window for title updates after language
    /// changes.
    @State private var settingsWindow: NSWindow?

    private let loc = LocalizationManager.shared

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section: API key input
            Text(loc.localizedString(forKey: "Twelve Data API Key"))
                .font(.headline)

            TextField(loc.localizedString(forKey: "Enter API Key"), text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .onChange(of: apiKey) { _, _ in
                    isSaved = false
                }

            HStack(spacing: 10) {
                Button(loc.localizedString(forKey: "Save")) {
                    PriceService.shared.updateAPIKey(apiKey)
                    loc.currentLanguage = selectedLanguage
                    isSaved = true
                    updateSettingsWindowTitle()
                    Logger.price.info("API key saved — triggering fetch")
                }
                .buttonStyle(.borderedProminent)

                if isSaved {
                    Text(loc.localizedString(forKey: "Saved"))
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }

            // Section: Language selector
            Text(loc.localizedString(forKey: "Language"))
                .font(.headline)

            Picker(selection: $selectedLanguage) {
                ForEach(loc.availableLanguages) { language in
                    Text(language.displayName).tag(language)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Section: registration hint
            Text(loc.localizedString(forKey: "Register at twelvedata.com for a free API Key"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .onAppear {
            DispatchQueue.main.async {
                settingsWindow = NSApp.windows.first {
                    $0.title.contains("Settings")
                }
                updateSettingsWindowTitle()
            }
        }
        .onChange(of: loc.currentLanguage) { _, _ in
            updateSettingsWindowTitle()
        }
    }

    // MARK: - Helpers

    /// Updates the Settings window title to match the currently active language.
    private func updateSettingsWindowTitle() {
        settingsWindow?.title = loc.localizedString(forKey: "Settings")
    }
}
```

**逐行对照变动：**

| 原代码位置 / 内容 | 新代码 | 说明 |
|---|---|---|
| `Text("Twelve Data API Key")` | `Text(loc.localizedString(forKey: "Twelve Data API Key"))` | 本地化标题 |
| `TextField("Enter API Key", ...)` | `TextField(loc.localizedString(forKey: "Enter API Key"), ...)` | 本地化 placeholder |
| `Button("Save") {` | `Button(loc.localizedString(forKey: "Save")) {` | 本地化按钮 |
| `PriceService.shared.updateAPIKey(apiKey)`（Save 按钮内） | 新增下一行：`loc.currentLanguage = selectedLanguage` | 应用语言切换 |
| 新增 | `updateSettingsWindowTitle()` | 同步设置窗口标题 |
| `Text("Saved")` | `Text(loc.localizedString(forKey: "Saved"))` | 本地化反馈 |
| `Text("Register at ...")` | `Text(loc.localizedString(forKey: "Register at twelvedata.com for a free API Key"))` | 本地化提示 |
| 无 | 新增 `@State private var selectedLanguage` | 缓冲语言选择，Save 时写入 |
| 无 | 新增 `@State private var settingsWindow: NSWindow?` | 缓存窗口引用，避免标题匹配 |
| 无 | 新增 `private let loc = LocalizationManager.shared` | 本地化管理器引用 |
| 无 | 新增语言选择 Section（`Divider` + `Text("Language")` + `Picker`） | 语言 Picker |
| `$0.title.contains("Settings")` + `?.title = "Settings"` | 拆分为 `onAppear` 缓存窗口 + `updateSettingsWindowTitle()` | 使用缓存的 `NSWindow` 引用更新标题 |
| 无 | `.onChange(of: loc.currentLanguage) { _, _ in updateSettingsWindowTitle() }` | 语言切换后更新标题 |

**Picker 详解：**
- `selection: $selectedLanguage`：绑定到本地 `@State`，用户选择不立即生效
- `ForEach(loc.availableLanguages)`：遍历 `SupportedLanguage.allCases`（3 个 case）
- `language.displayName`：显示 `"English"` / `"简体中文"` / `"繁體中文"`
- `.pickerStyle(.menu)`：macOS 风格下拉菜单，与 Settings 窗口风格一致
- `.frame(maxWidth: .infinity, alignment: .leading)`：左对齐占满宽度

---

### 5.5 `rise/AboutView.swift`

**改动后的完整代码：**

```swift
import SwiftUI

// MARK: - About View

/// About window that displays the app name, version, and a link to the
/// project's GitHub repository.
struct AboutView: View {

    // MARK: - Constants

    private let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Rise"
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    private let repoURL = URL(string: "https://github.com/hanchaoyang/rise")!
    private let loc = LocalizationManager.shared

    /// Cached reference to the About window for title updates after language
    /// changes.
    @State private var aboutWindow: NSWindow?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 14) {
            // App icon
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .padding(.bottom, 4)

            // App name
            Text(appName)
                .font(.title.weight(.semibold))

            // Version
            Text(String(format: loc.localizedString(forKey: "Version %@"), version))
                .font(.footnote)
                .foregroundStyle(.secondary)

            // GitHub link
            Button {
                NSWorkspace.shared.open(repoURL)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                    Text(verbatim: loc.localizedString(forKey: "GitHub Repository"))
                }
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pointingHand.pop()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.async {
                aboutWindow = NSApp.windows.first {
                    $0.identifier?.rawValue == "about"
                }
                updateAboutWindowTitle()
            }
        }
        .onChange(of: loc.currentLanguage) { _, _ in
            updateAboutWindowTitle()
        }
    }

    // MARK: - Helpers

    /// Updates the About window title to match the currently active language.
    private func updateAboutWindowTitle() {
        aboutWindow?.title = loc.localizedString(forKey: "About")
    }
}
```

**逐行对照变动：**

| 原代码 | 新代码 | 说明 |
|--------|--------|------|
| — | `private let loc = LocalizationManager.shared` | 新增 |
| — | `@State private var aboutWindow: NSWindow?` | 缓存窗口引用 |
| `Text("Version \(version)")` | `Text(String(format: loc.localizedString(forKey: "Version %@"), version))` | 本地化版本文字 |
| `Text("GitHub Repository")` | `Text(verbatim: loc.localizedString(forKey: "GitHub Repository"))` | 本地化链接文字 |
| — | `.onAppear { ... aboutWindow = NSApp.windows.first { $0.identifier?.rawValue == "about" }; updateAboutWindowTitle() }` | 首次缓存窗口并设置标题 |
| — | `.onChange(of: loc.currentLanguage) { _, _ in updateAboutWindowTitle() }` | 语言切换后更新标题 |
| — | `private func updateAboutWindowTitle() { aboutWindow?.title = loc.localizedString(forKey: "About") }` | 辅助方法 |

**未翻译项：**

| 内容 | 原因 |
|------|------|
| `appName`（Bundle 读取的品牌名 `"Rise"`） | 品牌名不翻译 |
| `"chart.line.uptrend.xyaxis"` | SF Symbol 系统标识 |
| `"link"` | SF Symbol 系统标识 |
| `"CFBundleName"`, `"CFBundleShortVersionString"` | Info.plist 字典 key |

---

## 六、不修改的文件

### 6.1 `rise/PriceService.swift`

**不修改。** 文件中所有字符串均为 Logger 输出或 API 调用内部参数。符合需求第 3 条："日志等内容不需要修改"。

文件内字符串审计（全部为 Logger / API 内部）：`"Service initialized"`, `"Starting polling..."`, `"Timer fired..."`, `"No API key configured..."`, `"API response body:..."`, `"Invalid response type"`, `"HTTP status:..."`, `"HTTP 401..."`, `"HTTP 429..."`, `"HTTP error:..."`, `"Price fetched successfully:..."`, `"API error..."`, `"Unable to parse price..."`, `"Price fetch failed:..."`, `"symbol"`, `"apikey \(key)"`

### 6.2 `rise/Logger+Extensions.swift`

**不修改。** subsystem identifier `"io.github.hanchaoyang.rise"` 和 category `"PriceService"` 是日志系统内部标识。

---

## 七、全项目字符串审计总表

| # | 文件:行号 | 原字符串 | 翻译 key | 分类 |
|---|-----------|---------|----------|------|
| 1 | riseApp:30 | `"About"` | `About` | 窗口标题 |
| 2 | riseApp:41 | `"Gold  ---"` | `Gold  ---` | 菜单栏状态 |
| 3 | riseApp:42 | `"Gold  No API Key"` | `Gold  No API Key` | 菜单栏状态 |
| 4 | riseApp:43 | `"Gold  Invalid Key"` | `Gold  Invalid Key` | 菜单栏状态 |
| 5 | riseApp:44 | `"Gold  Rate Limited"` | `Gold  Rate Limited` | 菜单栏状态 |
| 6 | riseApp:49 | `"Gold  $\(formatted)"` | `Gold  $%@` | 菜单栏格式化 |
| 7 | riseApp:50 | `"Gold  Fetch Failed"` | `Gold  Fetch Failed` | 菜单栏状态 |
| 8 | SettingsView:27 | `"Twelve Data API Key"` | `Twelve Data API Key` | 标题 |
| 9 | SettingsView:30 | `"Enter API Key"` | `Enter API Key` | placeholder |
| 10 | SettingsView:39 | `"Save"` | `Save` | 按钮 |
| 11 | SettingsView:48 | `"Saved"` | `Saved` | 反馈 |
| 12 | SettingsView:55 | `"Register at twelvedata.com for a free API Key"` | `Register at twelvedata.com for a free API Key` | 提示 |
| 13 | SettingsView:62 | `$0.title.contains("Settings")` | —（改为窗口引用） | 窗口匹配 |
| 14 | SettingsView:62 | `?.title = "Settings"` | `Settings` | 窗口标题 |
| 15 | MenuContentView:13 | `"Refresh"` | `Refresh` | 菜单按钮 |
| 16 | MenuContentView:19 | `"Settings"` | `Settings` | 菜单按钮 |
| 17 | MenuContentView:25 | `"About"` | `About` | 菜单按钮 |
| 18 | MenuContentView:29 | `$0.title == "About"` | —（改为 identifier） | 窗口匹配 |
| 19 | MenuContentView:36 | `"Quit"` | `Quit` | 菜单按钮 |
| 20 | AboutView:30 | `"Version \(version)"` | `Version %@` | 版本文字 |
| 21 | AboutView:40 | `"GitHub Repository"` | `GitHub Repository` | 链接文字 |
| — | 新增 Picker | — | `Language` | 标签 |

### 排除项审计

| 字符串 | 位置 | 排除原因 |
|--------|------|----------|
| `"Rise"` | AboutView:11 fallback | 品牌名（Bundle 读取失败时 fallback） |
| `"0.1"` | AboutView:12 fallback | 版本号（Bundle 读取失败时 fallback） |
| `"chart.line.uptrend.xyaxis"` | AboutView:20 | SF Symbol 系统标识 |
| `"link"` | AboutView:39 | SF Symbol 系统标识 |
| `"CFBundleName"` | AboutView:11 | Info.plist 字典 key |
| `"CFBundleShortVersionString"` | AboutView:12 | Info.plist 字典 key |
| `"API key saved — triggering fetch"` | SettingsView:42 | Logger 输出 |
| `"Service initialized"` 等 14 条 | PriceService.swift | Logger 输出 |
| `"symbol"` | PriceService:85 | API query parameter |
| `"apikey \(key)"` | PriceService:89 | HTTP header value |
| `"io.github.hanchaoyang.rise"` | Logger+Extensions:7 | Logger subsystem identifier |

---

## 八、文件变更汇总

| 操作 | 文件 | 行数变化 | 说明 |
|------|------|:--:|------|
| 新增 | `rise/LocalizationManager.swift` | +70 | @Observable 单例 |
| 新增 | `rise/Localizable.xcstrings` | — | Xcode String Catalog |
| 修改 | `rise/Constants.swift` | +1 常量，改 1 数值 | `languageStorageKey` + 窗口高度 |
| 修改 | `rise/riseApp.swift` | +1 属性，7 处字符串替换 | 菜单栏状态本地化 |
| 修改 | `rise/SettingsView.swift` | +~25 | 语言选择区 + 窗口管理 + 全文字本地化 |
| 修改 | `rise/MenuContentView.swift` | +1 属性，5 处 Button 重写 | 菜单文字本地化 + identifier 匹配 |
| 修改 | `rise/AboutView.swift` | +~15 | 窗口管理 + 2 处文字本地化 |
| 不变 | `rise/PriceService.swift` | 0 | — |
| 不变 | `rise/Logger+Extensions.swift` | 0 | — |

---

## 九、Xcode 项目配置

**无需修改的项目设置（已满足）：**
- `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` ✅
- `SWIFT_EMIT_LOC_STRINGS = YES` ✅
- `STRING_CATALOG_GENERATE_SYMBOLS = YES` ✅
- `developmentRegion = en` ✅

**建议更新 `knownRegions`（`project.pbxproj`，可选）：**

```
knownRegions = (
    en,
    "zh-Hans",
    "zh-Hant",
    Base,
);
```

> 此配置使 Xcode 知道项目支持这 3 种语言，但不影响运行时行为。可在 Xcode → Project → Info → Localizations 中添加。

---

## 十、测试验证

### 10.1 基本功能

| 测试场景 | 预期结果 |
|----------|----------|
| App 首次启动 | 默认英语，菜单栏显示 `Gold  ---` |
| 打开 Settings | 标题 "Settings"，API Key 标题 "Twelve Data API Key"，按钮 "Save" |
| 打开菜单 | "Refresh", "Settings", "About", "Quit" |
| 打开 About | 标题 "About"，"Version 0.1"，"GitHub Repository" |
| 选择简体中文 → Save | 所有 UI 文字立即变为简体中文，无需重启 App |
| 选择繁體中文 → Save | 所有 UI 文字立即变为繁體中文，无需重启 App |
| 选择 English → Save | 所有 UI 文字恢复英文 |
| 填写 API Key → Save | 价格正常显示，菜单栏格式中 "Gold" 跟随当前语言 |
| 语言切换后打开 About | 窗口标题跟随当前语言 |
| 语言切换后 Settings 窗口标题 | 标题即时更新为对应语言 |
| 重启 App | 语言选择保持上一次设置 |

### 10.2 回归验证

| 测试场景 | 预期结果 |
|----------|----------|
| 无 API Key 时菜单栏状态 | 显示对应语言的 `"Gold  No API Key"` |
| 填无效 API Key 后状态 | 显示对应语言的 `"Gold  Invalid Key"` |
| 请求过于频繁 | 显示对应语言的 `"Gold  Rate Limited"` |
| 网络异常 | 显示对应语言的 `"Gold  Fetch Failed"` |
| 正常价格 | `"Gold  $2651.23"` 或 `"黄金  $2651.23"` |
| Logger 输出 | 终端/Console.app 中日志仍为英文，不受影响 |
| 价格定时刷新（300 秒） | 正常工作，无异常 |
| Refresh 按钮 | 正常工作 |
| 重复点击 Save | `isSaved` 反馈正常，不重复触发副作用 |

---

## 十一、扩展指南

### 11.1 新增一种语言（例如日语）

1. 在 `LocalizationManager.SupportedLanguage` 新增 case：
   ```swift
   case japanese = "ja"
   ```
2. 在 `displayName` switch 新增：
   ```swift
   case .japanese: return "日本語"
   ```
3. 在 Xcode 中打开 `Localizable.xcstrings`，为所有 20 个 key 添加 `ja` 列的翻译
4. 将 `"ja"` 加入 Xcode 项目 `knownRegions`

无需修改任何视图代码。Picker 自动生成新选项。

### 11.2 新增一条需翻译的字符串

1. 在 `.xcstrings` 中添加新 key（key 使用英文原文）
2. 补齐 en / zh-Hans / zh-Hant 三列翻译
3. 在代码中使用 `loc.localizedString(forKey: "新 Key 的文字")`

无需修改 `LocalizationManager` 或任何其他代码。

---

## 十二、注意事项

1. **`Bundle.localizedString` 的 fallback 行为**：第三个参数 `value` 传 `nil` 时，若 key 在 `.xcstrings` 中找不到翻译，则返回 key 本身（即英文原文）。此行为天然支持英语作为 fallback 语言。

2. **`AppleLanguages` 的格式**：`UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")` 的值必须是 `[String]` 数组类型。`CFBundleCopyLocalizedString` 期望读取字符串数组。

3. **`MenuBarExtra` 环境传播限制**：`MenuBarExtra` 内部视图的环境可能与主应用不同步。方案中统一使用显式 `Text(verbatim:)` + `loc.localizedString(...)`，不依赖 `LocalizableStringKey` 的自动解析，确保 100% 可靠性。

4. **窗口标题的语言切换**：`Window` 初始化时通过 `LocalizableStringKey` 设置标题，之后 SwiftUI 不自动更新。因此需要通过 `onChange` 监听 `currentLanguage` 变化，手动更新 `NSWindow.title`。缓存 `NSWindow` 引用而非每次用字符串匹配搜索窗口。

5. **与 `SWIFT_EMIT_LOC_STRINGS` 的兼容性**：项目虽已开启 `SWIFT_EMIT_LOC_STRINGS`，但因我们使用的是自定义 `loc.localizedString(forKey:)` 而非系统 `String(localized:)`，Xcode 不会自动提取翻译条目到 `.xcstrings`。所有翻译条目需手动添加——这是有意的设计，确保 key 命名完全可控。

6. **`@Observable` 追踪必须显式读取 `currentLanguage`**：`localizedString(forKey:)` 内部的 `_ = currentLanguage` 是 Swift Observation 框架建立依赖链的关键语句。若省略，语言变更后视图不会自动重渲染。

7. **`DidSet` 在 `init` 中不触发**：`LocalizationManager.init()` 中给 `currentLanguage` 赋初值不会触发 `didSet`。因此需要在 `init` 末尾显式调用 `UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")` 以确保首次启动时 `AppleLanguages` 被正确设置。
