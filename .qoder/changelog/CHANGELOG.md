# Harness Changes

> 此文件记录 AI 驱动的功能变更。每次变更记录上下文、决策和验证结果。

## 格式

```
## [YYYY-MM-DD] 简短标题

- **类型**: feat / fix / refactor / docs / chore
- **影响范围**: 列出修改的文件
- **背景**: 为什么做这个变更
- **决策**: 关键设计决策和取舍
- **验证**: 如何验证变更正确
- **状态**: done / pending / rolled-back
```

---

## 初始设立

- **日期**: 2026-05-09
- **类型**: chore
- **影响范围**:
  - `AGENTS.md` — 重写为三层分层结构
  - `.harness/rules/architecture.md` — 架构规则
  - `.harness/rules/swift-conventions.md` — Swift 编码规范
  - `.harness/rules/node-conventions.md` — Node.js 编码规范
  - `.harness/rules/testing.md` — 测试规范
  - `.harness/rules/workflow.md` — 开发工作流规则
  - `.harness/agents/swift-dev.md` — Swift UI 开发 Agent
  - `.harness/agents/node-dev.md` — Node.js 封装 Agent
  - `.harness/agents/reviewer.md` — 代码评审 Agent
  - `.harness/skills/build-run.md` — 构建运行技能
  - `.harness/skills/add-feature.md` — 添加功能技能
  - `.harness/skills/diagnose.md` — 故障诊断技能
  - `.harness/changes/CHANGELOG.md` — 变更追溯
- **背景**: 基于 Harness Engineering 方法论，将 AI Coding 率提升至 90%+
- **决策**: 采用分层上下文架构（Always Loaded / Phase-triggered / On-demand），分离编码与评审 Agent
- **验证**: 文件结构完整性检查
- **状态**: done

## [2026-05-09] 修复端口列和运行时长列对齐

- **类型**: fix
- **影响范围**:
  - `VisualPM2GUI/Views/ProjectMenuItem.swift` — tableLayout 中两列的对齐修饰符
- **背景**: 端口号和运行时长两列在 tableLayout 模式下未正确右对齐
- **决策**:
  - 移除 `.multilineTextAlignment(.trailing)`——该修饰符控制 Text 内部文本对齐，与 `.frame(alignment: .trailing)` 冗余，两者共存时可能导致 SwiftUI 布局歧义
  - 为运行时长列补充 `.lineLimit(1)`——缺失该修饰符导致与端口列行为不一致
  - 统一使用 `.frame(alignment: .trailing)` 控制列对齐
- **验证**: `./build.sh` 编译通过，无新增警告
- **状态**: done

## [2026-05-09] 新增 Application Owner Agent

- **类型**: feat
- **影响范围**:
  - `.harness/agents/application-owner.md` — 新建 Application Owner Agent 定义
  - `AGENTS.md` — 更新引用指向
- **背景**: 上一轮创建 .harness 体系时遗漏了文章核心的 Application Owner Agent（编排中枢）
- **决策**: Application Owner 作为总负责人，遵循"执行与评判分离"原则，负责需求分析→任务拆解→调度专业 Agent→质量评审→验证追溯的完整闭环，不直接写代码
- **验证**: 文件结构完整性检查
- **状态**: done

## [2026-05-09] 修复非 tableLayout 模式端口和运行时列对齐

- **类型**: fix
- **影响范围**:
  - `VisualPM2GUI/Views/ProjectMenuItem.swift` — 非 tableLayout 分支重构
- **背景**: 截图显示运行时使用中文格式"17 小时 9 分钟 28 秒"，说明实际运行在非 tableLayout 模式。该模式下端口和运行时列无固定宽度和右对齐约束，各行数值起始位置不一致
- **决策**:
  - 移除内层 `HStack(spacing: 8)` 包装，改用外层 HStack 直接布局列
  - 端口列添加 `.frame(width: portColumnWidth, alignment: .trailing)` 固定宽度右对齐
  - 运行时列改用 `uptimeFormattedCompact`（纯 ASCII 等宽），添加 `.frame(width: uptimeColumnWidth, alignment: .trailing)`
  - `Spacer(minLength: 4)` 将列推至右侧，服务名弹性占据左侧空间
- **验证**: `./build.sh` 编译通过，无新增警告
- **状态**: done

## [2026-05-09] 重构 Application Owner Agent 为五模块结构

- **类型**: refactor
- **影响范围**:
  - `.harness/agents/application-owner.md` — 完全重写
- **背景**: 上一版 Application Owner 未按文章的五模块框架组织，缺乏系统性
- **决策**: 按文章框架重组为五个模块：角色与项目背景 → 配置中枢索引 → 七项核心职责 → 工作流程调度指令 → 沟通原则与硬性约束。新增职责 7（知识沉淀），将上下文加载策略纳入调度模块，质量门禁收口到沟通原则
- **验证**: 文件结构完整性检查
- **状态**: done
