# 改动摘要

## 修改/新建的文件清单

| 文件 | 类型 | 改动说明 |
|------|------|----------|
| `MojiSticker/App/AppDelegate.swift` | 修改 | cleanupTempFiles 移到后台队列；添加磁盘缓存清理调度 |
| `MojiSticker/Services/FrameDecodeService.swift` | 新建 | 帧解码服务 actor：帧缓存 + 并发控制(3) + 可取消等待队列 |
| `MojiSticker/Services/ImageCacheService.swift` | 修改 | 添加磁盘缓存清理逻辑（启动后延迟 5 秒，超 200MB 清理到 150MB） |
| `MojiSticker/Views/StickerCell.swift` | 修改 | 帧提取改用 FrameDecodeService；detectAnimation 结果缓存到 @State |
| `MojiSticker/Views/PreviewOverlay.swift` | 修改 | 帧提取改用 FrameDecodeService；show() 增加 url 参数 |
| `MojiSticker/Views/StickerGridView.swift` | 修改 | onHover 回调增加 url 参数传递 |
| `MojiSticker.xcodeproj/project.pbxproj` | 自动生成 | XcodeGen 重新生成 |

## 风险点

- FrameDecodeService 的并发控制使用手动信号量，需确保异常路径也释放令牌（已通过 defer 保证）
- 磁盘清理的文件枚举在缓存目录很大时可能耗时，但在后台低优先级队列执行不影响 UI

## 需要人工确认的事项

- 优化后 hover 预览的帧加载是否仍然流畅（因为改用了异步帧解码服务）
- 磁盘缓存 200MB 上限是否合适（可根据实际使用调整）
