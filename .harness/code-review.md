# Code Review Checklist

## Correctness

- [ ] 逻辑是否正确，边界情况是否处理
- [ ] 异步操作是否有竞态风险
- [ ] IPC 输出格式是否正确（stdout JSON / stderr 错误 JSON）

## Architecture

- [ ] View 层没有直接调用 PM2Service
- [ ] Service 层没有引用 SwiftUI 类型
- [ ] AppState 没有包含 UI 逻辑
- [ ] pm2.disconnect() 在所有路径上被调用

## Safety

- [ ] 无强制解包（`!`）
- [ ] 所有可失败操作抛出类型化错误（`PM2ServiceError`）
- [ ] UI 操作标记 `@MainActor`

## Security

- [ ] 没有将敏感信息（路径、端口）硬编码到 UI
- [ ] 子进程命令参数没有注入风险（Node.js 参数由 Swift 端构建，无用户输入直接拼接到命令）

## Performance

- [ ] 没有在 View 层执行耗时操作（网络、文件 IO 等）
- [ ] 列表渲染没有 O(n²) 复杂度

## Compatibility

- [ ] 没有使用低于 macOS 14.0 的 API
- [ ] SwiftUI 视图兼容 light/dark 模式（颜色使用 `@Environment` 或语义色）

## Testing

- [ ] 新增功能有对应测试
- [ ] Mock 覆盖所有 `PM2ServiceProtocol` 方法
- [ ] 现有测试未被修改或弱化

## Maintainability

- [ ] 没有遗留调试代码、注释掉的代码
- [ ] 代码注释用中文说明业务含义
- [ ] 命名符合规范（camelCase / PascalCase）
- [ ] 没有过度工程（无过早抽象、未使用的配置项）

## 三轮上限

1. 评审发现问题 → 返回修改
2. 修改后再次评审
3. 3 轮仍不过 → 标记人工介入

每轮必须输出明确结论：✅ 通过 / ❌ 拒绝（附原因）
