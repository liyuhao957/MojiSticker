# MojiSticker

macOS 菜单栏表情包搜索工具，一键搜索抖音表情包并复制到剪贴板，直接粘贴到飞书、微信等聊天工具中使用。

## 功能特点

- **菜单栏常驻** — 无 Dock 图标，不占用任务栏空间
- **全局快捷键** — `Cmd+Shift+K` 随时唤起搜索窗口
- **实时搜索** — 输入关键词即可搜索抖音表情包库
- **动图支持** — 完整保留 GIF/WebP 动画效果
- **一键复制** — 点击表情自动复制到剪贴板（缩放至 160px，适配飞书/微信）
- **悬浮预览** — 鼠标悬停显示 320px 大图预览
- **无限滚动** — 滚动到底部自动加载更多结果
- **IPC 接口** — 支持 `mojictl` 命令行工具调用

## 系统要求

- macOS 14.0+
- 需要抖音网页版 Cookie（首次使用时在设置中配置）

## 构建与运行

项目使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 管理工程配置：

```bash
# 安装 XcodeGen（如未安装）
brew install xcodegen

# 生成 Xcode 工程
xcodegen generate

# 一键构建并运行
./run.sh
```

也可以用 Xcode 打开 `MojiSticker.xcodeproj` 直接构建运行。

## 使用方法

1. 启动应用，菜单栏出现 😊 图标
2. 点击图标或按 `Cmd+Shift+K` 打开搜索窗口
3. 首次使用需配置抖音 Cookie：点击设置图标，粘贴从浏览器复制的 Cookie
4. 输入关键词搜索表情包
5. 点击表情即可复制，粘贴到聊天窗口使用

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd+Shift+K` | 打开/聚焦搜索窗口 |
| `Cmd+Shift+E` | 退出应用 |
| `Esc` | 关闭窗口 / 收起设置面板 |

## 技术栈

- **语言**: Swift 5.9
- **UI**: SwiftUI + AppKit（NSPanel 浮动窗口）
- **构建**: XcodeGen
- **缓存**: 内存 + 磁盘双级缓存（`~/.moji/cache`）
- **IPC**: Unix Domain Socket（`~/.moji/moji.sock`）

## 许可证

MIT
