# Testing & Verification

## 测试架构

- **框架**: XCTest
- **测试类注解**: `@MainActor`（确保主线程执行）
- **异步初始化**: `override func setUp() async throws`
- **Mock 模式**: `MockPM2Service` 实现 `PM2ServiceProtocol`，可配置行为

## Mock 规范

```swift
final class MockPM2Service: PM2ServiceProtocol {
    // 可配置行为
    var shouldThrowOnStart = false
    var shouldThrowOnStop = false

    // 调用记录（用于断言）
    var startedProjects: [String] = []
    var stoppedProjects: [String] = []

    // Mock 数据
    var mockProjects: [PM2Project] = []

    func startProject(_ id: String) async throws {
        if shouldThrowOnStart {
            throw PM2ServiceError.commandFailed("mock error")
        }
        startedProjects.append(id)
    }
    // ... 其他方法类似
}
```

Mock 必须覆盖 `PM2ServiceProtocol` 的**所有方法**，确保协议变更时测试立即编译报错。

## 断言类型

1. **状态断言**: `XCTAssertTrue(appState.isGroupOnline("xm-console"))`
2. **调用记录断言**: `XCTAssertEqual(mockService.startedProjects, ["svc-a", "svc-b"])`
3. **错误断言**: 验证错误被正确捕获和处理

## 测试模式

```
Arrange → Act → Assert
1. 初始化 AppState + MockPM2Service
2. 调用被测试方法
3. 验证 Mock 调用记录 + AppState 状态
```

## 按任务类型验证

### UI 改动

改动 `Views/` 下文件的 SwiftUI 视图。

- [ ] `./build.sh` 编译通过
- [ ] 手动验证：操作对应 UI 元素确认行为正确
- [ ] 无需新增单元测试（UI 层无业务逻辑）

### 业务逻辑改动

改动 `Models/`、`AppState` 的过滤/排序/分组逻辑。

- [ ] `./build.sh` 编译通过
- [ ] `xcodebuild test` 全部通过
- [ ] 新增或更新对应单元测试
- [ ] 回归测试：修改前运行基线，修改后对比

### IPC 改动

改动 `PM2Service.swift` 或 `pm2_wrapper.js`。

- [ ] `./build.sh` 编译通过
- [ ] `xcodebuild test` 全部通过
- [ ] stdout JSON 格式校验
- [ ] stderr 错误 JSON 格式校验
- [ ] `pm2.disconnect()` 在所有路径上被调用
- [ ] 手动冒烟：执行对应 PM2 命令验证

### Bug fix

- [ ] `./build.sh` 编译通过
- [ ] `xcodebuild test` 全部通过
- [ ] 新增测试覆盖修复场景（防止回归）
- [ ] 说明根因，避免同类错误

### Refactor

- [ ] `./build.sh` 编译通过
- [ ] `xcodebuild test` 全部通过
- [ ] 行为不变性确认（测试全部通过即证明）
- [ ] 标注修改了哪些公开接口（如有）

### 文档改动

改动 `docs/`、`.harness/`、`CONTEXT.md`、`AGENTS.md`。

- [ ] `./build.sh` 编译通过（验证不破坏构建）
- [ ] 链接有效性检查（相关文档引用路径正确）

## 覆盖面优先级

```
高：分组逻辑、过滤排序、错误处理
中：项目操作、配置持久化、端口检测
低：UI 布局、颜色字体
```

## 验证报告格式

每次代码改动后输出：

```md
## 验证记录
- [x] 编译通过
- [x] 全部测试通过（N 项）
- [x] 新增测试（N 项）
- [x] 手动验证通过
- [ ] ~需人工验收~（如有）
```
