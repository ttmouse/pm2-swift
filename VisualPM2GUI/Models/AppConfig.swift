import Foundation

struct TableColumnWidths: Codable {
    var name: Double
    var port: Double
    var status: Double
    var uptime: Double
    var actions: Double

    static let `default` = TableColumnWidths(
        name: 220,
        port: 86,
        status: 40,
        uptime: 120,
        actions: 132
    )
}

// MARK: - App Configuration
struct AppConfig: Codable {
    var autoRefresh: Bool
    var refreshInterval: TimeInterval
    var showNotifications: Bool
    var compactMode: Bool
    var sortOrder: SortOrder
    var portPool: PortPool
    var stoppedProjects: Set<String> // 用户手动停止的项目ID列表
    var tableColumns: TableColumnWidths
    
    enum SortOrder: String, Codable, CaseIterable {
        case name = "名称"
        case status = "状态"
        case cpu = "CPU"
        case memory = "内存"
        case uptime = "运行时长"
    }
    
    init() {
        self.autoRefresh = true
        self.refreshInterval = 5.0
        self.showNotifications = true
        self.compactMode = false
        self.sortOrder = .name
        self.portPool = PortPool()
        self.stoppedProjects = []
        self.tableColumns = .default
    }

    enum CodingKeys: String, CodingKey {
        case autoRefresh, refreshInterval, showNotifications, compactMode
        case sortOrder, portPool, stoppedProjects, tableColumns
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoRefresh = try container.decodeIfPresent(Bool.self, forKey: .autoRefresh) ?? true
        refreshInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .refreshInterval) ?? 5.0
        showNotifications = try container.decodeIfPresent(Bool.self, forKey: .showNotifications) ?? true
        compactMode = try container.decodeIfPresent(Bool.self, forKey: .compactMode) ?? false
        sortOrder = try container.decodeIfPresent(SortOrder.self, forKey: .sortOrder) ?? .name
        portPool = (try? container.decode(PortPool.self, forKey: .portPool)) ?? PortPool()
        stoppedProjects = try container.decodeIfPresent(Set<String>.self, forKey: .stoppedProjects) ?? []
        tableColumns = try container.decodeIfPresent(TableColumnWidths.self, forKey: .tableColumns) ?? .default
    }
    
    static var `default`: AppConfig {
        return AppConfig()
    }
}

// MARK: - Config Manager
class ConfigManager {
    static let shared = ConfigManager()
    
    private let configURL: URL
    private var config: AppConfig
    
    init() {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths.first!
        let configDirectory = appSupport.appendingPathComponent("pm2-swift")
        
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        
        self.configURL = configDirectory.appendingPathComponent("config.json")
        
        if let data = try? Data(contentsOf: configURL),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = .default
        }
    }
    
    func getConfig() -> AppConfig {
        return config
    }
    
    func updateConfig(_ config: AppConfig) {
        self.config = config
        save()
    }
    
    // 记录用户手动停止的项目
    func markProjectStopped(_ projectId: String) {
        config.stoppedProjects.insert(projectId)
        save()
    }
    
    // 记录用户手动启动的项目（从停止列表中移除）
    func markProjectStarted(_ projectId: String) {
        config.stoppedProjects.remove(projectId)
        save()
    }
    
    // 检查项目是否应该保持停止状态
    func shouldProjectStayStopped(_ projectId: String) -> Bool {
        return config.stoppedProjects.contains(projectId)
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(config) {
            try? encoded.write(to: configURL)
        }
    }
}
