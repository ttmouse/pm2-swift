# Visual PM2 GUI - 完整实现方案

> **版本**: v1.0  
> **创建时间**: 2026-03-08  
> **项目**: pm2-swift
> **路径**: `/Users/douba/Projects/XM/project/pm2-swift`

---

## 📊 项目背景

### 现有 PM2 管理痛点
基于豆爸的 XM 项目现状分析（参考记忆 `7115f4ad`）：

1. **服务数量增长**：当前已有 16 个 PM2 服务，管理复杂度增加
2. **端口分配冲突**：手动分配端口容易冲突（API: 18xxx, 前端: 15xxx）
3. **日志查看不便**：需要 SSH 到服务器或使用命令行查看日志
4. **状态监控缺失**：无法实时看到服务健康状态（CPU、内存）
5. **批量操作困难**：重启多个服务需要逐个执行命令
6. **配置分散**：`config/pm2.config.js` + `pm2-interactive.sh` 配置分散

### 现有管理工具参考
- **pm2-interactive.sh**：已实现端口探测、服务列表、URL 列表
- **PM2 CLI**：`pm2 list`, `pm2 logs`, `pm2 restart`
- **PM2 Guardian**：自动巡检和自愈（每 60 秒）

---

## 🎯 核心目标

### MVP 范围（1-2 周）
1. ✅ **状态栏应用**：macOS 原生 SwiftUI 应用，常驻状态栏
2. ✅ **项目列表**：显示所有 PM2 服务状态（在线/离线/错误）
3. ✅ **三键控制**：Start/Stop/Restart 每个服务
4. ✅ **端口管理**：自动检测端口占用，防止冲突
5. ✅ **日志查看**：快速查看最近日志（按项目）

### Phase 2（3-4 周）
- 🔮 **端口自动分配**：新服务自动分配可用端口
- 🔮 **配置导入/导出**：JSON 格式的项目管理配置
- 🔮 **批量操作**：一键启动/停止所有开发环境服务
- 🔮 **健康监控**：CPU/内存使用率图表
- 🔮 **通知集成**：服务崩溃时 macOS 通知

### Phase 3（长期）
- 🔮 **跨设备同步**：配置云端同步
- 🔮 **Web 管理界面**：远程管理 PM2
- 🔮 **Docker 支持**：容器化服务管理

---

## 🏗️ 技术架构

### 技术栈选择

#### 前端框架：**SwiftUI + macOS App**
**优势**：
- ✅ 原生 macOS 体验，性能最佳
- ✅ 状态栏应用（NSStatusItem）天然支持
- ✅ 无需 Electron/Tauri 的庞大体积
- ✅ 系统权限管理简单
- ✅ 可以调用 Node.js 子进程与 PM2 通信

**劣势**：
- ❌ 仅支持 macOS（如需跨平台可后续考虑 Tauri）

#### 后端集成：**PM2 Node API**
```javascript
// PM2 API 调用示例
const pm2 = require('pm2');

pm2.connect((err) => {
  if (err) console.error(err);
  pm2.list((err, list) => {
    console.log(list); // 获取所有进程状态
  });
  pm2.restart('xm-console-api', (err) => {
    // 重启服务
  });
});
```

#### 数据持久化：**Core Data / SQLite**
- 本地配置存储：`~/Library/Application Support/pm2-swift/`
- 端口池管理、项目元数据、用户偏好

### 架构图

```
┌─────────────────────────────────────────────────────────┐
│                   macOS 状态栏                          │
│  🟢 Visual PM2  [xm-console-api ●] [xm-pulsar ●]        │
└───────────────────────────┬─────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            │   SwiftUI 状态栏菜单           │
            │   - 服务列表（状态 + 名称）     │
            │   - 快速操作（Start/Stop）      │
            │   - 端口显示                   │
            └───────────────┬───────────────┘
                            │
            ┌───────────────┴───────────────┐
            │   PM2Service (Swift)          │
            │   - PM2 Node.js 通信           │
            │   - 端口检测 (lsof)            │
            │   - 日志读取                   │
            └───────────────┬───────────────┘
                            │
            ┌───────────────┴───────────────┐
            │   Node.js 子进程               │
            │   - pm2.list()                │
            │   - pm2.restart()             │
            │   - pm2.logs()                │
            └───────────────┬───────────────┘
                            │
            ┌───────────────┴───────────────┐
            │   PM2 Daemon                  │
            │   - 实际的进程管理             │
            └───────────────────────────────┘
```

