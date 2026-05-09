# Build & Run 技能

## 目的

标准化的构建、运行和验证流程。

## 构建

```bash
# 方式 1: 脚本构建（推荐）
./build.sh

# 方式 2: Xcode 构建
xcodebuild build -scheme VisualPM2GUI
```

## 运行

```bash
# 方式 1: 通过 Finder
open build/VisualPM2GUI.app

# 方式 2: 命令行直接启动
build/VisualPM2GUI.app/Contents/MacOS/VisualPM2GUI
```

## 验证

```bash
# 1. 编译检查
./build.sh

# 2. 测试
xcodebuild test -scheme VisualPM2GUI -destination 'platform=macOS'

# 3. 依赖检查
cd scripts && npm ls pm2
```

## 常见问题

| 症状 | 原因 | 解决 |
|------|------|------|
| `pm2: command not found` | Node 依赖未安装 | `cd scripts && npm install` |
| 编译时找不到符号 | Swift 文件列表过期 | 检查 `build.sh` 中的 `SWIFT_FILES` |
| 运行时崩溃（SIGABRT） | Info.plist 缺失或格式错误 | 检查 `Info.plist` 是否存在 |
| PM2 连接失败 | PM2 daemon 未启动 | 运行 `pm2 ping` 检查 |
