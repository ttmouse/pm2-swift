# Harness Self-Test Report

> 模拟三类任务，验证 Harness 结构是否可引导 Agent 正确执行。

---

## Simulated Task 1: Bug fix

**场景**: 某个已停止的项目在列表里仍然显示绿色状态图标。

**Agent 读上下文路径**:

```
AGENTS.md ("先读什么" → 任何代码修改)
  → .harness/working-boundaries.md (确认允许修改 UI)
  → .harness/task-workflow.md (步骤 4 → .qoder/rules/architecture.md → 定位 Views/)
  → .harness/testing-and-verification.md (bug fix 验证要求)
  → .harness/code-review.md (自审)
```

**能否找到入口**: ✅ AGENTS.md 的"先读什么"表直接命中
**能否选择正确上下文**: ✅ "任何代码修改" → working-boundaries + task-workflow
**能否知道哪些模块可改**: ✅ working-boundaries 列出 Allowed without approval
**能否知道不能碰哪**: ✅ Forbidden 和 High-risk areas
**能否知道跑什么命令**: ✅ commands.md 有快速验证命令
**能否输出验证报告**: ✅ task-workflow.md 步骤 8 规定格式

---

## Simulated Task 2: 新增功能

**场景**: 为设置页面添加"开机自启"开关。

**Agent 读上下文路径**:

```
AGENTS.md ("先读什么" → 任何代码修改)
  → .harness/task-workflow.md (9 步流程)
  → .harness/working-boundaries.md (需要 approval: 新增文件)
  → .qoder/rules/swift-conventions.md (编码规范，已自动加载)
  → .qoder/rules/architecture.md (AppState 状态管理规则，已自动加载)
  → .harness/testing-and-verification.md (UI 改动验证)
  → .harness/code-review.md (自审)
```

**能否找到入口**: ✅
**能否选择正确上下文**: ✅
**能否知道哪些模块可改**: ✅ working-boundaries 标识新增文件需要 approval
**能否知道不能碰哪**: ✅
**能否知道跑什么命令**: ✅
**能否输出验证报告**: ✅

---

## Simulated Task 3: IPC 协议修改

**场景**: PM2 返回格式变更，需要在 pm2_wrapper.js 和 Swift 端同步修改。

**Agent 读上下文路径**:

```
AGENTS.md ("先读什么" → 任何代码修改)
  → .harness/working-boundaries.md (高亮 High-risk: PM2Service.swift IPC)
  → .harness/task-workflow.md
  → .qoder/rules/node-conventions.md (IPC 契约，已自动加载)
  → .qoder/rules/architecture.md (IPC 通信协议，已自动加载)
  → .harness/testing-and-verification.md (IPC 改动验证要求)
  → .harness/code-review.md (重点检查 Safety 和 Architecture)
```

**能否知道这是高风险**: ✅ working-boundaries High-risk areas 表明确标注 PM2Service IPC
**能否知道验证要求**: ✅ testing-and-verification.md IPC 改动有完整 checklist
**能否知道不能碰哪**: ✅ "禁止修改输出格式而不更新 Swift 端"

---

## 检查结论

| 检查项 | 结果 |
|--------|------|
| Agent 是否知道项目是干什么的 | ✅ AGENTS.md 第一行 |
| 不同任务该读哪些上下文 | ✅ AGENTS.md "先读什么"表 |
| 从哪里开始看代码 | ✅ AGENTS.md 目录导航 + 关键文件速查 |
| 哪些目录文件不能乱改 | ✅ working-boundaries.md |
| 改完后跑什么命令 | ✅ commands.md |
| 不同类型任务的验收标准 | ✅ testing-and-verification.md |
| 失败后如何复盘并沉淀规则 | ✅ failure-analysis.md |
| 是否区分热/温/冷上下文 | ✅ AGENTS.md(热) → 先读表(温) → adr/known-risks(冷) |
| 是否避免把所有内容塞进一个文件 | ✅ 拆为 7 个独立文件 |
| 是否编造不存在的信息 | ✅ UNKNOWN 已标注，ADR 为模板 |

## 剩余差距

- `docs/adr/` 仅有模板，无真实架构决策记录
- 未验证真实 PM2 命令（dry run 无法触发实际 PM2 daemon）
- CONTEXT.md 缺少"常见修改场景"和"主要用户/角色"章节