---

## 📦 数据模型

### 1. Project（服务模型）
```swift
struct PM2Project: Identifiable, Codable {
    let id: String              // PM2 进程名称（如 "xm-console-api"）
    let name: String            // 显示名称（如 "控制台 API"）
    let pid: Int?               // 进程 ID
    let status: ProcessStatus   // online, stopped, errored, etc.
    let cpu: Double             // CPU 使用率
    let memory: Double          // 内存使用（MB）
    let uptime: Int             // 运行时长（秒）
    let restarts: Int           // 重启次数
    let port: Int?              // 监听端口（从 lsof 探测）
    let url: String?            // 访问 URL（如 "http://localhost:18920"）
    let logPath: String?        // 日志文件路径
    let category: ServiceCategory // api, frontend, bot, etc.
    let projectPath: String     // 项目路径（如 "./AI工作区/控制台/backend"）
}

enum ProcessStatus: String, Codable {
    case online = "online"
    case stopped = "stopped"
    case launching = "launching"
    case errored = "errored"
    case one-launch-status = "one-launch-status"
}

enum ServiceCategory: String, Codable {
    case api = "API"
    case frontend = "Frontend"
    case bot = "Bot"
    case monitor = "Monitor"
    case game = "Game"
    case other = "Other"
}
```

### 2. AppState（应用状态）
```swift
class AppState: ObservableObject {
    @Published var projects: [PM2Project] = []
    @Published var isLoading: Bool = false
    @Published var filterText: String = ""
    @Published var selectedCategory: ServiceCategory? = nil
    @Published var autoRefresh: Bool = true
    @Published var refreshInterval: TimeInterval = 5.0 // 秒
    
    // 端口池管理
    @Published var portPool: PortPool = PortPool(
        apiRange: 18920...18999,
        frontendRange: 15920...15999,
        usedPorts: Set<Int>()
    )
    
    // 用户偏好
    @Published var showNotifications: Bool = true
    @Published var compactMode: Bool = false
}

struct PortPool: Codable {
    let apiRange: ClosedRange<Int>
    let frontendRange: ClosedRange<Int>
    var usedPorts: Set<Int>
    
    mutating func allocatePort(category: ServiceCategory) -> Int? {
        let range = category == .api ? apiRange : frontendRange
        for port in range {
            if !usedPorts.contains(port) && !isPortInUse(port) {
                usedPorts.insert(port)
                return port
            }
        }
        return nil
    }
    
    func isPortInUse(_ port: Int) -> Bool {
        // 使用 lsof 检测端口占用
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }
}
```

---

## 🎨 UI 设计

### 状态栏菜单（主界面）
```swift
MenuButton("Visual PM2") {
    // 顶部状态概览
    VStack(alignment: .leading) {
        Text("🟢 12 Online | 🔴 3 Stopped | ⚠️ 1 Errored")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    Divider()
    
    // 搜索框
    TextField("搜索服务...", text: $filterText)
        .textFieldStyle(.roundedBorder)
    
    // 分类筛选
    Picker("分类", selection: $selectedCategory) {
        Text("全部").tag(nil as ServiceCategory?)
        Text("API").tag(ServiceCategory.api as ServiceCategory?)
        Text("前端").tag(ServiceCategory.frontend as ServiceCategory?)
        Text("Bot").tag(ServiceCategory.bot as ServiceCategory?)
    }
    .pickerStyle(.segmented)
    
    Divider()
    
    // 服务列表
    ForEach(filteredProjects) { project in
        ProjectMenuItem(project: project)
    }
    
    Divider()
    
    // 底部操作
    Button("刷新状态") { refreshProjects() }
    Button("打开日志目录") { openLogsDirectory() }
    Button("设置...") { openSettings() }
    Divider()
    Button("退出") { NSApplication.shared.terminate(nil) }
}
```

