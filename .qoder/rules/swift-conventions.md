---
trigger: model_decision
description: Swift 编码强制规则（可选类型安全、错误处理、线程安全），命名约定，格式标准（缩进/MARK/修饰符顺序），设计模式（依赖注入/Mock/乐观更新/防抖保存）。
---
# Swift 编码规范

## 强制规则（不可违反）

### 可选类型安全
- **禁止** 强制解包（`!`），除非：
  - main Bundle 资源路径（`Bundle.main.path(forResource:)`）
  - 其他**确定不会为 nil** 的已知安全场景
- 使用 `if let` / `guard let` 解包
- 可选链优先于强制解包
- 使用 `try?` 代替 `try!`

### 错误处理
- 所有可失败操作必须 throw 类型化错误（`PM2ServiceError` 枚举）
- `PM2ServiceError` 必须遵循 `LocalizedError`
- 每个 case 提供中文 `errorDescription`
- 调用处必须 `do-catch` 或 `try?`/`try!`（极少）

### 线程安全
- AppState 和其他 ObservableObject 标记 `@MainActor`
- Service 层使用串行 `DispatchQueue`
- 所有 UI 更新在主线程执行

## 命名约定

| 用途 | 规范 | 示例 |
|------|------|------|
| 类型/协议 | PascalCase | `PM2Project`, `PM2ServiceProtocol` |
| 变量/函数 | camelCase | `filterText`, `fetchProjects()` |
| 枚举 case | camelCase | `case online`, `case commandFailed(String)` |
| 私有方法 | camelCase + `_` 前缀 | `_executeStartProject()` |
| 常量 | camelCase | `static let defaultHeight` |
| 计算属性 | camelCase | `var isOnline: Bool` |

## 格式

- 缩进: 4 空格
- 花括号: K&R（同行）
- MARK: `// MARK: - SectionName`，前后各空一行
- 行长度: 无硬限制，保持可读性

## 修饰符顺序

### 声明修饰符
```
访问控制 → @属性 → override → func/var/let
```
```swift
@MainActor
@discardableResult
private func _executeStartProject(_ id: String) async -> Error?
```

### 视图修饰符
```
类型/字体 → 行数限制 → 颜色 → 尺寸/对齐 → 事件处理
```
```swift
Text("...")
    .font(.system(size: 13, weight: .medium))
    .lineLimit(1)
    .foregroundColor(.secondary)
    .frame(width: 220, alignment: .leading)
```

## 设计模式

### 依赖注入
```swift
init(pm2Service: PM2ServiceProtocol = PM2Service(), ...)
```

### Mock 工厂
```swift
static func mock(id: String, status: ProcessStatus) -> PM2Project
```

### 乐观 UI 更新
```swift
pendingStarts.insert(id)        // 立即显示处理中
try await pm2Service.startProject(id)  // 异步执行
pendingStarts.remove(id)        // 完成后恢复
```

### 防抖保存
```swift
saveDebounceTask?.cancel()
saveDebounceTask = Task { @MainActor in
    try? await Task.sleep(nanoseconds: 500_000_000)
    // 保存
}
```
