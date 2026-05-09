# UNKNOWN / TODO Items

以下为生成过程中无法确认、等待人工补充的内容。

## UNKNOWN（命令不可用）

| 命令 | 说明 |
|------|------|
| `lint` | 项目未配置 lint 工具（无 .swiftlint.yml、.eslintrc 等） |
| `typecheck` | 项目未配置类型检查命令 |
| `integration test` | 项目无集成测试 |
| `e2e test` | 项目无端到端测试 |

## TODO（需人工补充）

| 位置 | 说明 |
|------|------|
| `docs/adr/0001-template.md` | 仅有模板，无真实架构决策记录。需补充已有决策：MVVM 选型、PM2 IPC 方案、乐观 UI 更新等 |
| `docs/adr/` | 新增架构决策时在此创建新文件 |
| `CONTEXT.md` | 缺少"主要用户/角色"描述（如：开发者本地使用，非多用户系统） |
| `CONTEXT.md` | 缺少"常见修改场景"章节（列出最常改的文件和对应场景） |
| `.harness/known-risks.md` | 可补充更多项目特有问题 |
| `.harness/failure-analysis.md` | 尚未有实际失败记录，首次出错后需填入模板 |
