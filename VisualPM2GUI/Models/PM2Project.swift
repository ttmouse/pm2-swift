import Foundation
import AppKit
import SwiftUI

// MARK: - Discovered App (新发现的项目)
struct DiscoveredApp: Identifiable, Codable {
    let id = UUID()
    let name: String
    let configPath: String
    let projectPath: String
    let script: String?
    let port: Int?
    let category: String
}

// MARK: - Process Status
enum ProcessStatus: String, Codable {
    case online = "online"
    case stopped = "stopped"
    case launching = "launching"
    case errored = "errored"
    case oneLaunchStatus = "one-launch-status"
    case waitingRestart = "waiting restart"  // PM2 可能返回这个状态

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)

        // 处理所有可能的PM2状态值
        switch raw.lowercased() {
        case "online": self = .online
        case "stopped": self = .stopped
        case "launching": self = .launching
        case "errored", "error": self = .errored
        case "one-launch-status": self = .oneLaunchStatus
        case "waiting restart", "waiting-restart": self = .waitingRestart
        default:
            // 未知状态默认为 stopped
            self = .stopped
        }
    }

    var color: Color {
        switch self {
        case .online: return Color(nsColor: .systemGreen)
        case .stopped: return Color(nsColor: .systemGray)
        case .errored, .waitingRestart: return Color(nsColor: .systemOrange)
        case .launching: return Color(nsColor: .systemYellow)
        case .oneLaunchStatus: return Color(nsColor: .systemGray)
        }
    }

    var icon: String {
        switch self {
        case .online: return "power"
        case .stopped: return "poweroff"
        case .errored, .waitingRestart: return "exclamationmark.triangle"
        case .launching: return "hourglass"
        case .oneLaunchStatus: return "questionmark"
        }
    }
}

// MARK: - Service Category
enum ServiceCategory: String, Codable, CaseIterable {
    case api = "api"
    case frontend = "frontend"
    case bot = "bot"
    case monitor = "monitor"
    case game = "game"
    case database = "database"
    case other = "other"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)

        switch raw.lowercased() {
        case "api": self = .api
        case "frontend": self = .frontend
        case "bot": self = .bot
        case "monitor": self = .monitor
        case "game": self = .game
        case "database": self = .database
        default: self = .other  // 修复：默认返回 other 而不是抛出错误
        }
    }
    
    var icon: String {
        switch self {
        case .api: return "server.rack"
        case .frontend: return "desktopcomputer"
        case .bot: return "bubble.left.and.bubble.right"
        case .monitor: return "chart.line.uptrend.xyaxis"
        case .game: return "gamecontroller"
        case .database: return "database"
        case .other: return "cube"
        }
    }
    
    var defaultPortRange: ClosedRange<Int> {
        switch self {
        case .api, .database: return 18920...18999
        case .frontend: return 15920...15999
        case .game: return 3000...3999
        case .bot, .monitor, .other: return 5000...5999
        }
    }
}

// MARK: - Priority
enum Priority: String, Codable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

// MARK: - Project Metadata
struct ProjectMetadata: Codable {
    var tags: [String] = []
    var notes: String = ""
    var autoStart: Bool = false
    var priority: Priority = .medium
}

// MARK: - PM2 Project Model
struct PM2Project: Identifiable, Codable, Equatable {
    // Core identifiers
    let id: String                  // PM2 process name (unique)
    let name: String                // Display name
    let pid: Int?                   // Process ID
    
    // Status information
    let status: ProcessStatus       // online, stopped, errored, etc.
    let cpu: Double                 // CPU usage (0-100)
    let memory: Double              // Memory usage (MB)
    let uptime: TimeInterval        // Uptime (seconds)
    let restarts: Int               // Restart count
    
    // Network information
    var port: Int?                  // Listening port (detected via lsof)
    let url: String?                // Access URL
    let host: String?               // Hostname (default localhost)
    
    // Log information
    let logPath: String?            // Error log path
    let outPath: String?            // Output log path
    let errorPath: String?          // Error log path
    
    // Metadata
    let category: ServiceCategory   // Service category
    let projectPath: String         // Project path
    let interpreter: String?        // Interpreter (python3, node, etc.)
    let script: String?             // Startup script
    let args: [String]              // Startup arguments (Modified: non-optional)
    
    // User custom
    var tags: [String]?             // User tags
    var notes: String?              // Notes
    var autoStart: Bool?            // Auto start
    var priority: Priority?         // Priority
    
