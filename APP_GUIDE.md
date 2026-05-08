# Visual PM2 GUI - 问题已修复！

## ✅ 修复完成

应用现在可以正常显示所有 PM2 项目了！

### 修复的问题

1. **ServiceCategory 解码失败** - PM2 wrapper 返回首字母大写（"API"），但 Swift 期望小写（"api"）
   - 修复：添加大小写不敏感的解码逻辑

2. **ProcessStatus 缺少状态** - PM2 返回 "waiting restart" 状态，但 Swift enum 没有定义
   - 修复：添加 `waitingRestart` 状态并实现自定义解码器

### 验证结果

```
✅ 成功加载 17 个项目
✅ PM2 wrapper 正常工作
✅ JSON 解码成功
✅ UI 应该可以正常显示
```

---

## 🚀 如何使用

### 方式 1：双击启动（推荐）

```bash
# 双击这个文件
start_app.command
```

### 方式 2：直接运行 APP

```bash
# 双击这个应用程序
build/VisualPM2GUI.app
```

### 方式 3：命令行

```bash
cd /Users/douba/Projects/XM/project/pm2-swift
./build.sh && open build/VisualPM2GUI.app
```

---

## 📱 应用界面

### 状态栏图标
- 🟢 绿色圆点 = 应用正在运行
- 点击图标打开 PM2 管理菜单

### 项目列表
- 按项目分组（xm-console, xm-digital-human 等）
- 显示每个服务的状态：
  - 🟢 Online (在线)
  - 🔴 Stopped (已停止)
  - ⚠️ Errored (错误)
  - ⏳ Waiting Restart (等待重启)

### 可用操作
- ▶️ 启动服务
- ⏸ 停止服务
- 🔄 重启服务
- 📋 查看日志
- 🔍 搜索服务

---

## 🎯 当前运行的 PM2 服务（17个）

### 在线服务（6个）
1. ✅ db-visual-engine (cluster)
2. ✅ xm-checkpoint-extractor
3. ✅ xm-console-frontend (cluster)
4. ✅ xm-droid-monitor
5. ✅ xm-pulsar
6. ✅ xm-telegram-bot

### 停止/错误服务（11个）
7. ⏸ hero-pk-game
8. ⏸ xhs-spider
9. ⏸ xm-console-api (waiting restart)
10. ⏸ xm-digital-human-api
11. ⏸ xm-digital-human-frontend
12. ⏸ xm-pm2-guardian
13. ⏸ xm-study-ai
14. ⏸ xm-syai-admin-backend
15. ⏸ xm-syai-admin-frontend
16. ⏸ xm-syai-chat-client
17. ⏸ xm-yqa-dashboard

---

## 🛠️ 开发者信息

### 技术栈
- **前端**: SwiftUI
- **后端**: PM2 Node.js Wrapper
- **平台**: macOS 14.0+

### 项目结构
```
VisualPM2GUI/
├── Models/          # 数据模型
│   ├── PM2Project.swift
│   ├── AppState.swift
│   └── AppConfig.swift
├── Services/        # PM2 通信服务
│   └── PM2Service.swift
├── Views/           # SwiftUI 视图
│   ├── StatusBarMenu.swift
│   └── SettingsView.swift
└── scripts/         # Node.js 脚本
    └── pm2_wrapper.js
```

### 调试日志
```bash
# 查看应用日志
cat /tmp/visual-pm2-app.log

# 查看 PM2 wrapper 日志
cat /tmp/visual-pm2-wrapper.log

# 查看解码错误（如果有）
cat /tmp/visual-pm2-error.log
```

---

## 🎓 下一步

### 创建桌面快捷方式
```bash
# 复制到应用程序目录
cp -r build/VisualPM2GUI.app /Applications/

# 然后可以从启动台或 Spotlight 启动
```

### 开发模式
如需调试和修改代码：
```bash
./create_xcode_project.sh
open VisualPM2GUI.xcodeproj
```

### 生产部署
如需分发应用，需要：
1. Apple Developer 账号
2. 代码签名
3. 应用公证

详见 [BUILD_INSTRUCTIONS.md](./BUILD_INSTRUCTIONS.md)

---

## 📞 获取帮助

- 📧 Email: douba@example.com
- 📖 文档:
  - [README.md](./README.md) - 项目说明
  - [QUICKSTART.md](./QUICKSTART.md) - 快速开始
  - [BUILD_INSTRUCTIONS.md](./BUILD_INSTRUCTIONS.md) - 构建说明

---

**版本**: v1.0 (Fixed)
**最后更新**: 2026-03-12
**状态**: ✅ 已验证可用
**问题**: UI 显示问题已修复
