<div align="center">
  <h1>Rise</h1>
  <p>在 macOS 菜单栏中实时显示黄金价格。</p>

  <sub>基于 SwiftUI 构建 &middot; macOS 26+ &middot; 由 <a href="https://twelvedata.com">Twelve Data</a> 提供数据</sub>
</div>

<br>

[English](./README.md)

Rise 将当前 XAU/USD 金价直接显示在菜单栏中，每 5 分钟自动刷新。没有窗口，没有 Dock 图标——只有你需要的数字。

## 快速开始

1. 从 [Releases](https://github.com/hanchaoyang/rise/releases) 下载最新 `.dmg` 并拖入 **应用程序** 文件夹
2. 在 [twelvedata.com](https://twelvedata.com) 注册获取 **免费 API 密钥**
3. 点击菜单栏中的价格 → **Settings** → 粘贴密钥 → **Save**

几秒钟内价格就会出现。

| 操作 | 方式 |
|---|---|
| 刷新价格 | 点击价格 → **Refresh** |
| 移除密钥 | 在 Settings 中清空输入框 → **Save** |

> 免费套餐提供每日 800 次调用。Rise 约使用 288 次——完全不用担心超额。

## 从源码构建

```bash
git clone https://github.com/hanchaoyang/rise.git
cd rise
xcodebuild -project rise.xcodeproj -scheme rise -configuration Release build
```

## 状态说明

<sub>菜单栏始终显示当前状态。</sub>

| 显示 | 状态 |
|---|---|
| `Gold $2,650.12` | 正常——已获取最新价格 |
| `Gold ---` | 刚启动，正在获取数据 |
| `Gold No API Key` | 前往 Settings 添加密钥 |
| `Gold Invalid Key` | 密钥被拒——前往 twelvedata.com 获取新密钥 |
| `Gold Rate Limited` | 当日免费额度用尽——次日自动重置 |
| `Gold Fetch Failed` | 网络异常——请重试或稍候 |

## 许可

MIT
