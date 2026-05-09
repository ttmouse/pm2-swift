# Add Feature 技能

## 目的

在 pm2-swift 中安全、一致地添加新功能。

## 流程

### 1. 定位影响范围

确定新功能涉及的层级：

```
功能起点
  ├── 仅 View 层（UI 调整、布局变更）
  ├── View + State（新操作、过滤、排序）
  ├── State + Service（新 IPC 命令）
  └── Service + Node.js（全新子命令）
```

对于每个层级，确认需要修改的文件。

### 2. 协议定义（如果需要新的 IPC）

如果功能需要新的 PM2 命令：

**Step 1**: 在 `scripts/pm2_wrapper.js` 中添加 `case` 处理

**Step 2**: 在 `PM2Service.swift` 中添加对应的 `PM2ServiceProtocol` 方法

**Step 3**: 在 `PM2Service` 类中实现方法（调用 `executePM2Command`）

**Step 4**: 更新 `MockPM2Service` 确保测试可用

### 3. 状态管理

在 `AppState.swift` 中：

- 添加 `@Published` 属性（如需持久化状态）
- 添加操作方法（遵循乐观更新模式）
- 更新过滤/排序逻辑（如果新属性影响排序）

### 4. 视图层

- 创建或修改 View 组件
- 使用 `@ObservedObject` 观察 AppState
- 新组件遵循现有的设计系统（参见 `DesignSystem.swift`）

### 5. 遵循工作流

1. 需求分析 → 2. 设计 → 3. 编码 → 4. 自审 → 5. 验证

## Checklist

- [ ] 功能影响范围已确认
- [ ] 协议/接口已更新
- [ ] Node.js 命令已实现
- [ ] Swift Service 层已实现
- [ ] Swift State 层已更新
- [ ] 视图已更新/创建
- [ ] MockPM2Service 已更新
- [ ] 构建通过
- [ ] 测试通过
- [ ] CHANGELOG 已更新
