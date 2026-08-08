<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-light.png">
  <img alt="Rise" src="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-light.png">
</picture>

[English](./README.md)

# Rise

> 一款轻量级的 macOS 菜单栏应用，实时显示黄金价格。

Rise 安静地驻留在菜单栏中，让你一目了然地查看最新的 XAU/USD（国际金价）报价。没有窗口，没有干扰——只有你需要的数字，每 5 分钟自动更新一次。

---

## 功能

- **实时金价** — 菜单栏中显示 XAU/USD 实时报价
- **自动刷新** — 每 5 分钟自动更新一次
- **手动刷新** — 随时点击"Refresh"立即获取最新价格
- **状态提示** — 直观显示无密钥、密钥无效、请求过多、网络错误等状态
- **API 密钥管理** — 在设置中添加、更新或移除你的 Twelve Data API 密钥
- **极致轻量** — 仅存在于菜单栏，无 Dock 图标

## 系统要求

- macOS 26 及以上版本
- 一个免费的 [Twelve Data](https://twelvedata.com) API 密钥

## 安装

### 下载安装（推荐）

前往 [Releases](https://github.com/hanchaoyang/rise/releases) 页面下载最新版本。打开 `.dmg` 文件，将 `Rise.app` 拖入应用程序文件夹，然后启动即可。

> **注意：** Rise 仅运行在菜单栏中——你不会看到 Dock 图标。请在菜单栏中查找金价文本。

### 从源码构建

```bash
git clone https://github.com/hanchaoyang/rise.git
cd rise
xcodebuild -project rise.xcodeproj -scheme rise -configuration Release build
```

构建产物路径：`~/Library/Developer/Xcode/DerivedData/rise-*/Build/Products/Release/rise.app`。

## 配置

Rise 需要一个免费的 Twelve Data API 密钥来获取金价数据。

1. 前往 [twelvedata.com](https://twelvedata.com) 注册一个免费账户
2. 在[控制台](https://twelvedata.com/apikey)复制你的 API 密钥
3. 点击菜单栏中的金价 → **Settings**
4. 粘贴你的 API 密钥，点击 **Save**

菜单栏将在几秒钟内完成更新。如果密钥无效，你将看到 `Gold Invalid Key`。

### 移除 API 密钥

打开 **Settings**，清空输入框，点击 **Save**。应用将恢复至"未配置 API Key"的初始状态。

## 使用说明

| 操作 | 方法 |
|------|------|
| 查看价格 | 看一眼菜单栏 |
| 立即刷新 | 点击价格 → **Refresh** |
| 更换密钥 | 点击价格 → **Settings** |
| 关于应用 | 点击价格 → **About** |
| 退出应用 | 点击价格 → **Quit** |

Twelve Data 免费套餐允许每日 **800 次** API 调用。以每 5 分钟一次计算，Rise 每日约调用 288 次，远在免费额度之内。

## 技术栈

| 层面 | 技术 |
|------|------|
| UI | SwiftUI |
| 状态 | `@Observable`（Observation 框架） |
| 网络 | `URLSession` |
| 持久化 | `UserDefaults` |
| 日志 | `OSLog` |
| 最低系统 | macOS 26 |

## 项目结构

```
rise/
├── RiseApp.swift              # @main 入口 — 菜单栏 + 场景
├── MenuContentView.swift      # 下拉菜单（Refresh, Settings, About, Quit）
├── SettingsView.swift         # API 密钥配置
├── AboutView.swift            # 应用信息 + GitHub 链接
├── PriceService.swift         # 单例 — 获取、缓存、轮询
├── Constants.swift            # API 地址、间隔、窗口尺寸
├── Logger+Extensions.swift    # OSLog 分类扩展
└── Assets.xcassets/           # 应用图标与强调色
```

## 故障排除

| 菜单栏显示 | 含义 | 解决方法 |
|-----------|------|---------|
| `Gold ---` | 刚启动，正在获取 | 稍等片刻 |
| `Gold No API Key` | 未配置 API 密钥 | 在设置中填入你的 API 密钥 |
| `Gold Invalid Key` | 密钥被服务器拒绝 | 在 [twelvedata.com/apikey](https://twelvedata.com/apikey) 检查密钥或生成新密钥 |
| `Gold Rate Limited` | 请求次数过多 | 等待即可——免费额度每日重置 |
| `Gold Fetch Failed` | 网络或服务器错误 | 检查网络连接，或稍后重试 |

## 许可

MIT © [Han Chaoyang](https://github.com/hanchaoyang)
