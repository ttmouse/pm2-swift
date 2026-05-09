# Working Boundaries

## Allowed without approval

- UI 组件修改（View 层内的布局、颜色、文本、交互细节）
- 非关键业务逻辑的 bug fix（过滤、排序、展示层面的错误）
- 新增/修改测试
- 文档更新（注释、CONTEXT.md、本目录下的 harness 文件）
- 重构私有方法（签名不变）

## Requires approval

- `PM2ServiceProtocol` 协议定义变更
- `AppState` 公开方法签名变更
- 新增 NPM / Swift Package 依赖
- Node.js 封装层（`pm2_wrapper.js`）IPC 协议修改
- 新增文件（超过 1 个文件的新模块）
- 配置持久化格式变更（`AppConfig`）

## Forbidden

- 移除或弱化现有测试来让 CI 通过
- 修改 `Bundle Identifier`、版本号等 Xcode 项目配置
- 删除 UserDefaults key 不做迁移兼容
- 直接修改 `pm2_wrapper.js` 的 stdout/stderr 输出格式而不更新 Swift 端解析逻辑
- 提交 `.env`、credentials 等敏感文件

## Architecture Boundaries

### 三层架构不可逆

```
View Layer (SwiftUI) ──observes──▶ AppState ──calls──▶ PM2Service ──IPC──▶ pm2_wrapper.js
```

- View 层**不能**直接调用 PM2Service（必须通过 AppState）
- Service 层**不能**引用 View 类型（不 import 任何 SwiftUI 模块）
- AppState **不能**包含 UI 逻辑（不管理 `@State`、布局等）

### 状态管理

- `AppState` 是唯一的状态持有者（`@MainActor @ObservableObject`）
- Views 通过 `@ObservedObject` 观察 AppState
- 临时 UI 状态（弹窗、展开、选中）用 `@State` 在视图内部管理
- 配置持久化通过 `ConfigPersistence` 协议，不直接写 UserDefaults

### 并发控制

- 刷新操作必须检查 `isRefreshing` 防重入
- 组级操作使用 `withTaskGroup` 并发执行子操作
- 操作完成前锁定组状态（`groupOperationInProgress[key]`）
- 配置保存使用 500ms debounce

### 文件职责

| 文件 | 应包含 | 不应包含 |
|------|--------|----------|
| `PM2Project.swift` | 模型定义、格式化方法、mock 工厂 | IPC 逻辑、UI 代码 |
| `AppState.swift` | 状态管理、业务编排、过滤排序 | 视图定义、IPC 细节 |
| `PM2Service.swift` | IPC 通信、命令执行、错误映射 | UI 逻辑、状态缓存 |
| `StatusBarMenu.swift` | 菜单布局、项目列表 | IPC 调用、数据持久化 |
| `ProjectMenuItem.swift` | 单行项目展示 | 业务逻辑、批量操作 |

## High-risk areas

| 区域 | 风险 | 操作前必须 |
|------|------|-----------|
| `PM2Service.swift` IPC 通信 | 破坏 Swift ↔ Node.js 契约 | 理解 stderr 错误 JSON 格式和超时机制 |
| `AppState.swift` 并发控制 | `isRefreshing` / `groupOperationInProgress` 竞态 | 理解防重入和串行队列 |
| `ConfigPersistence` | 配置读取失败导致 app 异常 | 写向后兼容代码 |
| `pm2_wrapper.js` 连接生命周期 | `pm2.disconnect()` 遗漏导致孤儿连接 | 确保所有路径断开 |
