# PRD：PM2 项目分组与组管理

## 问题陈述

pm2-swift macOS 状态栏应用管理着大量 PM2 进程（16+）。随着项目数量增长，平铺列表变得难以管理。分组逻辑不合理（例如 `XM-bazi-backend` 和 `xm-console-api` 都被归入 `XM`/`xm` 组），组级操作（启动/停止组内所有项目）的 UI 反馈不可靠——toggle 开关在异步操作完成前就弹回，让用户误以为操作失败。

## 解决方案

实现基于两段连字符前缀的分组系统（`{project-name}-{role}`），自动将同一服务的相关项目（如 backend/frontend）归入同一组。修复 group toggle 的 Binding，通过 `@State` 跟踪进行中的操作状态，使 toggle 在异步期间保持正确状态。提供清晰的组级操作视觉反馈。

## 用户故事

1. 作为用户，我希望属于同一服务的项目（如 `xm-console-api` + `xm-console-frontend`）出现在同一组中，以便将它们作为单元管理。

2. 作为用户，我希望具有相同顶层前缀但属于不同服务的项目（如 `xm-console-*` vs `xm-digital-human-*`）出现在不同组中，以便区分不同服务。

3. 作为用户，我希望一键启动组内所有已停止的项目，以免逐个启动。

4. 作为用户，我希望一键停止组内所有运行中的项目，以便快速关闭整个服务。

5. 作为用户，我希望 group toggle 在启动操作进行中保持在"开"的位置，以便看到我的操作已被注册。

6. 作为用户，我希望 group toggle 在操作进行中被禁用，以免误发重复命令。

7. 作为用户，我希望组按活跃状态排序（有在线项目的组排在前面），然后按字母顺序排列，以便快速找到正在运行的服务。

8. 作为用户，我希望可以折叠/展开组以减少视觉杂乱，以便专注于相关项目。

9. 作为用户，我希望看到每个组的项目数量，以便快速了解各组规模。

10. 作为用户，我希望从组头部打开终端或 Finder 到项目的目录，以便快速导航。

11. 作为用户，我希望包含异常（errored）项目的组能视觉上区分，以便快速识别有问题的服务。

12. 作为用户，我希望分组能响应类别和文本过滤，使过滤后的视图只显示相关组。

## 实现决策

### 模块 1：ProjectGroupKey（PM2Project.swift）

- **接口**：计算属性 `var projectGroupKey: String`
- **算法**：按 `-` 分割 `id`，取前两段拼接。不足两段时使用唯一段。降级到下划线分割，再降级到 `"未分组"`。
- **示例**：
  - `XM-bazi-backend` → `XM-bazi`
  - `xm-console-api` → `xm-console`
  - `web-share` → `web-share`
  - `subform` → `subform`
- **边界情况**：无分隔符的单词名 → 整个名称作为组名。下划线命名 → 取第一段。空名称 → `"未分组"`。

### 模块 2：GroupManagement（AppState.swift）

- **接口**：
  - `func startProjectsInGroup(_ projectGroupKey: String) async` — 过滤 `projects` 中 `projectGroupKey == key && !isOnline` 的项目，通过 `TaskGroup` 并行调用 `startProject`，最后持久化启动状态。
  - `func stopProjectsInGroup(_ projectGroupKey: String) async` — 过滤 `projects` 中 `projectGroupKey == key && isOnline` 的项目，通过 `TaskGroup` 并行调用 `stopProject`，持久化停止状态。
  - `func isGroupOnline(_ projectGroupKey: String) -> Bool` — `allSatisfy { $0.isOnline }` 判断组内所有项目是否在线。
  - `var sortedGroupedProjects: [(groupName: String, projects: [PM2Project])]` — `Dictionary(grouping:by:)` 分组后按活跃状态、字母顺序排序。
- **并发**：使用 `withTaskGroup` 并行执行组内项目操作。每个 `startProject`/`stopProject` 内部包含乐观 UI + PM2 IPC + refresh 三阶段。
- **持久化**：组级操作通过 `ConfigManager.shared.markProjectStarted/Stopped` 保存状态。

### 模块 3：GroupToggleUI（StatusBarMenu.swift）

- **Toggle Binding**：使用 `Binding(get:set:)`，`get` 返回 `isGroupActive || pendingGroupToggles.contains(groupName)`，确保 toggle 在异步窗口期间保持"开"位。
- **禁用状态**：`.disabled(pendingGroupToggles.contains(projectGroup))` 防止重复点击。
- **组头部**：折叠/展开箭头、组名 + 项目数、Terminal 按钮、Finder 按钮、主开关 toggle。
- **排序**：组按活跃状态（在线优先）再按字母顺序排列。

### 模块 4：GroupOperationState（StatusBarMenu.swift）

- **状态**：`@State private var pendingGroupToggles: Set<String>`
- **生命周期**：toggle 触发时插入，异步操作完成后移除（无论成功或失败）。
- **作用域**：按组隔离，支持多组独立操作。

### 模块 5：PM2Service IPC 层（PM2Service.swift + pm2_wrapper.js）

- **按名称启动**：`start <project-name>` 流程：检查非文件路径 → 加载 `/Users/douba/.pm2/ecosystem.config.js` → 按名称查找应用配置 → `pm2.start(appConfig)`。
- **重试**：指数退避（0.3s, 0.6s, 1.2s 基准），最多 3 次重试。
- **错误处理**：非零退出码 → 解析 stderr JSON → 抛出类型化 `PM2ServiceError`。

## 测试决策

- **好测试的标准**：只测外部行为，不测实现细节。验证分组结果是否正确、toggle 状态能否反映异步操作进度、PM2 IPC 命令是否传递了正确的参数。
- **需要测试的模块**：
  1. `ProjectGroupKey` — 单元测试各种项目 ID 到预期组名的映射。覆盖边界情况：单段名、下划线分隔名、多段名。
  2. `GroupManagement` — 集成测试验证过滤后的项目是否匹配组键，`isGroupActive` 能否正确反映在线/离线状态。
  3. `GroupToggleUI` — UI 测试验证操作进行中 toggle 的视觉状态。
  4. `PM2Service.startProject` — 集成测试验证 IPC 参数正确性和错误处理。
- **测试框架**：Swift 代码使用 XCTest。Node.js wrapper 可使用 Jest 或 node:test。

## 不在此范围

- 用户自定义分组规则（标签、类别、手动分组）
- 拖拽重排分组
- 组级日志聚合（同时查看组内所有项目的日志）
- 组级配置（端口冲突、启停依赖顺序）
- 嵌套分组（组内子组）
- 折叠状态的跨重启持久化
- 组级资源使用可视化（聚合 CPU/内存）

## 补充说明

- 分组规则使用项目 `id`（PM2 进程名），而非 `name`（显示名）。这是有意为之——`id` 是 PM2 注册的唯一稳定标识。
- 该 repo 未执行 `setup-matt-pocock-skills` 脚手架，因此没有 ADR 目录或 CONTEXT.md。除了 AGENTS.md 中的文档外，不存在领域术语词汇表。
- group toggle 弹回 bug 是一个典型的 SwiftUI `Binding` 问题：`get` 闭包按值捕获了 `let` 常量，因此 binding 无法反映进行中的状态。添加 `@State` 的 `pendingGroupToggles` 集合并让 `get` 返回 `isGroupActive || pendingGroupToggles.contains(groupName)` 解决了此问题。
