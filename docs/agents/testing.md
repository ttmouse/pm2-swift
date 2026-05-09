---
trigger: model_decision
description: XCTest 测试架构规范，MockPM2Service 实现标准，分组测试模式，断言类型，覆盖面要求，测试运行命令。
---
# 测试规范

## 测试架构

- **测试框架**: XCTest
- **测试类注解**: `@MainActor`（确保主线程执行）
- **异步初始化**: `override func setUp() async throws`
- **Mock 模式**: `MockPM2Service` 实现 `PM2ServiceProtocol`

## Mock 服务规范

```swift
final class MockPM2Service: PM2ServiceProtocol {
    // 可配置行为
    var shouldThrowOnStart = false
    var shouldThrowOnStop = false
    var startedProjects: [String] = []
    var stoppedProjects: [String] = []
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

## 测试策略

### 分组测试模式
```swift
func testStartGroup_StartsAllStoppedProjects() async {
    // 1. Arrange — 初始化 AppState + MockPM2Service
    // 2. Act — 调用组操作方法
    // 3. Assert — 验证 mock 调用记录
    let expected = ["svc1", "svc2"]
    XCTAssertEqual(mockService.startedProjects.sorted(), expected)
}
```

### 断言类型
- 状态断言: `XCTAssertTrue(appState.isGroupOnline("xm-console"))`
- 相等断言: `XCTAssertEqual(mockService.startedProjects, [...])`
- 错误断言: 验证错误被正确捕获和处理

### 覆盖面要求
- 分组逻辑必须有单元测试
- Mock 服务必须覆盖所有 PM2ServiceProtocol 方法
- 关键业务逻辑（过滤、排序、分组）优先测试

## 运行命令

```bash
xcodebuild test -scheme VisualPM2GUI -destination 'platform=macOS'
```
