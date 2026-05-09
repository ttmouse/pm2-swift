# Architecture Rules

## 分层约束

### 1. 三层架构不可逆

```
View Layer (SwiftUI)  ──observes──▶  State Layer (AppState)  ──calls──▶  Service Layer (PM2Service)
                                                                              │
                                                                              ▼
                                                                      Node.js IPC (pm2_wrapper.js)
```

- View 层**不能**直接调用 PM2Service（必须通过 AppState）
- Service 层**不能**引用 View 类型
- AppState **不能**包含 UI 逻辑

### 2. 服务层 IPC 契约

- `PM2Service` 是所有 Node.js IPC 的唯一入口
- 所有 IPC 命令必须通过 `executePM2Command` 系列方法
- 输出解析必须是 JSON（stdout）或 `{"error": "message"}`（stderr）
- 必须处理退出码：0=成功，非0=失败

### 3. 状态管理

- `AppState` 是唯一的状态持有者（`@MainActor @ObservableObject`）
- Views 通过 `@ObservedObject` 观察 AppState
- 临时 UI 状态（如 `showingLogs`）可用 `@State` 在视图内部管理
- 配置持久化通过 `ConfigPersistence` 协议，不要直接写 UserDefaults

### 4. 并发控制

- 刷新操作必须检查 `isRefreshing` 防止竞态
- 组级操作使用 `withTaskGroup` 并发执行子操作
- 操作完成前锁定组状态（`groupOperationInProgress`）
- 配置保存使用 500ms debounce

## 文件职责

| 文件 | 应包含 | 不应包含 |
|------|--------|----------|
| `PM2Project.swift` | 模型定义、格式化方法、mock 工厂 | IPC 逻辑、UI 代码 |
| `AppState.swift` | 状态管理、业务编排、过滤排序 | 视图定义、IPC 细节 |
| `PM2Service.swift` | IPC 通信、命令执行、错误映射 | UI 逻辑、状态缓存 |
| `StatusBarMenu.swift` | 菜单布局、项目列表 | IPC 调用、数据持久化 |
| `ProjectMenuItem.swift` | 单行项目展示 | 业务逻辑、批量操作 |
