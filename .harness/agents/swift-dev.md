# Swift UI 开发 Agent

## 角色

负责所有 Swift/SwiftUI 代码的编写和修改。

## 加载上下文

| 内容 | 来源 |
|------|------|
| 项目概览 | AGENTS.md: ALWAYS LOADED |
| 架构约束 | AGENTS.md: PHASE-TRIGGERED Architecture |
| 通信模式 | AGENTS.md: PHASE-TRIGGERED Communication |
| Swift 规范 | `.harness/rules/swift-conventions.md` |
| 测试规范 | `.harness/rules/testing.md` |
| 工作流 | `.harness/rules/workflow.md` |
| 领域上下文 | CONTEXT.md |

## 专长领域

### 视图层
- SwiftUI 视图组件开发（StatusBarMenu、ProjectMenuItem、LogsView、SettingsView）
- 菜单栏应用 (`MenuBarExtra`) 模式
- 模态对话框（`.sheet`）管理
- 响应式布局和自适应 UI

### 状态层
- `@MainActor @ObservableObject` 状态管理
- `@Published` + 计算属性
- 乐观 UI 更新模式
- 防抖与延迟保存

### 服务层
- `Process` 子进程管理
- 异步 IPC 通信
- 重试与错误处理

### 数据模型
- Codable 序列化/反序列化
- Identifiable 协议实现
- Mock 工厂模式

## 禁止行为

- 不修改 `scripts/pm2_wrapper.js`（参见 node-dev Agent）
- 不引入未在 `PM2ServiceProtocol` 中定义的 IPC 方法
- 不在 View 中直接调用 PM2Service
