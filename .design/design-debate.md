# 设计辩论记录

## 第 1 轮

### Codex 反馈

| 级别 | 问题 | 处理 |
|------|------|------|
| P0 | `sourceRect` 由鼠标位置推算不可靠 | **接受并改进**：去掉 sourceRect 和 position-tracking timer，改为事件驱动（`ignoresMouseEvents` 让 `.onHover` 可靠 + debounce 处理抖动 + app 生命周期兜底） |
| P0 | `show()` 先 hide 再 show 导致闪烁 | **接受**：加入 `currentURL` 幂等判断，同一 sticker 不重建面板 |
| P1 | 隐藏机制重复（scheduleHide + timer）存在竞态 | **接受**：去掉 trackingTimer，统一用 scheduleHide + generation counter |
| P1 | 未明确主线程约束 | **接受**：加 `@MainActor` |
| P1 | 边界场景不完整（窗口失焦、滚动等） | **部分接受**：增加 `didResignActiveNotification` 监听；滚动由 `.onHover(false)` 自然处理 |
| P2 | 魔法数无依据 | 记录，不在此轮处理 |
| P2 | 缺少验收标准 | 记录，不在此轮处理 |

## 第 2 轮

### Codex 反馈

| 级别 | 问题 | 处理 |
|------|------|------|
| P0 | show() 幂等分支未取消 pending hide，导致竞态 | **接受**：show() 最前面统一执行 cancelHide + generation++，再做 URL 幂等判断 |
| P1 | 切换 Space 不等于 app 失焦，兜底不充分 | **接受**：补充监听 `NSWorkspace.activeSpaceDidChangeNotification` |
| P1 | 数据源突变/视图重建时可能留下悬挂面板 | **接受**：新增 `hideIfShowing(url:)` 方法，在 StickerCell.onDisappear 中调用 |