### 单个服务菜单项
```swift
struct ProjectMenuItem: View {
    let project: PM2Project
    
    var body: some View {
        HStack {
            // 状态指示器
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // 服务名称
            VStack(alignment: .leading) {
                Text(project.name)
                    .font(.body)
                Text(project.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 端口和 URL
            if let port = project.port {
                Text(":\(port)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            // 操作按钮
            HStack(spacing: 8) {
                Button(action: { startProject(project) }) {
                    Image(systemName: "play.fill")
                }
                .disabled(project.status == .online)
                
                Button(action: { stopProject(project) }) {
                    Image(systemName: "stop.fill")
                }
                .disabled(project.status == .stopped)
                
                Button(action: { restartProject(project) }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(project.status == .stopped)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
    
    var statusColor: Color {
        switch project.status {
        case .online: return .green
        case .stopped: return .red
        case .errored: return .orange
        default: return .gray
        }
    }
}
```

### 设置窗口
```swift
struct SettingsView: View {
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("refreshInterval") private var refreshInterval = 5.0
    @AppStorage("showNotifications") private var showNotifications = true
    
    var body: some View {
        TabView {
            VStack(alignment: .leading) {
                Toggle("自动刷新", isOn: $autoRefresh)
                Slider(value: $refreshInterval, in: 1...60, step: 1) {
                    Text("刷新间隔: \(Int(refreshInterval))秒")
                }
                Toggle("显示通知", isOn: $showNotifications)
                Divider()
                Button("重置所有设置") { resetSettings() }
            }
            .padding()
            .tabItem { Label("常规", systemImage: "gear") }
            
            VStack(alignment: .leading) {
                Text("端口范围配置")
                    .font(.headline)
                HStack {
                    Text("API 端口范围:")
                    TextField("", value: $portPool.apiRange, format: .numberRange)
                }
                HStack {
                    Text("前端端口范围:")
                    TextField("", value: $portPool.frontendRange, format: .numberRange)
                }
                Divider()
                Button("扫描端口冲突") { scanPortConflicts() }
            }
            .padding()
            .tabItem { Label("网络", systemImage: "network") }
            
            VStack(alignment: .leading) {
                Text("关于")
                    .font(.headline)
                Text("Visual PM2 GUI v1.0")
                Text("© 2026 豆爸")
                Divider()
                Button("检查更新") { checkForUpdates() }
            }
            .padding()
            .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 400)
    }
}
```

---

## 🔧 核心功能实现

### 1. PM2 服务（PM2Service.swift）
```swift
import Foundation

class PM2Service: ObservableObject {
    private let nodePath = "/opt/homebrew/bin/node" // 或 /usr/local/bin/node
    private let pm2ScriptPath = "/Users/douba/Projects/XM/project/pm2-swift/scripts/pm2_wrapper.js"
    
    // 获取所有服务列表
    func fetchProjects() -> [PM2Project] {
        let nodeProcess = Process()
        nodeProcess.launchPath = nodePath
        nodeProcess.arguments = [pm2ScriptPath, "list"]
        
        let pipe = Pipe()
        nodeProcess.standardOutput = pipe
        nodeProcess.launch()
        nodeProcess.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonString = String(data: data, encoding: .utf8),
              let jsonData = jsonString.data(using: .utf8),
              let projects = try? JSONDecoder().decode([PM2Project].self, from: jsonData) else {
            return []
        }
        
        // 附加端口检测
        return projects.map { project in
            var project = project
            project.port = detectPort(for: project)
            return project
        }
    }
    
    // 启动服务
    func startProject(_ id: String) async throws {
        try await executePM2Command("start", id)
    }
    
    // 停止服务
    func stopProject(_ id: String) async throws {
        try await executePM2Command("stop", id)
    }
    
    // 重启服务
    func restartProject(_ id: String) async throws {
        try await executePM2Command("restart", id)
    }
    
    // 获取日志
    func fetchLogs(for id: String, lines: Int = 100) async throws -> String {
        let nodeProcess = Process()
        nodeProcess.launchPath = nodePath
        nodeProcess.arguments = [pm2ScriptPath, "logs", id, String(lines)]
        
        let pipe = Pipe()
        nodeProcess.standardOutput = pipe
        nodeProcess.launch()
        nodeProcess.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func executePM2Command(_ command: String, _ id: String) async throws {
        let nodeProcess = Process()
        nodeProcess.launchPath = nodePath
        nodeProcess.arguments = [pm2ScriptPath, command, id]
        
        try nodeProcess.run()
        nodeProcess.waitUntilExit()
        
        if nodeProcess.terminationStatus != 0 {
            throw PM2Error.commandFailed(command)
        }
    }
    
    // 端口检测（使用 lsof）
    private func detectPort(for project: PM2Project) -> Int? {
        guard let pid = project.pid else { return nil }
        
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-p", String(pid)]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // 解析 lsof 输出: "COMMAND   PID USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME"
        // 提取端口: "TCP *:18920 (LISTEN)"
        if let range = output.range(of: ":([0-9]+)", options: .regularExpression) {
            let portString = output[range].dropFirst()
            return Int(portString)
        }
        
        return nil
    }
}

enum PM2Error: Error {
    case commandFailed(String)
}
```

