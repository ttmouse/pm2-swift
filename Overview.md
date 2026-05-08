# Visual PM2 GUI for Subform XM

目标: 在本地以可视化方式管理多个子项目，快速查看启动/暂停/重启状态，确保每个项目拥有独立端口并可查看日志。

架构选项（优先 MVP）：
- 原生 macOS 状态栏应用（SwiftUI），通过 PM2 CLI 或 Node API 调用实现列表与控制。
- 备选：Electron/Tauri 跨平台桌面应用，方便快速迭代但体积较大。

MVP 实现路线:
1) 读取本地已配置的项目来源（如 ecosystem.config.js、pm2 jlist），聚合为 Projects 清单。
2) 提供 Start/Stop/Restart 操作，以及“分配端口”、“导出/导入配置”等基本功能。
3) 自动端口分配与冲突检测，确保没有重复监听端口。
4) 日志查看入口（可选：按项目查看最近日志）。
5) 本地数据持久化（JSON/SQLite），以便重启后保留设置。

数据模型（草案）：
- Project: { id, name, path, port, status, pid, startCmd, stopCmd, restartCmd, env, portHint }
- AppState: { projects: Project[], portPool: { start, end, used } }

关键挑战与对策:
- 端口冲突检测、进程崩溃时的自愈策略
- 沙盒/签名与权限问题（初期以轻量本地应用形式落地，后续再考虑打包与签名）
- 多设备/云端同步场景的扩展性

里程碑建议:
- 1 周内：实现状态栏 UI 框架、PM2 列表读取、三键控制
- 2-3 周：端口分配、日志查看、导入导出
- 4 周：完整打包、签名、基本的日志检索与搜索
