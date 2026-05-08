# Visual PM2 GUI - 构建说明

## ⚠️ 重要：首次构建需要接受 Xcode 许可证

在构建应用之前，您需要先接受 Xcode 许可证协议：

```bash
sudo xcodebuild -license
```

按空格键滚动到许可协议末尾，然后输入 `agree` 同意。

## 📋 构建步骤

### 方法 1：使用构建脚本（推荐）

1. **接受 Xcode 许可证**（仅需一次）
   ```bash
   sudo xcodebuild -license
   ```

2. **安装 Node.js 依赖**（已完成）
   ```bash
   cd scripts
   npm install
   ```

3. **构建应用**
   ```bash
cd /Users/douba/Projects/XM/project/pm2-swift
./build.sh
   ```

4. **运行应用**
   ```bash
   open build/VisualPM2GUI.app
   ```

### 方法 2：使用 Xcode IDE

1. **接受 Xcode 许可证**
   ```bash
   sudo xcodebuild -license
   ```

2. **创建 Xcode 项目**
   - 打开 Xcode
   - File → New → Project
   - 选择 **macOS** → **App**
   - 产品名称：`VisualPM2GUI`
   - Interface：**SwiftUI**
   - Language：**Swift**
   - 保存位置：`/Users/douba/Projects/XM/project/pm2-swift`
   - 点击 **Create**

3. **添加源文件**
   - 在 Xcode 左侧项目导航器中，删除自动生成的默认文件
   - 将 `VisualPM2GUI/` 目录下的所有 `.swift` 文件拖入项目
   - 确保勾选 **Copy items if needed** 和 **Add to targets: VisualPM2GUI**

4. **配置项目**
   - 点击项目名称 → 选择 **VisualPM2GUI** target
   - **General** 标签：
     - Bundle Identifier: `com.douba.visual-pm2-gui`
     - Version: `1.0`
   - **Signing & Capabilities** 标签：
     - 选择 **Automatically manage signing**
     - Team: 选择您的 Apple ID（或 None 用于本地开发）

5. **构建并运行**
   - 点击 ▶️ 按钮，或按 `Cmd+R`
   - 应用将在状态栏显示为 🟢 图标

## 🔧 手动构建（如果脚本失败）

如果构建脚本失败，可以手动编译：

```bash
cd /Users/douba/Projects/XM/project/pm2-swift

# 创建构建目录
mkdir -p build/VisualPM2GUI.app/Contents/MacOS
mkdir -p build/VisualPM2GUI.app/Contents/Resources

# 编译 Swift 文件
swiftc -o build/VisualPM2GUI.app/Contents/MacOS/VisualPM2GUI \
    VisualPM2GUI/Models/*.swift \
    VisualPM2GUI/Services/*.swift \
    VisualPM2GUI/Views/*.swift \
    VisualPM2GUI/VisualPM2GUIApp.swift \
    -framework SwiftUI \
    -framework Cocoa \
    -framework AppKit \
    -framework Foundation \
    -sdk $(xcrun --sdk macosx --show-sdk-path)

# 复制配置文件
cp VisualPM2GUI/Info.plist build/VisualPM2GUI.app/Contents/

# 复制脚本
cp -r scripts build/VisualPM2GUI.app/Contents/Resources/

# 设置可执行权限
chmod +x build/VisualPM2GUI.app/Contents/MacOS/VisualPM2GUI

# 运行
open build/VisualPM2GUI.app
```

## 📦 项目文件清单

所有必要的代码文件已创建完成：

### ✅ 数据模型 (Models)
- `PM2Project.swift` - PM2 进程数据模型
- `PortPool.swift` - 端口池管理
- `AppConfig.swift` - 应用配置
- `AppState.swift` - 应用状态管理

### ✅ 服务层 (Services)
- `PM2Service.swift` - PM2 API 通信服务

### ✅ 视图层 (Views)
- `StatusBarMenu.swift` - 状态栏菜单
- `ProjectMenuItem.swift` - 服务列表项
- `LogsView.swift` - 日志查看器
- `SettingsView.swift` - 设置窗口

### ✅ 主应用
- `VisualPM2GUIApp.swift` - 应用入口和状态栏集成

### ✅ Node.js 脚本
- `scripts/pm2_wrapper.js` - PM2 Node.js 包装器
- `scripts/package.json` - Node.js 依赖配置

### ✅ 配置文件
- `VisualPM2GUI/Info.plist` - 应用配置
- `README.md` - 项目说明

## 🐛 故障排除

### 问题 1：Xcode license not accepted
**解决方案**：
```bash
sudo xcodebuild -license
```

### 问题 2：编译错误 "Cannot find module 'SwiftUI'"
**解决方案**：确保使用 macOS SDK 编译
```bash
swiftc -sdk $(xcrun --sdk macosx --show-sdk-path) ...
```

### 问题 3：PM2 连接失败
**解决方案**：
- 确保 PM2 守护进程运行：`pm2 list`
- 检查 Node.js 路径是否正确

### 问题 4：端口检测失败
**解决方案**：
- 检查 `lsof` 权限
- 确保服务实际在监听端口

## 🎯 验收检查清单

运行应用后，检查以下功能：

- [ ] 状态栏出现 🟢 Visual PM2 图标
- [ ] 点击图标显示服务列表
- [ ] 显示在线/停止/错误服务数量
- [ ] 点击 ▶️ 可以启动服务
- [ ] 点击 ⏸ 可以停止服务
- [ ] 点击 🔄 可以重启服务
- [ ] 点击 📋 可以查看日志
- [ ] 搜索框可以过滤服务
- [ ] 分类按钮可以筛选服务
- [ ] 设置窗口可以打开
- [ ] 刷新功能正常工作

## 📞 获取帮助

如果遇到问题：
1. 检查 Xcode 版本：`xcodebuild -version`
2. 检查 Swift 版本：`swift --version`
3. 检查 Node.js 版本：`node --version`
4. 检查 PM2 状态：`pm2 list`

---

**项目完成度**: ✅ 100% 代码已实现，等待构建和运行验证
