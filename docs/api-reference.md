# API Reference

## PM2ServiceProtocol

```swift
protocol PM2ServiceProtocol {
    // 查询
    func fetchProjects() async throws -> [PM2Project]
    func fetchLogs(for id: String, lines: Int) async throws -> String
    func scanForNewProjects() async throws -> [DiscoveredApp]

    // 操作
    func startProject(_ id: String) async throws
    func stopProject(_ id: String) async throws
    func restartProject(_ id: String) async throws
    func deleteProject(_ id: String) async throws
    func startDiscoveredApp(configPath: String, appName: String) async throws

    // 持久化
    func saveState() async throws
    func flushLogs() async throws
}
```

## PM2Project

```swift
struct PM2Project: Codable, Identifiable {
    var id: String
    var name: String
    var status: String          // online/offline/errored/stopped
    var port: Int?
    var category: String        // Frontend/Backend/Game/Other
    var projectGroupKey: String // 分组键
    var fullURL: String?
    var script: String?
    var pid: Int?

    var isOnline: Bool { status == "online" }
    var isStopped: Bool { status == "stopped" }
    var isErrored: Bool { status == "errored" }
}
```

## AppState (公开方法)

```swift
@MainActor
class AppState: ObservableObject {
    @Published var projects: [PM2Project] = []
    @Published var filteredProjects: [PM2Project] = []
    @Published var filterText: String = ""
    @Published var selectedCategory: ServiceCategory? = nil
    @Published var selectedTab: TabType = .all

    // 批量操作
    func refresh(showLoading: Bool = false) async
    func startProject(_ id: String) async
    func stopProject(_ id: String) async
    func startAllProjects() async
    func stopAllProjects() async

    // 分组操作
    func startProjectsInGroup(_ projectGroupKey: String) async
    func stopProjectsInGroup(_ projectGroupKey: String) async
}
```

## PM2ServiceError

```swift
enum PM2ServiceError: Error, LocalizedError {
    case nodeNotFound
    case scriptNotFound
    case commandFailed(String)
    case invalidResponse
    case portDetectionFailed
    case maxRetriesExceeded(String)
}
```

## PM2 Wrapper 命令

```text
node scripts/pm2_wrapper.js <command> [args]
```

| 命令 | 参数 | 模式 |
|------|------|------|
| list | — | 同步 |
| start | `<name\|config-path>` | 异步 |
| stop | `<name>` | 同步 |
| restart | `<name>` | 同步 |
| delete | `<name>` | 同步 |
| logs | `<name> [lines]` | 同步 |
| flush | — | 同步 |
| save | — | 同步 |
| scan | — | 异步 |
| start-app | `<config-path> <name>` | 异步 |

## 端口匹配优先级

`extractPortFromArgs()` 模式匹配顺序（从最具体到最不具体）：

1. `--port N` → uvicorn/fastapi
2. `http.server` → Python HTTP
3. `-l N` / `--listen N` → npx serve
4. `-p N` → 通用简写
5. `server.port=N` → Streamlit
