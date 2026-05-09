# AGENTS.md

<!-- ====================================================================== -->
<!-- ALWAYS LOADED — 每次会话必须加载                                    -->
<!-- ====================================================================== -->

## ALWAYS LOADED: Project Identity

- **项目**: Visual PM2 GUI — macOS 状态栏菜单应用，用于可视化管理 PM2 进程
- **技术栈**: SwiftUI (macOS 14.0+) + Node.js (pm2 封装层)
- **构建**: `./build.sh`（首选）或 `xcodebuild build -scheme VisualPM2GUI`
- **运行**: `open build/VisualPM2GUI.app`
- **依赖安装**: `cd scripts && npm install`（首次构建前执行）
- **前置条件**: 接受 Xcode 许可证: `sudo xcodebuild -license`
- **Bundle ID**: `com.douba.pm2-swift`
- **架构支持**: arm64 / x86_64

### 目录结构

```
VisualPM2GUI/
├── Models/           # PM2Project, AppState, AppConfig, PortPool, DesignSystem
├── Services/         # PM2Service (IPC with Node.js)
├── Views/            # StatusBarMenu, ProjectMenuItem, LogsView, SettingsView
└── VisualPM2GUIApp.swift   # 入口点

scripts/
└── pm2_wrapper.js    # Node.js PM2 API 封装 (539 行)

Tests/
└── VisualPM2GUITests/
    └── GroupManagementTests.swift  # 单元测试

.harness/             # Harness Engineering 体系（规则/Agent/技能/变更）
docs/agents/          # Agent 辅助文档（domain/issue-tracker/triage-labels）
.qoder/specs/         # 功能规范
```

### 关键文件速查

| 文件 | 行数 | 用途 |
|------|------|------|
| `VisualPM2GUI/Models/AppState.swift` | 533 | 核心状态管理，ObservableObject |
| `VisualPM2GUI/Services/PM2Service.swift` | 233 | IPC 通信服务 |
| `VisualPM2GUI/Views/StatusBarMenu.swift` | 689 | 主菜单视图 |
| `VisualPM2GUI/Views/ProjectMenuItem.swift` | 165 | 项目行组件 |
| `scripts/pm2_wrapper.js` | 539 | PM2 命令封装 |
| `Tests/VisualPM2GUITests/GroupManagementTests.swift` | 220 | 分组逻辑测试 |

---

<!-- ====================================================================== -->
<!-- PHASE-TRIGGERED — 在对应阶段自动加载                                 -->
<!-- ====================================================================== -->

## PHASE-TRIGGERED: Architecture

在分析、设计或修改架构时加载此节。

### 系统架构

```
┌─────────────────────────────────────────────────┐
│           StatusBarMenu (SwiftUI)               │
│  ┌───────────────────────────────────────────┐  │
│  │  ProjectMenuItem / LogsView / SettingsView │  │
│  └───────────────────────────────────────────┘  │
└──────────────────────┬────────────────────────┘
                       │ Child Process (Process.launchPath)
┌──────────────────────▼────────────────────────┐
│            PM2Service.swift                    │
│  - Runs node with pm2_wrapper.js as child     │
│  - Async/await wrapper for Process calls       │
└──────────────────────┬────────────────────────┘
                       │ PM2 Protocol
┌──────────────────────▼────────────────────────┐
│            pm2_wrapper.js                      │
│  - Connects to PM2 daemon via pm2 npm package │
│  - Commands: list, start, stop, restart,      │
│              delete, logs, flush, save, scan   │
└────────────────────────────────────────────────┘
```

### 设计模式

- **MVVM**: View → AppState (@ObservableObject) → PM2Service → Node.js IPC
- **依赖注入**: 协议型构造函数参数（`PM2ServiceProtocol`）+ 默认实现
- **乐观 UI 更新**: 待处理状态集合（`pendingStarts`/`pendingStops`）提升响应性
- **防抖保存**: 配置保存使用 500ms debounce
- **重试机制**: IPC 命令带指数退避重试（最多 3 次）

### 数据流

```
用户操作 → AppState (async) → PM2Service → pm2_wrapper.js → PM2 daemon
                                                              ↓
用户界面 ← AppState.@Published ← PM2Service ← stdout JSON ←┘
```

---

## PHASE-TRIGGERED: Communication

在实现 IPC 通信或处理 Swift↔Node.js 边界时加载此节。

### Swift → Node.js IPC

`PM2Service` 通过 `Process.launchPath` 生成子进程执行 `node scripts/pm2_wrapper.js <command> [args]`:

- **stdout**: JSON 响应或数据
- **stderr**: 错误 JSON `{"error": "message"}`
- **退出码**: 0 = 成功，非 0 = 失败

### PM2 命令列表

| 命令 | 参数 | 用途 |
|------|------|------|
| `list` | 无 | 获取所有项目列表 |
| `start` | `<name\|config-path>` | 启动项目 |
| `stop` | `<name>` | 停止项目 |
| `restart` | `<name>` | 重启项目 |
| `delete` | `<name>` | 删除项目 |
| `logs` | `<name> [lines]` | 获取日志 |
| `flush` | 无 | 清空日志 |
| `save` | 无 | 保存 PM2 状态 |
| `scan` | 无 | 扫描新项目 |
| `start-app` | `<config-path> <name>` | 从配置文件启动单个应用 |

