# 改动摘要

## 修改的文件

| 文件 | 改动 |
|------|------|
| `MojiSticker/Views/PreviewOverlay.swift` | 重写 PreviewPanelController：幂等 show、debounced hide + generation counter、ignoresMouseEvents、生命周期监听、hideIfShowing |
| `MojiSticker/Views/StickerGridView.swift` | onHover(false) 改用 scheduleHide() |
| `MojiSticker/Views/StickerCell.swift` | onDisappear 中加入条件隐藏 |

## 风险点

- debounce 200ms 延迟：鼠标离开 cell 后预览会多停留 200ms 才消失，用户体验上可能略有感知（但远好于闪烁消失）
- `ignoresMouseEvents = true`：如果将来需要在预览面板上添加交互（如点击），需要移除此设置

## 需要人工确认的事项

- 实际鼠标 hover 操作验证：在小图上缓慢/快速移动鼠标，确认预览稳定不闪烁
- 多显示器场景下预览位置是否正常
