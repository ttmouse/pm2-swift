# Known Risks

## 测试覆盖不足

仅有 `GroupManagementTests.swift` 一个测试文件，覆盖范围：
- ✅ 分组启动/停止逻辑
- ❌ 项目单操作（start/stop/restart/delete）
- ❌ 过滤逻辑
- ❌ 排序逻辑
- ❌ 配置持久化
- ❌ IPC 错误处理
- ❌ UI 层

## 平台兼容

- **Apple Silicon (arm64)**: PM2 启动 Node.js 进程时可能因架构不匹配出现 `esbuild spawn` 错误（Error -88），需显式指定 arm64 Node 路径。
- **仅 macOS 14.0+**: SwiftUI 特性依赖新版本 API。

## 端口检测

`extractPortFromArgs()` 的端口模式匹配覆盖常见框架（uvicorn/http.server/serve/Streamlit），但不覆盖所有可能。新增框架需补充匹配规则。

## PM2 连接泄漏

`pm2_wrapper.js` 中所有路径必须调用 `pm2.disconnect()`。已在规则中强调，但手动修改此文件时容易遗漏。

## 技术债务

- AppState 约 530 行，承担了 ViewModel + 业务编排双重职责，可能需按模块拆分。
- 错误通知仅通过 `AppState.error` 传递，无持久化错误日志。
