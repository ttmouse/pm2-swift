# Visual PM2 GUI - 使用指南

## 🎯 如何将项目变成可点击运行的 APP

项目已成功编译为 macOS 原生应用程序，提供以下 3 种启动方式：

---

## 方式 1：双击启动（最简单）

✅ **推荐方式** - 双击 `start_app.command` 文件即可启动

```
📂 /Users/douba/Projects/XM/project/pm2-swift/start_app.command
```

**特点**：
- ✅ 一键启动，无需命令行
- ✅ 自动检测并构建（如果需要）
- ✅ 友好的提示信息

---

## 方式 2：直接运行 APP（最快）

如果已经构建完成，可以直接双击 APP 文件：

```
📂 /Users/douba/Projects/XM/project/pm2-swift/build/VisualPM2GUI.app
```

**特点**：
- ✅ 双击即可运行
- ✅ 可以拖到 Dock 或桌面快捷方式
- ✅ 标准 macOS 应用体验

---

## 方式 3：命令行启动（开发用）

```bash
cd /Users/douba/Projects/XM/project/pm2-swift
./build.sh          # 构建（如果需要）
open build/VisualPM2GUI.app  # 运行
```

---

## 🔧 创建桌面快捷方式

### 方法 1：创建别名

1. 右键点击 `VisualPM2GUI.app`
2. 选择"制作别名"
3. 将别名拖到桌面

### 方法 2：复制到应用程序目录

```bash
cp -r build/VisualPM2GUI.app /Applications/
```

然后可以从启动台或 Spotlight 启动。

---

## 📋 应用功能

### 状态栏集成
- ✅ 应用在状态栏显示为 🟢 图标
- ✅ 点击图标显示 PM2 服务列表
- ✅ 显示在线/停止/错误服务数量

### 服务管理
- ▶️ 启动服务
- ⏸ 停止服务
- 🔄 重启服务
- 📋 查看日志
- 🌐 打开 URL

### 高级功能
- 🔍 服务搜索
- 📊 分类筛选
- ⚙️ 设置面板
- 🔄 自动刷新

---

## 🛠️ 重新构建

如果修改了代码，需要重新构建：

```bash
cd /Users/douba/Projects/XM/project/pm2-swift
./build.sh
```

构建完成后，APP 文件会自动更新。

---

## 🐛 故障排除

### 问题 1：应用启动后无反应

**原因**：PM2 守护进程未运行

**解决**：
```bash
pm2 list
```

### 问题 2：提示"无法打开应用"

**原因**：macOS 安全设置

**解决**：
1. 右键点击应用 →"打开"
2. 或在"系统设置"→"隐私与安全性"中允许

### 问题 3：端口检测失败

**解决**：
- 检查 lsof 权限
- 确保服务实际在监听端口

---

## 📊 系统要求

- ✅ macOS 14.0+ (Sonoma 或更高)
- ✅ Xcode 15.0+ (仅构建时需要)
- ✅ Node.js 18+ (运行时需要)
- ✅ PM2 已安装并运行

---

## 🎓 下一步

### 开发模式
如需调试和修改代码，推荐使用 Xcode：

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
- 📖 文档: [README.md](./README.md)
- 🔧 构建: [BUILD_INSTRUCTIONS.md](./BUILD_INSTRUCTIONS.md)

---

**版本**: v1.0
**最后更新**: 2026-03-12
**状态**: ✅ 已验证可用
