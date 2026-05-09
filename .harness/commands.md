# Commands

> 所有命令均从项目真实文件中提取。无法确认的命令标注 `UNKNOWN`。

## 构建

| 命令 | 用途 | 备注 |
|------|------|------|
| `./build.sh` | 编译并打包 .app | 首选方式，自动处理签名 |
| `xcodebuild build -scheme VisualPM2GUI` | Xcode 编译 | 备选方式 |
| `open build/VisualPM2GUI.app` | 运行已编译的 app | — |

## 本地启动

| 命令 | 用途 |
|------|------|
| `open build/VisualPM2GUI.app` | 启动已编译的应用 |
| `./build.sh && open build/VisualPM2GUI.app` | 编译后立即启动 |

## 测试

| 命令 | 用途 |
|------|------|
| `xcodebuild test -scheme VisualPM2GUI -destination 'platform=macOS'` | 完整测试 |
| `xcodebuild test -scheme VisualPM2GUI -only-testing:VisualPM2GUITests/GroupManagementTests` | 单文件测试 |

## 小改动快速验证

```
./build.sh                                   # 编译检查
xcodebuild test -scheme VisualPM2GUI         # 测试检查
```

## PR 前完整验证

```
./build.sh                                   # 编译
xcodebuild test -scheme VisualPM2GUI         # 全部测试
open build/VisualPM2GUI.app                  # 手动冒烟
```

## 依赖

| 命令 | 用途 |
|------|------|
| `cd scripts && npm install` | 安装 Node.js 依赖（首次构建前必须执行） |

## 调试

| 命令 | 用途 |
|------|------|
| `tail -f /tmp/visual-pm2-wrapper.log` | 实时查看 PM2 wrapper 调试日志 |

## 未确认的命令

下列命令在项目中未找到对应配置，标记为 `UNKNOWN`：

- **lint**: `UNKNOWN` — 项目未配置 lint 工具
- **typecheck**: `UNKNOWN` — 项目未配置 typecheck
- **integration test**: `UNKNOWN` — 项目无集成测试
- **e2e test**: `UNKNOWN` — 项目无端到端测试

## 已知命令问题

- **Apple Silicon**: PM2 启动 Vite 等 Node.js 进程时可能因架构不匹配报 `esbuild spawn` 错误（Error -88），需显式指定 arm64 Node 路径。
- **Xcode 许可证**: 首次构建前执行 `sudo xcodebuild -license` 接受许可证。
