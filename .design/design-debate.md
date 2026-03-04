# 设计辩论记录

## 第 1 轮

### Codex 反馈

| 严重级别 | 问题 | 处理结果 |
|----------|------|----------|
| P0 | 启动 I/O 全部后台化会引入 Cookie 迁移竞态 | **接受** — migrateCookieStorage 保持同步，只有 cleanupTempFiles 后台化 |
| P0 | Task.detached 无并发上限，滚动时可能 CPU 风暴 | **接受** — 改为集中式 FrameDecodeService actor，限制并发 3 + inflight 去重 |
| P1 | performCopy 并不调用 extractFrames（设计描述有误） | **接受** — 修正描述，明确复制走 resizeAnimatedImage，和浏览帧提取分开 |
| P1 | 缺少 inflight 任务去重 | **接受** — FrameDecodeService 维护 inflight 字典 |
| P1 | 缓存 key 仅用 URL 不安全 | **拒绝** — CDN 静态资源 URL 不变，URL 作 key 足够，加 schema version 过度设计 |
| P1 | 内存边界只限条目数，动图帧可能很大 | **部分接受** — 加 totalCostLimit（按帧数据大小估算），但不做超大资源降级 |
| P1 | 磁盘清理按最后访问时间不可靠 | **部分接受** — 改用文件修改时间（自己写入的文件，可靠），不引入 manifest |
| P1 | 缺少性能验收标准和 os_signpost | **拒绝** — 小型 menubar 工具，os_signpost 过度工程化，体感判断即可 |
| P1 | 缺少测试计划 | **拒绝** — 项目无测试基础设施，超出本次优化范围 |
| P2 | 章节 2 和 6 冗余 | **接受** — 合并为"动画帧解码统一缓存与复用" |

## 第 2 轮

### Codex 反馈

| 严重级别 | 问题 | 处理结果 |
|----------|------|----------|
| P0 | 边界情况仍提到 Task.detached，与集中式服务矛盾 | **接受** — 修正措辞，明确所有解码走 FrameDecodeService |
| P1 | 单个超大动图解码内存峰值未控制 | **接受** — 文档补充现有 200 帧上限作为硬约束 |
| P1 | 排队策略无界积压 | **部分接受** — StickerCell .task 生命周期自动取消，自然限制积压 |
| P1 | StickerCell 复用导致旧 badge | **拒绝** — ForEach 用 UUID 作 identity，每个 sticker 唯一，cell 不会跨 sticker 复用 |
| P2 | 磁盘清理只在启动时 | **拒绝** — menubar 工具用户通常每日重启，启动清理足够 |
