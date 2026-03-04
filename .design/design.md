# 性能优化设计文档

## 目标

优化 MojiSticker 的启动性能和搜索/浏览过程中的性能，减少主线程阻塞和不必要的重复计算。

## 非目标

- 不改变 UI 外观或交互方式
- 不改变 API 调用逻辑
- 不改变缓存存储路径
- 不添加 os_signpost 等性能监控基础设施（小型工具，优化效果通过体感判断）

## 问题分析与方案

### 1. 启动阶段主线程阻塞

**问题**: `applicationDidFinishLaunching` 中同步执行文件 I/O 操作：
- `ClipboardService.cleanupTempFiles()` — 枚举临时目录并删除文件
- `migrateCookieStorage()` — 读取/验证 cookie 文件

**方案**:
- `cleanupTempFiles()` 移到后台队列异步执行（不影响功能）
- `migrateCookieStorage()` 保持同步执行（搜索依赖 cookie，异步化会引入竞态）

**修改文件**: `MojiSticker/App/AppDelegate.swift`

### 2. 动画帧解码统一缓存与复用

**问题**: 同一张动图的帧会被多次解码：
- `StickerCell.loadImage()` 中提取帧用于 hover 动画
- `PreviewContentView.startAnimationIfNeeded()` 中再次提取帧用于预览

`ImageProcessor.extractFrames()` 是 CPU 密集操作（解码每一帧），重复调用浪费大量 CPU。

注意：复制操作（`performCopy`）走的是 `resizeAnimatedImage` 路径，和浏览帧提取是不同的操作，不在本优化范围内。

**方案**: 新建 `FrameDecodeService`（actor），提供：
- **帧缓存**：NSCache，key 为 URL，value 为帧数组。设置 countLimit（30）和 totalCostLimit（按 `width*height*4*frameCount` 估算 cost）
- **并发控制**：waiter 队列 + 信号量（计数 3），acquireSlot 通过 withTaskCancellationHandler 支持取消清理
- **取消支持**：nonisolated func 在调用方 task 上下文中执行解码，取消自然传播；等待队列中已取消的 task 自动从队列移除
- **帧数硬限制**：复用现有 `extractFrames` 的 200 帧上限

**修改文件**:
- 新建 `MojiSticker/Services/FrameDecodeService.swift`
- `MojiSticker/Views/StickerCell.swift` — 改为通过 FrameDecodeService 获取帧
- `MojiSticker/Views/PreviewOverlay.swift` — 改为通过 FrameDecodeService 获取帧

### 3. StickerCell detectAnimation 重复调用

**问题**: `StickerCell` 中 `detectAnimation` 被多次调用：
- `loadImage()` 结尾检查一次
- `animationBadge` computed property 中每次重绘调用一次

**方案**: 在 `loadImage()` 中一次性检测并缓存动画类型到 `@State` 变量，`animationBadge` 使用缓存值。

**修改文件**: `MojiSticker/Views/StickerCell.swift`

### 4. 磁盘缓存无限增长

**问题**: `ImageCacheService` 的磁盘缓存目录 `~/.moji/cache` 没有大小限制或清理策略。

**方案**: 启动时在后台延迟 5 秒执行磁盘缓存清理：
- 枚举缓存目录，按文件修改时间排序
- 如果总大小超过 200MB，删除最旧的文件直到降到 150MB 以下
- 使用文件修改时间（我们自己写入的文件，时间可靠）

**修改文件**: `MojiSticker/Services/ImageCacheService.swift`

## 要修改的文件清单

1. `MojiSticker/App/AppDelegate.swift` — cleanupTempFiles 异步化
2. `MojiSticker/Services/FrameDecodeService.swift` — 新建，帧解码服务
3. `MojiSticker/Services/ImageCacheService.swift` — 磁盘缓存清理
4. `MojiSticker/Views/StickerCell.swift` — 使用 FrameDecodeService + detectAnimation 缓存
5. `MojiSticker/Views/PreviewOverlay.swift` — 使用 FrameDecodeService

## 边界情况

- 帧缓存内存控制：NSCache 的 countLimit + totalCostLimit 双重限制，系统内存压力时自动淘汰
- 磁盘清理不阻塞启动：后台低优先级队列，延迟 5 秒执行
- 帧缓存 key：使用 URL（CDN 静态资源 URL 不变，无需加 schema version）
- 所有帧解码通过 FrameDecodeService 统一调度（nonisolated func），在调用方 task 上下文中执行
- acquireSlot 支持取消清理：已取消的 waiter 自动从队列移除，不占用后续解码位
- 解码完成后检查 Task.isCancelled，避免设置已过期的 state
- 帧缓存提供隐式去重：第二次相同 URL 请求通常命中缓存，不重复解码