### 2. PM2 Node.js 包装器（scripts/pm2_wrapper.js）
```javascript
const pm2 = require('pm2');

const command = process.argv[2];
const args = process.argv.slice(3);

pm2.connect((err) => {
  if (err) {
    console.error(JSON.stringify({ error: err.message }));
    process.exit(1);
  }

  switch (command) {
    case 'list':
      pm2.list((err, list) => {
        if (err) {
          console.error(JSON.stringify({ error: err.message }));
          pm2.disconnect();
          process.exit(1);
        }
        
        const projects = list.map(process => ({
          id: process.name,
          name: process.name,
          pid: process.pid,
          status: process.pm2_env.status,
          cpu: process.monit?.cpu || 0,
          memory: process.monit?.memory || 0,
          uptime: process.pm2_env.pm_uptime || 0,
          restarts: process.pm2_env.restart_time || 0,
          logPath: process.pm2_env.pm_out_log_path,
          projectPath: process.pm2_env.cwd || '',
        }));
        
        console.log(JSON.stringify(projects));
        pm2.disconnect();
      });
      break;

    case 'start':
      pm2.start(args[0], (err) => {
        if (err) {
          console.error(JSON.stringify({ error: err.message }));
        } else {
          console.log(JSON.stringify({ success: true }));
        }
        pm2.disconnect();
        process.exit(err ? 1 : 0);
      });
      break;

    case 'stop':
    case 'restart':
    case 'delete':
      pm2[command](args[0], (err) => {
        if (err) {
          console.error(JSON.stringify({ error: err.message }));
        } else {
          console.log(JSON.stringify({ success: true }));
        }
        pm2.disconnect();
        process.exit(err ? 1 : 0);
      });
      break;

    case 'logs':
      const [processName, lines = '100'] = args;
      pm2.logs(processName, { lines: parseInt(lines), nostream: true }, (err, logs) => {
        if (err) {
          console.error(JSON.stringify({ error: err.message }));
        } else {
          console.log(logs.map(log => `[${log.date}] ${log.data}`).join('\n'));
        }
        pm2.disconnect();
      });
      break;

    default:
      console.error(JSON.stringify({ error: 'Unknown command' }));
      pm2.disconnect();
      process.exit(1);
  }
});
```

---

## 📁 项目结构

```
pm2-swift/
├── VisualPM2GUI.xcodeproj/     # Xcode 项目
├── VisualPM2GUI/
│   ├── VisualPM2GUIApp.swift   # 应用入口
│   ├── AppState.swift          # 应用状态管理
│   ├── Models/
│   │   ├── PM2Project.swift    # 数据模型
│   │   └── PortPool.swift      # 端口池管理
│   ├── Services/
│   │   └── PM2Service.swift    # PM2 通信服务
│   ├── Views/
│   │   ├── StatusBarMenu.swift # 状态栏菜单
│   │   ├── ProjectMenuItem.swift # 服务菜单项
│   │   ├── SettingsView.swift  # 设置窗口
│   │   └── LogsView.swift      # 日志查看器
│   ├── Resources/
│   │   └── Assets.xcassets     # 图标资源
│   └── Info.plist              # 应用配置
├── scripts/
│   ├── pm2_wrapper.js          # PM2 Node.js 包装器
│   └── install_dependencies.sh # 依赖安装脚本
├── docs/
│   ├── IMPLEMENTATION_PLAN.md  # 本文档
│   └── API.md                  # API 文档
├── tests/
│   ├── PM2ServiceTests.swift   # 单元测试
│   └── PortPoolTests.swift     # 端口池测试
└── README.md                   # 项目说明
```

