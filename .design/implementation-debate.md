# 代码审查辩论记录

## 第 1 轮

### Codex 反馈

| 严重级别 | 问题 | 处理结果 |
|----------|------|----------|
| P1 | inflight Task 取消不传播，快速滚动时解码任务积压 | **接受** — 重构为 nonisolated func，在调用方 task 上下文中执行解码，取消自然传播 |
| P1 | PreviewContentView await 后缺 Task.isCancelled 检查，可能泄漏 Timer | **接受** — await 后增加 guard !Task.isCancelled 检查 |
| P2 | 磁盘清理 removeItem 失败仍扣减 totalSize | **接受** — 改为 do/catch，只在删除成功后扣减 |
| P2 | cleanupTempFiles 异步后可能误删新 session 文件 | **拒绝** — 启动时用户不可能在毫秒内触发复制，实际风险极低 |

## 第 2 轮

### Codex 反馈

| 严重级别 | 问题 | 处理结果 |
|----------|------|----------|
| P1 | acquireSlot 等待队列中已取消的 task 不清理 | **接受** — 改用 withTaskCancellationHandler + waiter ID，取消时从队列移除 |
| P2 | inflight 去重在 nonisolated 重构后丢失 | **拒绝** — cache 命中率高，第二个请求通常走缓存；nonisolated 下实现去重复杂度过高 |