    // Computed properties
    var isOnline: Bool { status == .online }
    var isStopped: Bool { status == .stopped }
    var isErrored: Bool { status == .errored }
    
    var fullURL: String? {
        guard let host = host, let port = port else { return nil }
        return "http://\(host):\(port)"
    }
    
    var memoryFormatted: String {
        let bytes = Int64(memory * 1024 * 1024)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
    
    var uptimeFormatted: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: uptime) ?? "0s"
    }

    var projectGroupKey: String {
        let parts = id.split(separator: "-")
        // 增加更健壮的逻辑：如果没有横杠，或者分组名不合理，强制统一归类
        if parts.count >= 2 {
            return "\(parts[0])-\(parts[1])"
        }
        return "未分组" // 统一归类，避免直接展示 id 导致的 UI 碎裂
    }
    
    // Coding keys for custom decoding
    enum CodingKeys: String, CodingKey {
        case id, name, pid, status, cpu, memory, uptime, restarts
        case port, url, host
        case logPath, outPath, errorPath
        case category, projectPath, interpreter, script, args
        case tags, notes, autoStart, priority
    }

    // 实现自定义解码以处理 null
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        pid = try container.decodeIfPresent(Int.self, forKey: .pid)
        status = try container.decode(ProcessStatus.self, forKey: .status)
        cpu = try container.decode(Double.self, forKey: .cpu)
        memory = try container.decode(Double.self, forKey: .memory)
        uptime = try container.decode(TimeInterval.self, forKey: .uptime)
        restarts = try container.decode(Int.self, forKey: .restarts)
        port = try container.decodeIfPresent(Int.self, forKey: .port)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        host = try container.decodeIfPresent(String.self, forKey: .host)
        logPath = try container.decodeIfPresent(String.self, forKey: .logPath)
        outPath = try container.decodeIfPresent(String.self, forKey: .outPath)
        errorPath = try container.decodeIfPresent(String.self, forKey: .errorPath)
        category = try container.decode(ServiceCategory.self, forKey: .category)
        projectPath = try container.decode(String.self, forKey: .projectPath)
        interpreter = try container.decodeIfPresent(String.self, forKey: .interpreter)
        script = try container.decodeIfPresent(String.self, forKey: .script)
        // 强制将 args 初始化为空数组，而不是 null
        args = try container.decodeIfPresent([String].self, forKey: .args) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        autoStart = try container.decodeIfPresent(Bool.self, forKey: .autoStart)
        priority = try container.decodeIfPresent(Priority.self, forKey: .priority)
    }
    
    // 必要的初始化方法用于 mock
    init(id: String, name: String, pid: Int?, status: ProcessStatus, cpu: Double, memory: Double, uptime: TimeInterval, restarts: Int, port: Int?, url: String?, host: String?, logPath: String?, outPath: String?, errorPath: String?, category: ServiceCategory, projectPath: String, interpreter: String?, script: String?, args: [String], tags: [String]?, notes: String?, autoStart: Bool?, priority: Priority?) {
        self.id = id
        self.name = name
        self.pid = pid
        self.status = status
        self.cpu = cpu
        self.memory = memory
        self.uptime = uptime
        self.restarts = restarts
        self.port = port
        self.url = url
        self.host = host
        self.logPath = logPath
        self.outPath = outPath
        self.errorPath = errorPath
        self.category = category
        self.projectPath = projectPath
        self.interpreter = interpreter
        self.script = script
        self.args = args
        self.tags = tags
        self.notes = notes
        self.autoStart = autoStart
        self.priority = priority
    }
}

// MARK: - Mock for testing
extension PM2Project {
    static func mock(id: String, status: ProcessStatus) -> PM2Project {
        PM2Project(
            id: id,
            name: id,
            pid: status == .online ? 12345 : nil,
            status: status,
            cpu: 0.5,
            memory: 100,
            uptime: 3600,
            restarts: 0,
            port: 18920,
            url: "http://localhost:18920",
            host: "localhost",
            logPath: "/logs/\(id).log",
            outPath: "/logs/\(id)-out.log",
            errorPath: "/logs/\(id)-error.log",
            category: .api,
            projectPath: "./project/\(id)",
            interpreter: "node",
            script: "index.js",
            args: [],
            tags: nil,
            notes: nil,
            autoStart: true,
            priority: .medium
        )
    }
}
