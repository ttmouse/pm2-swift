# Diagnose 技能

## 目的

结构化的故障诊断流程，用于定位和修复 pm2-swift 中的问题。

## 诊断流程

### 1. 问题确认

确定问题类型：

| 类型 | 表现 | 排查方向 |
|------|------|----------|
| 编译错误 | `./build.sh` 失败 | Swift 语法、文件引用、依赖 |
| 启动崩溃 | 应用闪退 | Info.plist、资源路径、子进程 |
| IPC 失败 | PM2 命令不返回 | pm2_wrapper.js 逻辑、Node 环境 |
| 状态异常 | 项目列表不对 | AppState 逻辑、分组/排序 |
| UI 异常 | 显示错乱 | SwiftUI 布局、绑定 |

### 2. 日志收集

```bash
# PM2 wrapper 日志
cat /tmp/visual-pm2-wrapper.log

# 构建日志
./build.sh 2>&1

# PM2 本身状态
pm2 list
pm2 logs --lines 50
```

### 3. Root Cause 定位

**IPC 失败排查路径**:
```
PM2Service.executePM2Command()
  → 检查 nodePath 是否存在 (/usr/local/bin/node)
  → 检查 scriptPath 是否存在 (scripts/pm2_wrapper.js)
  → 检查 stderr 输出 (JSON 格式错误)
  → 检查退出码
```

**状态异常排查路径**:
```
AppState.refresh()
  → PM2Service.fetchProjects()
    → pm2_wrapper.js list 命令
      → PM2 daemon 响应
    → JSON 解析
  → filterProjects()
  → applySort()
  → groupProjects()
```

### 4. 修复实施

- 创建最小复现环境
- 一次只改一个变量
- 修复后运行完整构建 + 测试
- 更新 `.harness/changes/CHANGELOG.md` 记录根因
