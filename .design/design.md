# 设计文档：修复 Hover 预览大图闪烁消失问题

## 目标

- 鼠标 hover 到某个小图（72x72 cell）上后，只要鼠标还在该 cell 范围内移动，预览大图始终保持显示
- 鼠标移出 cell 范围后，预览正常消失

## 非目标

- 不改变预览面板的视觉样式或位置逻辑
- 不改变点击复制的行为

## 根因分析

当前实现存在三个问题：

1. **NSPanel 可能干扰 hit-testing**：浮动面板出现在 cell 附近时，可能拦截鼠标事件，导致 SwiftUI `.onHover` 收到错误的 `false`
2. **立即隐藏无容错**：`StickerGridView` 中 `onHover(false)` 直接调用 `hide()`，`.onHover` 任何一次抖动都会导致预览消失
3. **show() 非幂等**：`show()` 开头无条件调用 `hide()` 再重建面板，同一 sticker 的 hover 抖动（false→true）会销毁/重建面板产生闪烁

## 方案

### 1. NSPanel 设置 `ignoresMouseEvents = true`（PreviewOverlay.swift）

预览面板不需要接收鼠标事件。设置后鼠标事件穿透面板传递给下层 SwiftUI 视图，从根本上避免面板干扰 `.onHover` 判定。

### 2. 幂等 show（PreviewOverlay.swift）

- 记录 `currentURL: URL?`，当 `show()` 的 URL 与当前一致时跳过重建，直接返回
- 仅 URL 不同时才关闭旧面板、创建新面板
- 这样 `.onHover` 抖动时重复 `show()` 不会销毁/重建面板

### 3. Debounced Hide + Generation Counter（PreviewOverlay.swift + StickerGridView.swift）

- 去掉现有的 `trackingTimer`（position-based 轮询），改用事件驱动
- 新增 `hideGeneration: Int`，每次 `show()` 或 `cancelHide()` 时递增
- **关键**：`show()` 最前面统一执行 `cancelHide + generation++`，然后再做 URL 幂等判断。确保同 URL 的 show 也能取消 pending hide
- `scheduleHide()` 捕获当前 generation，延迟 200ms 后检查 generation 是否仍匹配，匹配才执行 `hide()`
- `StickerGridView` 的 `onHover(false)` 改调 `scheduleHide()` 而非 `hide()`

### 4. @MainActor 线程安全（PreviewOverlay.swift）

- `PreviewPanelController` 标记 `@MainActor`，确保所有 NSPanel、Timer 操作都在主线程

### 5. 应用 / 窗口生命周期兜底（PreviewOverlay.swift）

- 监听 `NSApplication.didResignActiveNotification`，触发时强制 `hide()`
- 监听 `NSWorkspace.activeSpaceDidChangeNotification`，切换 Space 时强制 `hide()`
- 防止 app 失焦或切换桌面后预览面板悬挂

### 6. 数据源突变兜底（StickerCell.swift + PreviewOverlay.swift）

- `PreviewPanelController` 新增 `hideIfShowing(url:)` 方法
- `StickerCell.onDisappear` 中调用 `PreviewPanelController.shared.hideIfShowing(url: sticker.url)`
- 确保搜索结果刷新、cell 被移除时不会留下悬挂的预览面板

## 要修改的文件

| 文件 | 改动内容 |
|------|----------|
| `MojiSticker/Views/PreviewOverlay.swift` | `@MainActor`、`ignoresMouseEvents`、幂等 show、`scheduleHide` + generation、去掉 trackingTimer、监听 app 失焦 |
| `MojiSticker/Views/StickerGridView.swift` | `onHover(false)` 改用 `scheduleHide()` |
| `MojiSticker/Views/StickerCell.swift` | `onDisappear` 中加入条件隐藏 |

## 边界情况

- **鼠标在同一 cell 内移动**：`.onHover` 不变（或抖动后 200ms 内恢复），show 幂等 → 预览稳定
- **鼠标从 cell A 移到 cell B**：cell A 的 `onHover(false)` 触发 `scheduleHide()`，cell B 的 `onHover(true)` 触发 `show(newURL)` → generation 递增 → 旧的 scheduleHide 失效 → 无缝切换
- **鼠标离开所有 cell**：`onHover(false)` → `scheduleHide()` → 200ms 后 generation 匹配 → 隐藏
- **app 失焦 / 切换 Space**：`didResignActiveNotification` → 强制 `hide()`
- **滚动导致 cell 移出鼠标位置**：SwiftUI 自动触发 `onHover(false)` → `scheduleHide()` → 正常隐藏
- **搜索结果刷新 / cell 被移除**：`StickerCell.onDisappear` → `hideIfShowing(url:)` → 条件隐藏
- **切换 Space**：`activeSpaceDidChangeNotification` → 强制 `hide()`