---

## 🚀 实施步骤

### Phase 1：MVP 开发（Week 1-2）

#### Week 1：基础架构
- [ ] Day 1-2：创建 Xcode 项目，配置 SwiftUI + 状态栏应用
- [ ] Day 3-4：实现 PM2Service，完成 Node.js 包装器
- [ ] Day 5：数据模型定义（PM2Project, AppState）

#### Week 2：UI 开发
- [ ] Day 1-2：状态栏菜单 + 服务列表
- [ ] Day 3：三键控制（Start/Stop/Restart）
- [ ] Day 4：端口检测与显示
- [ ] Day 5：日志查看器基础版

### Phase 2：功能增强（Week 3-4）

#### Week 3：高级功能
- [ ] Day 1-2：端口自动分配
- [ ] Day 3：配置导入/导出（JSON）
- [ ] Day 4：批量操作（启动/停止所有服务）
- [ ] Day 5：健康监控（CPU/内存图表）

#### Week 4：优化与测试
- [ ] Day 1-2：性能优化（大量服务列表）
- [ ] Day 3：单元测试 + 集成测试
- [ ] Day 4：UI/UX 优化
- [ ] Day 5：文档完善

### Phase 3：部署与发布（Week 5）

#### Week 5：打包与发布
- [ ] Day 1：代码签名 + 公证
- [ ] Day 2：DMG 安装包制作
- [ ] Day 3：GitHub Release
- [ ] Day 4：Homebrew Formula（可选）
- [ ] Day 5：文档 + 教程

---

## 🔐 安全与权限

### macOS 权限配置

**Info.plist 配置**：
```xml
<key>NSAppleEventsUsageDescription</key>
<string>需要与 PM2 通信以管理服务</string>

<key>LSUIElement</key>
<true/> <!-- 隐藏 Dock 图标，仅显示状态栏 -->

<key>NSSystemAdministrationUsageDescription</key>
<string>需要管理员权限来管理 PM2 服务</string>
```

**沙盒配置（开发阶段可禁用）**：
- 开发阶段：关闭沙盒，方便调试
- 发布阶段：开启沙盒，配置例外：
  - `com.apple.security.network.client` (允许网络连接)
  - `com.apple.security.files.user-selected.read-only` (读取日志文件)

### 安全考虑
1. **Node.js 子进程**：使用绝对路径，防止 PATH 劫持
2. **PM2 权限**：确保 PM2 守护进程以用户权限运行（非 root）
3. **日志文件**：只读访问，不修改原始日志
4. **配置存储**：使用 `~/Library/Application Support/`，避免权限问题

---

## 📊 性能优化

### 大量服务列表优化
```swift
// 使用 LazyVStack 懒加载
LazyVStack {
    ForEach(filteredProjects) { project in
        ProjectMenuItem(project: project)
    }
}

// 分页加载（每页 20 个）
@Published var currentPage = 0
let pageSize = 20

var paginatedProjects: [PM2Project] {
    let start = currentPage * pageSize
    let end = min(start + pageSize, filteredProjects.count)
    return Array(filteredProjects[start..<end])
}
```

### 刷新策略
- **正常模式**：每 5 秒刷新一次
- **节能模式**：每 30 秒刷新一次
- **手动刷新**：用户点击刷新按钮
- **智能刷新**：仅在状态变化时更新 UI

---

## 🧪 测试策略

### 单元测试
```swift
import XCTest
@testable import VisualPM2GUI

class PM2ServiceTests: XCTestCase {
    var service: PM2Service!
    
    override func setUp() {
        super.setUp()
        service = PM2Service()
    }
    
    func testFetchProjects() {
        let projects = service.fetchProjects()
        XCTAssertFalse(projects.isEmpty, "应该返回至少一个项目")
        XCTAssertNotNil(projects.first?.id, "项目 ID 不应为空")
    }
    
    func testDetectPort() {
        let project = PM2Project(
            id: "xm-console-api",
            name: "控制台 API",
            pid: 12345, // 测试 PID
            status: .online,
            cpu: 0.5,
            memory: 100,
            uptime: 3600,
            restarts: 0,
            port: nil,
            url: nil,
            logPath: nil,
            category: .api,
            projectPath: "./AI工作区/控制台/backend"
        )
        let port = service.detectPort(for: project)
        XCTAssertNotNil(port, "应该检测到端口")
    }
}
```

