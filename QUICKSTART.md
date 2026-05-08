# Visual PM2 GUI - 快速启动指南

> **60 秒上手指南** | 从零到可用的 PM2 可视化管理工具

---

## ⚡ 快速开始

### 前置要求

```bash
# 1. macOS 14.0+ (Sonoma 或更高)
sw_vers

# 2. Xcode 15.0+
xcodebuild -version

# 3. Node.js 18+ (PM2 依赖)
node --version

# 4. PM2 已安装并运行
pm2 list
```

### 3 步启动

#### 步骤 1：安装依赖（30 秒）

```bash
cd /Users/douba/Projects/XM/project/pm2-swift

# 安装 Node.js 依赖（PM2 包装器）
npm install

# 验证 PM2 守护进程运行
pm2 list
```

#### 步骤 2：打开 Xcode 项目（20 秒）

```bash
# 双击打开或命令行打开
open VisualPM2GUI.xcodeproj
```

#### 步骤 3：运行应用（10 秒）

1. 在 Xcode 中点击 **▶️ Run** 按钮（或 `Cmd+R`）
2. 状态栏出现 **🟢 Visual PM2** 图标
3. 点击图标查看所有 PM2 服务状态

---

## 🎯 核心功能演示

### 1. 查看服务状态

```swift
// 状态栏菜单显示：
🟢 12 Online | 🔴 3 Stopped | ⚠️ 1 Errored

// 点击展开查看：
● xm-console-api     (online)   :18920
● xm-console-frontend (online)  :15921
● xm-pulsar          (stopped)
● hero-pk-game       (errored)  :3456
```

### 2. 快速操作

```swift
// 右键点击服务 → 选择操作：
▶️ Start  - 启动已停止的服务
⏸ Stop   - 停止正在运行的服务
🔄 Restart - 重启服务
📋 View Logs - 查看最近日志
🌐 Open URL - 在浏览器打开服务
```

### 3. 端口管理

```swift
// 自动检测端口冲突
⚠️ 端口 18920 已被占用（PID: 12345）
✅ 自动分配可用端口：18921

// 手动分配端口
Settings → Network → 输入端口号 → Apply
```

### 4. 日志查看

```swift
// 实时日志流
Logs → 选择服务 → 查看最近 100 行
[2026-03-08 10:23:45] INFO: Server started on port 18920
[2026-03-08 10:24:12] ERROR: Connection refused
[2026-03-08 10:25:01] INFO: Retrying connection...
```

---

## 🔧 常见问题

### Q1：应用启动后显示 "No PM2 processes found"

**原因**：PM2 守护进程未启动  
**解决**：
```bash
# 启动 PM2 守护进程
pm2 list

# 如果还是不行，重启 PM2
pm2 kill
pm2 resurrect
```

### Q2：端口检测显示错误或为空

**原因**：lsof 权限不足或进程无端口监听  
**解决**：
```bash
# 检查 lsof 权限
/usr/sbin/lsof -nP -iTCP:18920 -sTCP:LISTEN

# 手动刷新端口
状态栏菜单 → 刷新状态
```

### Q3：日志查看器显示空白

**原因**：日志文件路径错误或权限不足  
**解决**：
```bash
# 检查日志文件是否存在
ls -lh ./logs/api-error.log

# 使用 PM2 API 获取日志（推荐）
# 应用会自动使用 pm2 logs 命令而非直接读取文件
```

### Q4：应用无法启动，提示 "Code Sign Error"

**原因**：macOS 安全设置  
**解决**：
```bash
# 1. 打开"系统设置" → "隐私与安全性"
# 2. 找到 "Visual PM2 GUI"，点击 "仍要打开"
# 3. 或右键点击应用 → "打开" → "打开"
```

---

## 🎨 自定义配置

### 修改刷新间隔

```swift
// 默认：5 秒刷新一次
// 修改为：10 秒

Settings → General → 刷新间隔: 10秒
```

### 添加自定义服务分类

```swift
// Models/PM2Project.swift
enum ServiceCategory: String, Codable {
    case api = "API"
    case frontend = "Frontend"
    case bot = "Bot"
    case monitor = "Monitor"
    case game = "Game"
    case database = "Database"  // 新增
    case other = "Other"
}
```

### 配置端口范围

```json
// ~/Library/Application Support/pm2-swift/config.json
{
  "portPool": {
    "apiRange": [18920, 18999],
    "frontendRange": [15920, 15999],
    "databaseRange": [5432, 5499]  // 新增数据库端口范围
  }
}
```

---

## 🚀 开发模式

### 启用调试日志

```swift
// VisualPM2GUIApp.swift
#if DEBUG
let enableLogging = true
#else
let enableLogging = false
#endif

if enableLogging {
    print("[DEBUG] PM2 Service initialized")
}
```

### 热重载（Xcode）

```bash
# Xcode 自动支持 SwiftUI 热重载
# 修改代码后，Cmd+S 保存，UI 自动更新
```

### 测试 PM2 集成

```bash
# 测试 Node.js 包装器
node scripts/pm2_wrapper.js list

# 应该返回 JSON 格式的服务列表
[
  {
    "id": "xm-console-api",
    "name": "xm-console-api",
    "status": "online",
    ...
  }
]
```

---

## 📊 性能优化建议

### 大量服务（100+）

```swift
// 启用分页加载
AppState.swift
let pageSize = 20
@Published var currentPage = 0

// 启用懒加载
LazyVStack {
    ForEach(paginatedProjects) { project in
        ProjectMenuItem(project: project)
    }
}
```

### 节能模式

```swift
// 降低刷新频率
Settings → General → 刷新间隔: 30秒

// 关闭自动刷新
Settings → General → 自动刷新: OFF
```

---

## 🎓 下一步

### 学习资源

- 📖 [完整实现方案](./IMPLEMENTATION_PLAN.md)
- 🎨 [UI 设计规范](./docs/UI_GUIDELINES.md)
- 🔧 [API 文档](./docs/API.md)

### 进阶功能

- 🔮 **端口自动分配**：Settings → Network → Auto Port Allocation
- 🔮 **批量操作**：按住 Cmd 键多选服务 → 右键 → Batch Start
- 🔮 **配置导出**：File → Export Configuration → 保存为 JSON

### 参与贡献

```bash
# 1. Fork 项目
# 2. 创建功能分支
git checkout -b feature/my-feature

# 3. 提交更改
git commit -m "Add: 我的新功能"

# 4. 推送分支
git push origin feature/my-feature

# 5. 创建 Pull Request
```

---

## 📞 获取帮助

- 📧 Email: douba@example.com
- 🐛 Issues: [GitHub Issues](https://github.com/douba/visual-pm2-gui/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/douba/visual-pm2-gui/discussions)

---

**快速启动指南版本**: v1.0  
**最后更新**: 2026-03-08  
**状态**: ✅ 已验证

> 💡 **提示**: 首次运行建议花 5 分钟阅读 [完整实现方案](./IMPLEMENTATION_PLAN.md)，了解项目架构和设计思路。
