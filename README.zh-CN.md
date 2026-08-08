<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-light.png">
  <img alt="Rise" src="https://raw.githubusercontent.com/hanchaoyang/rise/main/.github/assets/hero-light.png">
</picture>

[English](./README.md)

Rise — 在 macOS 菜单栏中实时显示黄金价格。XAU/USD，每 5 分钟自动刷新。没有窗口，没有 Dock 图标，没有干扰。

> **macOS 26+** &nbsp;|&nbsp; **SwiftUI** &nbsp;|&nbsp; 基于 [Twelve Data](https://twelvedata.com)

## 快速开始

1. 从 [Releases](https://github.com/hanchaoyang/rise/releases) 下载最新的 `.dmg` 并拖入应用程序文件夹
2. 在 [twelvedata.com](https://twelvedata.com) 获取免费 API 密钥
3. 点击菜单栏中的价格 → **Settings** → 粘贴密钥 → **Save**

完成。几秒钟内价格就会出现。

| | |
|---|---|
| 刷新 | 点击价格 → **Refresh** |
| 移除密钥 | 在 Settings 中清空输入框 → **Save** |

> 免费额度：每日 800 次调用。Rise 约使用 288 次——绰绰有余。

## 从源码构建

```bash
git clone https://github.com/hanchaoyang/rise.git
cd rise
xcodebuild -project rise.xcodeproj -scheme rise -configuration Release build
```

## 状态说明

| 菜单栏显示 | 含义 |
|----------|------|
| `Gold $2,650.12` | 成功获取价格 |
| `Gold ---` | 刚启动，正在获取 |
| `Gold No API Key` | 请在设置中填写 API 密钥 |
| `Gold Invalid Key` | 密钥被拒——前往 twelvedata.com 获取新密钥 |
| `Gold Rate Limited` | 当日额度用尽——次日自动重置 |
| `Gold Fetch Failed` | 网络问题——请重试或稍候 |

## 许可

MIT