### 集成测试
```bash
# 测试 PM2 集成
./scripts/test_pm2_integration.sh

# 测试端口冲突检测
./scripts/test_port_conflicts.sh

# 性能测试（1000 个服务）
./scripts/test_performance.sh
```

---

## 📝 配置文件示例

### 项目配置（projects.json）
```json
{
  "version": "1.0",
  "projects": [
    {
      "id": "xm-console-api",
      "name": "控制台 API",
      "category": "api",
      "port": 18920,
      "url": "http://localhost:18920",
      "autoStart": true,
      "priority": "high"
    },
    {
      "id": "xm-console-frontend",
      "name": "控制台前端",
      "category": "frontend",
      "port": 15921,
      "url": "http://localhost:15921",
      "autoStart": true,
      "priority": "medium"
    }
  ],
  "portPool": {
    "apiRange": [18920, 18999],
    "frontendRange": [15920, 15999],
    "usedPorts": [18920, 15921]
  }
}
```

---

## 🐛 已知问题与解决方案

### 问题 1：PM2 守护进程未启动
**症状**：`pm2 list` 返回空  
**解决**：自动启动 PM2 守护进程
```swift
func ensurePM2Daemon() {
    let task = Process()
    task.launchPath = "/usr/local/bin/pm2"
    task.arguments = ["list"] // 触发守护进程启动
    task.launch()
    task.waitUntilExit()
}
```

### 问题 2：端口检测不准确
**症状**：lsof 返回多个端口  
**解决**：优先选择 TCP LISTEN 端口
```swift
func selectListeningPort(from ports: [Int]) -> Int? {
    ports.filter { isTCPListening(port: $0) }.first
}
```

### 问题 3：日志文件权限
**症状**：无法读取日志文件  
**解决**：使用 `pm2 logs` 而非直接读取文件
```javascript
// pm2_wrapper.js
pm2.logs(processName, { nostream: true }, (err, logs) => {
  // 从 PM2 API 获取日志，避免文件权限问题
});
```

---

## 📚 参考资料

### 技术文档
- [SwiftUI 官方文档](https://developer.apple.com/documentation/swiftui)
- [PM2 官方文档](https://pm2.keymetrics.io/docs/usage/quick-start/)
- [NSStatusItem 参考](https://developer.apple.com/documentation/appkit/nsstatusitem)

### 类似项目
- [PM2 Plus](https://pm2.io/) - 商业版 PM2 监控
- [PM2-Monitor](https://github.com/pm2-hive/pm2-monitor) - 开源监控方案
- [macOS Menu Bar Applications](https://www.raywenderlich.com/761-creating-a-macos-menu-bar-app-using-swiftui)

---

## ✅ 验收标准

### MVP 验收
- ✅ 状态栏应用正常运行，不占用 Dock
- ✅ 显示所有 PM2 服务状态（16 个服务）
- ✅ Start/Stop/Restart 操作正常
- ✅ 端口检测准确（与 `pm2-interactive.sh` 一致）
- ✅ 日志查看器显示最近 100 行日志
- ✅ 应用启动时间 < 2 秒

### 性能验收
- ✅ 100 个服务列表刷新 < 1 秒
- ✅ 内存占用 < 50 MB
- ✅ CPU 占用 < 5%（空闲时）

---

## 🎯 后续规划

### v1.1（1 个月后）
- 🔮 服务依赖管理（按顺序启动）
- 🔮 服务分组（开发环境 / 生产环境）
- 🔮 自定义标签和注释

### v1.2（3 个月后）
- 🔮 跨设备配置同步（iCloud / 自建服务器）
- 🔮 Web 管理界面
- 🔮 Docker 容器支持

### v2.0（6 个月后）
- 🔮 多服务器管理（SSH 远程 PM2）
- 🔮 分布式监控（集群管理）
- 🔮 AI 智能诊断（异常检测）

---

## 📞 联系方式

- **项目维护者**：豆爸
- **问题反馈**：[GitHub Issues](https://github.com/douba/visual-pm2-gui/issues)
- **文档更新**：2026-03-08

---

**文档版本**: v1.0  
**最后更新**: 2026-03-08  
**状态**: ✅ 已完成
