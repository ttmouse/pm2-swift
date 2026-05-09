# Task Workflow

所有开发任务按以下流程执行。

## 步骤 1：任务分类

确定任务类型：

| 类型 | 示例 |
|------|------|
| **bug-fix** | 某个项目状态显示错误、日志不更新 |
| **feature** | 新增端口扫描、添加批量操作 |
| **refactor** | 重命名、提取公共逻辑、协议拆分 |
| **testing** | 补充测试、修复测试 |
| **docs** | 更新文档、注释 |

## 步骤 2：需求复述

用自己的话复述任务目标，明确：
- 要解决什么问题 / 要做什么
- 不做什么（范围边界）

## 步骤 3：受影响模块识别

```
UI (StatusBarMenu / ProjectMenuItem / LogsView / SettingsView)
  → 状态 (AppState: ObservableObject)
    → 服务 (PM2ServiceProtocol)
      → IPC (pm2_wrapper.js)
```

逐个排查任务涉及哪些层。跨层变更需要设计阶段。

## 步骤 4：上下文选择

根据任务类型读取对应上下文：

| 阶段 | 必读 |
|------|------|
| 架构分析 | `.harness/working-boundaries.md`（Architecture Boundaries 节） |
| Swift 编码 | `docs/agents/swift-conventions.md` |
| Node.js 编码 | `docs/agents/node-conventions.md` |
| 测试 | `.harness/testing-and-verification.md` |
| 代码自审 | `.harness/code-review.md` |

## 步骤 5：实施计划

写出具体的修改步骤，确认：
- 先读再改（理解现有代码再动）
- 最小修改（只改必要部分）
- 不改未要求的功能

## 步骤 6：最小修改

编码约束：
- 一次只做一件事
- 不添加未要求的抽象层、配置项、错误处理
- 不破坏现有测试
- 关键逻辑添加中文注释

## 步骤 7：测试验证

```
./build.sh                        # 编译
xcodebuild test                   # 全部测试通过
手动验证功能表现                    # 冒烟测试
```

## 步骤 8：结果报告

输出格式：

```md
## 改了什么
- [文件1]: 变更说明
- [文件2]: 变更说明

## 为什么这样改
简要说明根因或设计选择

## 验证记录
- [x] 编译通过
- [x] 全部测试通过
- [x] 手动验证通过

## 剩余风险
- 如果有未覆盖的场景，说明
```

## 步骤 9：风险说明

- 是否涉及 High-risk areas（见 `working-boundaries.md`）
- 是否需要人工验收
- 是否存在已知问题（见 `known-risks.md`）

## 步骤 10：变更追溯

每次 AI 驱动的功能变更必须在 `.qoder/changelog/CHANGELOG.md` 中记录，格式：

```markdown
## [日期]

### 新增 / 修复 / 变更
- 描述（关联文件列表）
- 决策记录、取舍说明
```
