# Swift 编码规范

## 强制规则

### 可选类型安全

- **禁止** 强制解包（`!`），除非：
  - main Bundle 资源路径（`Bundle.main.path(forResource:)`）
  - 其他**确定不会为 nil** 的已知安全场景（需注释说明原因）
- 使用 `if let` / `guard let` 解包
- 可选链优先于强制解包
- 使用 `try?` 代替 `try!`

### 错误处理

- 所有可失败操作必须 throw 类型化错误（`PM2ServiceError` 枚举）
- `PM2ServiceError` 必须遵循 `LocalizedError`
- 每个 case 提供中文 `errorDescription`
- 调用处使用 `do-catch`（推荐）或 `try?`（不关心具体错误时）

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
| 布尔属性 | is/has/should 前缀 | `var isOnline: Bool` |

## 格式

- 缩进: 4 空格
- 花括号: K&R（同行）
- MARK: `// MARK: - SectionName`，前后各空一行
- 行长度: 无硬限制，保持可读性

## 修饰符顺序

**声明修饰符**: `访问控制 → @属性 → override → func/var/let`

```swift
@MainActor
@discardableResult
private func _executeStartProject(_ id: String) async -> Error?
```

**视图修饰符**: `类型/字体 → 行数限制 → 颜色 → 尺寸/对齐 → 事件处理`

```swift
Text("...")
    .font(.system(size: 13, weight: .medium))
    .lineLimit(1)
    .foregroundColor(.secondary)
    .frame(width: 220, alignment: .leading)
```

## 设计模式

- **依赖注入**: 协议注入，Mock 可替换: `init(pm2Service: PM2ServiceProtocol = PM2Service())`
- **Mock 工厂**: `static func mock(id: String, status: ProcessStatus) -> PM2Project`
- **乐观 UI**: `pendingStarts.insert(id)` → 执行操作 → `pendingStarts.remove(id)` → 刷新列表
- **防抖保存**: `saveDebounceTask` 500ms debounce，避免频繁写磁盘
