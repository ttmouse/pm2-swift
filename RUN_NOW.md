# 🚀 立即运行 Visual PM2 GUI

## ⚠️ 第一步：接受 Xcode 许可证（必须）

在终端执行以下命令：

```bash
sudo xcodebuild -license
```

**操作步骤**：
1. 按空格键快速滚动到许可协议末尾
2. 输入 `agree` 并按回车
3. 输入您的 macOS 密码

---

## 🔨 第二步：构建应用

```bash
cd /Users/douba/Projects/XM/project/pm2-swift
./build.sh
```

**预期输出**：
```
🔨 Building Visual PM2 GUI...

📝 Compiling Swift files...
✅ Compilation successful!
✅ Build complete!
📦 App location: /Users/douba/Projects/XM/project/pm2-swift/build/VisualPM2GUI.app
```

---

## ▶️ 第三步：运行应用

```bash
open build/VisualPM2GUI.app
```

**或者在 Finder 中**：
1. 打开 `/Users/douba/Projects/XM/project/pm2-swift/build/`
2. 双击 `VisualPM2GUI.app`

---

## ✅ 验收检查

应用启动后，您应该看到：

1. **状态栏图标**：顶部菜单栏右侧出现 🟢 绿色圆点
2. **服务列表**：点击图标显示您的 PM2 服务
3. **状态概览**：
   - 🟢 X Online（在线服务数）
   - 🔴 X Stopped（停止服务数）
   - ⚠️ X Errored（错误服务数）

---

## 🎮 测试功能

### 基础操作
- [ ] 点击 ▶️ 启动一个停止的服务
- [ ] 点击 ⏸ 停止一个在线的服务
- [ ] 点击 🔄 重启一个服务
- [ ] 点击 📋 查看服务日志

### 搜索和筛选
- [ ] 在搜索框输入服务名称，列表实时过滤
- [ ] 点击分类按钮（API、Frontend 等），筛选服务

### 设置
- [ ] 点击 "设置..." 打开设置窗口
- [ ] 修改刷新间隔
- [ ] 开启/关闭通知

---

## 🐛 如果遇到问题

### 问题：应用无法打开

**解决方案**：
```bash
# 检查可执行文件是否存在
ls -la build/VisualPM2GUI.app/Contents/MacOS/

# 如果不存在，重新构建
./build.sh
```

### 问题：编译失败

**解决方案**：
```bash
# 确认已接受 Xcode 许可证
sudo xcodebuild -license

# 确认 Swift 编译器可用
swiftc --version

# 清理并重新构建
rm -rf build
./build.sh
```

### 问题：PM2 连接失败

**解决方案**：
```bash
# 检查 PM2 守护进程
pm2 list

# 如果没有服务，启动一个测试服务
pm2 start echo "test" --name test-app
```

---

## 📞 快速帮助

如遇到任何问题，请检查：

1. **Xcode 版本**：`xcodebuild -version`（需要 15.0+）
2. **Swift 版本**：`swift --version`（需要 5.0+）
3. **Node.js 版本**：`node --version`（需要 18+）
4. **PM2 状态**：`pm2 list`

---

**准备好了吗？开始运行吧！** 🚀

```bash
# 一键执行（复制粘贴）
sudo xcodebuild -license && \
cd /Users/douba/Projects/XM/project/pm2-swift && \
./build.sh && \
open build/VisualPM2GUI.app
```