---

## PHASE-TRIGGERED: Coding

在编写或修改代码时加载此节。

### Swift 编码规范

- **无强制解包**: 使用 `if let` / `guard let`，仅在 main bundle 等确定性安全场景例外
- **命名**: camelCase（变量/函数）, PascalCase（类型）, 私有方法用 `_` 前缀
- **错误处理**: 抛出类型化 `PM2ServiceError`（继承 `LocalizedError`）
- **线程安全**: UI 操作标记 `@MainActor`，PM2Service 使用串行 DispatchQueue
- **MARK 组织**: `// MARK: - Core Data / Published Properties / Actions / Private Methods`
- **修饰符顺序**: 访问控制 → `@`属性 → `override` → `func`/`var`/`let`
- **视图修饰符**: 类型/字体 → 布局 → 颜色 → 帧 → 事件
- **缩进**: 4 空格，K&R 花括号风格
- **注释**: 代码注释用中文解释业务含义

### Node.js 编码规范

- **错误输出**: 所有错误必须输出 `JSON.stringify({ error: message })` 到 stderr
- **全局异常捕获**: `uncaughtException` / `unhandledRejection` 处理程序必须存在
- **PM2 连接管理**: 每次命令后必须调用 `pm2.disconnect()`
- **异步模式**: 复杂命令使用 IIFE async 包装
- **端口匹配**: 模式匹配从最具体到最不具体
- **调试日志**: 使用 `debugLog()` 写入 `/tmp/visual-pm2-wrapper.log`

### COMMIT 格式

```
<type>(<scope>): <description>

Types: fix, feat, docs, chore, refactor
Scopes: pm2-swift, pm2, configs
```

---

## PHASE-TRIGGERED: Review

在执行代码审查时加载此节。

### 质量门禁清单

- [ ] `./build.sh` 编译通过
- [ ] 所有测试通过（Swift 项目中为 `GroupManagementTests`）
- [ ] 无强制解包
- [ ] 类型化错误处理
- [ ] `@MainActor` 标记 UI 操作
- [ ] PM2Service IPC 格式正确（stdout JSON / stderr 错误 JSON）
- [ ] pm2.disconnect() 在所有路径上被调用

### 分离执行与评审

始终遵循下列原则：
1. **编码 Agent** 负责生成代码
2. **评审 Agent** 独立审查代码，重点关注正确性、安全性和规范符合度
3. 评审发现问题 → 返回编码 Agent 修改 → 重新评审（最多 3 轮）

---

<!-- ====================================================================== -->
<!-- ON-DEMAND — 按需加载                                               -->
<!-- ====================================================================== -->

## ON-DEMAND: Domain Context

当需要理解业务逻辑、分组机制或过滤规则时加载。

详见 [CONTEXT.md](./CONTEXT.md) — 包含核心概念、分组机制、错误处理、排序与过滤规则。

## ON-DEMAND: Config Reference

当需要修改配置或理解持久化时加载。

- **配置路径**: `~/Library/Application Support/pm2-swift/config.json`
- **配置格式**: `AppConfig` (Codable) — 包含 UI 偏好、端口池、排序顺序、列宽度
- **用户意图持久化**: `stoppedProjects` 集合记录用户手动停止的项目，启动时自动重新停止
- **PM2 ecosystem**: `/Users/douba/.pm2/ecosystem.config.js`
- **项目扫描目录**: 见 `pm2_wrapper.js` 中的 `PROJECT_DIRS`

## ON-DEMAND: Testing

当需要编写或运行测试时加载。

- **测试框架**: XCTest
- **测试模式**: `@MainActor` 标记测试类，`override func setUp() async throws` 异步初始化
- **Mock 模式**: `MockPM2Service` 实现 `PM2ServiceProtocol`，可配置行为（`shouldThrowOnStart` 等）
- **断言**: `XCTAssertEqual`、`XCTAssertTrue`、`XCTAssertFalse`
- **运行测试**: `xcodebuild test -scheme VisualPM2GUI`

## ON-DEMAND: Agent Docs

- **Issue Tracker**: `.scratch/` 目录下 markdown 文件。详见 [docs/agents/issue-tracker.md](./docs/agents/issue-tracker.md)
- **Triage Labels**: 五个标准角色（needs-triage / needs-info / ready-for-agent / ready-for-human / wontfix）。详见 [docs/agents/triage-labels.md](./docs/agents/triage-labels.md)
- **Domain Docs**: 单上下文布局。详见 [docs/agents/domain.md](./docs/agents/domain.md)
- **Harness Rules / Application Owner**: 见 `.harness/agents/application-owner.md`

## ON-DEMAND: Harness Engineering

参见 `.harness/` 目录：

- `.harness/rules/` — 架构、编码、测试、工作流规则
- `.harness/agents/` — Agent 定义（含 Application Owner 编排中枢）
- `.harness/skills/` — 可复用的开发技能
- `.harness/changes/` — 变更追溯
