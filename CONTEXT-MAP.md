# Context Map

## How to choose context by task type

### Bug fix (排序/分组/过滤/显示错误)

Read in order:
1. `CONTEXT.md` — 理解分组/过滤/排序的规则定义
2. `VisualPM2GUI/Models/AppState.swift` — 定位问题函数
3. `.harness/task-workflow.md` 步骤 3-5

Verify: `.harness/testing-and-verification.md` → Bug fix 节

### UI 改动 (Views/)

Read:
- `.harness/task-workflow.md` 步骤 3-6
- `.harness/working-boundaries.md` → Architecture Boundaries

Verify: `.harness/testing-and-verification.md` → UI 改动节

### IPC / Service 层改动 (PM2Service / pm2_wrapper.js)

Read:
- `.harness/working-boundaries.md` → Architecture Boundaries → IPC 边界
- `.harness/testing-and-verification.md` → IPC 改动节
- `VisualPM2GUI/Services/PM2Service.swift` — 理解 IPC 协议

Verify: stdout JSON 校验 + stderr 错误 JSON 校验

### 配置/持久化改动

Read:
- `VisualPM2GUI/Models/AppState.swift` — ConfigPersistence 使用位置
- `.harness/working-boundaries.md` → ConfigPersistence 风险

### 重构 (Refactor)

Read:
- `.harness/task-workflow.md` → Refactor 步骤
- `.harness/working-boundaries.md` → Architecture Boundaries
- `docs/agents/domain.md` → 术语一致性

Verify: `.harness/testing-and-verification.md` → Refactor 节

---

## All tasks: before starting

Always read before any code change:
1. `AGENTS.md` — 项目目标和核心约束
2. `.harness/working-boundaries.md` — 边界和风险区域
3. `.harness/task-workflow.md` — 步骤 1-2

Always read after implementation:
4. `.harness/commands.md` — 验证命令
5. `.harness/testing-and-verification.md` — 按任务类型的验收标准
6. `.harness/code-review.md` — 自查清单
