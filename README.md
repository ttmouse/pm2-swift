# Visual PM2 GUI

> 可视化 PM2 进程管理工具 - macOS 状态栏应用

## 功能特性

- ✅ 实时查看 PM2 服务状态
- ✅ 快速启动/停止/重启服务
- ✅ 自动端口检测
- ✅ 日志快速查看
- ✅ 服务分类和搜索
- ✅ 批量操作
- ✅ macOS 原生体验

## 快速开始

### 1. 安装依赖

```bash
cd /Users/douba/Projects/XM/project/pm2-swift/scripts
npm install
```

### 2. 打开 Xcode 项目

```bash
cd /Users/douba/Projects/XM/project/pm2-swift
open VisualPM2GUI.xcodeproj
```

### 3. 运行应用

点击 Xcode 的 ▶️ 按钮，或按 `Cmd+R`

## 系统要求

- macOS 14.0+ (Sonoma 或更高)
- Xcode 15.0+
- Node.js 18+
- PM2 已安装并运行

## 项目结构

```
pm2-swift/
├── VisualPM2GUI/           # Xcode 项目
│   ├── Models/             # 数据模型
│   │   ├── PM2Project.swift
│   │   ├── PortPool.swift
│   │   ├── AppState.swift
│   │   └── AppConfig.swift
│   ├── Services/           # 服务层
│   │   └── PM2Service.swift
│   ├── Views/              # UI 视图
│   │   ├── StatusBarMenu.swift
│   │   ├── ProjectMenuItem.swift
│   │   ├── LogsView.swift
│   │   └── SettingsView.swift
│   ├── Resources/          # 资源文件
│   ├── VisualPM2GUIApp.swift
│   └── Info.plist
├── scripts/                # Node.js 脚本
│   ├── pm2_wrapper.js      # PM2 包装器
│   └── package.json
└── README.md
```

## 使用说明

### 状态栏菜单

- 点击状态栏的 🟢 图标打开菜单
- 查看所有 PM2 服务的状态
- 使用搜索框快速查找服务
- 通过分类按钮筛选服务

### 服务操作

- ▶️ 启动服务
- ⏸ 停止服务
- 🔄 重启服务
- 📋 查看日志
- 🌐 打开 URL

### 设置

- **常规**: 自动刷新、通知、显示模式
- **网络**: 端口范围配置
- **关于**: 版本信息

## 开发

### 构建 Release 版本

1. 选择 "Any macOS Device (arm64)" 或 "Any macOS Device (x86_64)"
2. Product → Archive
3. 右键 Archive → Distribute App
4. 选择 "Copy" (不签名) 或 "Developer ID" (签名)

### 代码签名

如果需要发布，需要:

1. Apple Developer 账号
2. 创建 Developer ID 应用证书
3. 在 Xcode 中配置签名
4. 公证应用 (macOS 10.15+)

## 常见问题

### Q: 应用启动后显示 "No PM2 processes found"

A: 确保 PM2 守护进程正在运行:
```bash
pm2 list
```

### Q: 端口检测显示错误或为空

A: 检查 lsof 权限，或手动刷新状态

### Q: 日志查看器显示空白

A: 检查日志文件路径和权限

## 技术栈

- **前端**: SwiftUI
- **后端**: PM2 Node API
- **通信**: Node.js 子进程
- **存储**: UserDefaults / Core Data

## 许可证

MIT License

## 作者

豆爸 (douba)

## 更新日志

### v1.0.0 (2026-03-08)
- ✨ 初始版本
- ✅ 基础功能完成
- ✅ 状态栏应用
- ✅ 服务管理
- ✅ 日志查看
