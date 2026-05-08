import Foundation
import Combine
import AppKit

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    @Published var projects: [PM2Project] = [] {
        didSet { updateFilteredProjects() }
    }
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var filterText: String = "" {
        didSet { updateFilteredProjects() }
    }
    @Published var selectedCategory: ServiceCategory? = nil {
        didSet { updateFilteredProjects() }
    }
    @Published var selectedProjects: Set<String> = []
    @Published var filteredProjects: [PM2Project] = []

    // MARK: - 乐观UI更新：临时状态
    @Published var pendingStarts: Set<String> = []
    @Published var pendingStops: Set<String> = []
    @Published var pendingGroupToggles: Set<String> = []

    // MARK: - Refresh Settings
    @Published var autoRefresh: Bool = true {
        didSet {
            guard !isApplyingPreferences else { return }
            if autoRefresh {
                restartAutoRefresh()
            } else {
                stopAutoRefresh()
            }
        }
    }
    @Published var refreshInterval: TimeInterval = 10.0 {
        didSet {
            guard !isApplyingPreferences else { return }
            if autoRefresh {
                restartAutoRefresh()
            }
        }
    }
    
    // MARK: - Port Management
    @Published var portPool: PortPool = PortPool()
    
    // MARK: - User Preferences
    @Published var showNotifications: Bool = true
    @Published var compactMode: Bool = false
    @Published var sortOrder: SortOrder = .name {
        didSet {
            sortProjects()
        }
    }
    @Published var tableColumns: TableColumnWidths = .default
    
    // MARK: - User Intent Persistence (用户意图持久化)
    private let configPersistence: ConfigPersistence
    
    // MARK: - Tabs
    enum TabType: String, CaseIterable {
        case all = "全部"
        case active = "激活的"
        case inactive = "未激活的"
        
        var filterType: ProjectFilterType {
            switch self {
            case .all: return .all
            case .active: return .active
            case .inactive: return .inactive
            }
        }
    }
    @Published var selectedTab: TabType = .all {
        didSet { updateFilteredProjects() }
    }
    
    // MARK: - Dependencies
    private let pm2Service: PM2ServiceProtocol
    private var refreshTimer: Timer?
    private var isRefreshing = false
    private var isApplyingPreferences = false
    private var saveDebounceTask: Task<Void, Never>?
    
    init(pm2Service: PM2ServiceProtocol = PM2Service(), configPersistence: ConfigPersistence = ConfigManager.shared) {
        self.pm2Service = pm2Service
        self.configPersistence = configPersistence
        isApplyingPreferences = true
        loadPreferences()
        isApplyingPreferences = false

        if autoRefresh {
            restartAutoRefresh()
        }

        Task {
            await refresh(showLoading: true)
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Actions
    func refresh(showLoading: Bool = false) async {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true
        if showLoading {
            isLoading = true
        }
        error = nil

        do {
            let fetched = try await pm2Service.fetchProjects()
            projects = fetched
            sortProjects()
        } catch {
            self.error = error
            if showNotifications {
                sendNotification(title: "刷新失败", message: error.localizedDescription)
            }
        }

        if showLoading {
            isLoading = false
        }
        isRefreshing = false
    }
    
    // MARK: - User Intent Persistence
    // 仅在应用启动时调用一次，不在每次 refresh 时调用
    func applyUserIntentOnce() async {
        let stoppedProjectIds = configPersistence.getConfig().stoppedProjects
        
        guard !stoppedProjectIds.isEmpty else { return }
        
        for projectId in stoppedProjectIds {
            if let project = projects.first(where: { $0.id == projectId }), project.isOnline {
                try? await pm2Service.stopProject(projectId)
            }
        }
        
        do {
            projects = try await pm2Service.fetchProjects()
            sortProjects()
        } catch {
            // 忽略刷新错误
        }
    }
    
    func startProject(_ id: String) async {
        let error = await _executeStartProject(id)
        await refresh()

        if let error = error {
            self.error = error
            if showNotifications {
                sendNotification(title: "启动失败", message: error.localizedDescription)
            }
        } else {
            try? await pm2Service.saveState()
            if showNotifications {
                let project = projects.first { $0.id == id }
                sendNotification(title: "服务已启动", message: project?.name ?? id)
            }
        }
    }

    func stopProject(_ id: String) async {
        let error = await _executeStopProject(id)
        await refresh()

        if let error = error {
            self.error = error
            if showNotifications {
                sendNotification(title: "停止失败", message: error.localizedDescription)
            }
        } else {
            try? await pm2Service.saveState()
            if showNotifications {
                let project = projects.first { $0.id == id }
                sendNotification(title: "服务已停止", message: project?.name ?? id)
            }
        }
    }

    func restartProject(_ id: String) async {
        do {
            try await pm2Service.restartProject(id)

            // 等待一小段时间让 PM2 完成重启
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒

            await refresh()

            // 自动保存 PM2 状态
            try? await pm2Service.saveState()

            if showNotifications {
                let project = projects.first { $0.id == id }
                sendNotification(title: "服务已重启", message: project?.name ?? id)
            }
        } catch {
            await refresh()
            self.error = error
            sendNotification(title: "重启失败", message: error.localizedDescription)
        }
    }

    // MARK: - 私有执行方法（无通知、无刷新，由调用方聚合）

    /// 执行启动操作，返回 Error?（nil 表示成功）
    @discardableResult
    private func _executeStartProject(_ id: String) async -> Error? {
        pendingStarts.insert(id)
        do {
            try await pm2Service.startProject(id)
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3s 等待 PM2 稳定
            pendingStarts.remove(id)
            configPersistence.markProjectStarted(id)
            return nil
        } catch {
            pendingStarts.remove(id)
            return error
        }
    }

    /// 执行停止操作，返回 Error?（nil 表示成功）
    @discardableResult
    private func _executeStopProject(_ id: String) async -> Error? {
        pendingStops.insert(id)
        do {
            try await pm2Service.stopProject(id)
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2s 等待 PM2 稳定
            pendingStops.remove(id)
            configPersistence.markProjectStopped(id)
            return nil
        } catch {
            pendingStops.remove(id)
            return error
        }
    }

    func openProjectURL(_ project: PM2Project) async {
        // 如果已有完整 URL，直接打开
        if let fullURL = project.fullURL, let url = URL(string: fullURL) {
            NSWorkspace.shared.open(url)
            return
        }

        // 否则，尝试根据项目配置猜测端口
        let guessedPort = guessPortForProject(project)
        let urlString = "http://localhost:\(guessedPort)"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)

            if showNotifications {
                sendNotification(
                    title: "尝试打开服务",
                    message: "\(project.name) -> \(urlString)\n(端口基于配置猜测，可能不准确)"
                )
            }
        }
    }

    private func guessPortForProject(_ project: PM2Project) -> Int {
        // 根据项目 ID 或类别猜测默认端口
        let name = project.id.lowercased()

        // API 服务默认端口范围
        if name.contains("-api") || name.contains("-backend") {
            // xm-console-api -> 18920
            if name.contains("console") { return 18920 }
            if name.contains("digital-human") { return 18921 }
            if name.contains("syai-admin") { return 18922 }
            return 18920  // 默认 API 端口
        }

        // Frontend 服务默认端口范围
        if name.contains("-frontend") || name.contains("-client") {
            // xm-console-frontend -> 15921
            if name.contains("console") { return 15921 }
            if name.contains("digital-human") { return 15922 }
            if name.contains("syai-admin") { return 15923 }
            if name.contains("syai-chat") { return 15924 }
            return 15921  // 默认前端端口
        }

        // 其他服务
        if name.contains("game") { return 3456 }
        if name.contains("yqa") { return 18925 }
        if name.contains("visual-engine") { return 3000 }

        // 根据类别返回默认端口
        return project.category.defaultPortRange.lowerBound
    }

    func savePM2State() async {
        do {
            try await pm2Service.saveState()
            if showNotifications {
                sendNotification(title: "PM2 状态已保存", message: "当前运行的进程列表已保存，PM2 重启后会自动恢复")
            }
        } catch {
            self.error = error
            sendNotification(title: "保存失败", message: error.localizedDescription)
        }
    }

    func startAllProjects() async {
        let offlineProjects = projects.filter { !$0.isOnline }
        await withTaskGroup(of: Void.self) { group in
            for project in offlineProjects {
                group.addTask { await self.startProject(project.id) }
            }
        }
    }

    func stopAllProjects() async {
        let onlineProjects = projects.filter { $0.isOnline }
        await withTaskGroup(of: Void.self) { group in
            for project in onlineProjects {
                group.addTask { await self.stopProject(project.id) }
            }
        }
    }

    func startProjectsInGroup(_ projectGroupKey: String) async {
        let groupProjects = projects.filter { $0.projectGroupKey == projectGroupKey && !$0.isOnline }
        guard !groupProjects.isEmpty else { return }

        // 并行启动组内所有 offline 项目，收集错误
        var errors: [(String, Error)] = []

        await withTaskGroup(of: (String, Error?).self) { group in
            for project in groupProjects {
                group.addTask {
                    let error = await self._executeStartProject(project.id)
                    return (project.id, error)
                }
            }
            for await result in group {
                if let error = result.1 {
                    errors.append((result.0, error))
                }
            }
        }

        // 一次刷新、一次保存
        await refresh()
        try? await pm2Service.saveState()

        // 聚合通知：全部成功 or 部分失败
        if showNotifications {
            if errors.isEmpty {
                sendNotification(
                    title: "\(projectGroupKey) 组启动完成",
                    message: "\(groupProjects.count) 个项目已全部启动"
                )
            } else {
                sendNotification(
                    title: "\(projectGroupKey) 组启动部分失败",
                    message: errors.map { "\($0.0): \($0.1.localizedDescription)" }.joined(separator: "\n")
                )
            }
        }
    }

    func stopProjectsInGroup(_ projectGroupKey: String) async {
        let groupProjects = projects.filter { $0.projectGroupKey == projectGroupKey && $0.isOnline }
        guard !groupProjects.isEmpty else { return }

        // 并行停止组内所有 online 项目，收集错误
        var errors: [(String, Error)] = []

        await withTaskGroup(of: (String, Error?).self) { group in
            for project in groupProjects {
                group.addTask {
                    let error = await self._executeStopProject(project.id)
                    return (project.id, error)
                }
            }
            for await result in group {
                if let error = result.1 {
                    errors.append((result.0, error))
                }
            }
        }

        // 持久化组停止意图（_executeStopProject 已标记单个项目，此处补充整体同步）
        var config = configPersistence.getConfig()
        for project in groupProjects {
            config.stoppedProjects.insert(project.id)
        }
        configPersistence.updateConfig(config)

        // 一次刷新、一次保存
        await refresh()
        try? await pm2Service.saveState()

        // 聚合通知：全部成功 or 部分失败
        if showNotifications {
            if errors.isEmpty {
                sendNotification(
                    title: "\(projectGroupKey) 组停止完成",
                    message: "\(groupProjects.count) 个项目已全部停止"
                )
            } else {
                sendNotification(
                    title: "\(projectGroupKey) 组停止部分失败",
                    message: errors.map { "\($0.0): \($0.1.localizedDescription)" }.joined(separator: "\n")
                )
            }
        }
    }

    func isGroupOnline(_ projectGroupKey: String) -> Bool {
        let groupProjects = projects.filter { $0.projectGroupKey == projectGroupKey }
        return !groupProjects.isEmpty && groupProjects.allSatisfy { $0.isOnline }
    }

    var onlineCount: Int {
        projects.filter { $0.isOnline || pendingStarts.contains($0.id) }.count
    }

    var stoppedCount: Int {
        projects.filter { $0.isStopped || pendingStops.contains($0.id) }.count
    }

    var erroredCount: Int {
        projects.filter { $0.isErrored }.count
    }
    
    var sortedGroupedProjects: [(groupName: String, projects: [PM2Project])] {
        groupProjects(filteredProjects)
    }
    
    private func updateFilteredProjects() {
        filteredProjects = filterProjects(projects, category: selectedCategory, filterType: selectedTab.filterType, text: filterText)
    }

    private func sortProjects() {
        projects = applySort(projects, by: sortOrder)
        updateFilteredProjects()
    }
    
    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func restartAutoRefresh() {
        stopAutoRefresh()
        if autoRefresh {
            startAutoRefresh()
        }
    }
    
    // MARK: - Notifications
    private func sendNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // MARK: - Persistence
    private func loadPreferences() {
        let config = configPersistence.getConfig()
        self.autoRefresh = config.autoRefresh
        self.refreshInterval = config.refreshInterval
        self.showNotifications = config.showNotifications
        self.compactMode = config.compactMode
        self.sortOrder = config.sortOrder
        self.portPool = config.portPool
        self.tableColumns = config.tableColumns
    }
    
    func savePreferences() {
        // Debounce save operations to prevent excessive disk writes
        saveDebounceTask?.cancel()
        saveDebounceTask = Task { @MainActor in
            // Wait 500ms before saving (debounce)
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            
            var config = configPersistence.getConfig()
            config.autoRefresh = autoRefresh
            config.refreshInterval = refreshInterval
            config.showNotifications = showNotifications
            config.compactMode = compactMode
            config.sortOrder = sortOrder
            config.portPool = portPool
            config.tableColumns = tableColumns
            
            configPersistence.updateConfig(config)
        }
    }
    
    // Immediate save without debounce (for critical operations)
    func savePreferencesImmediately() {
        saveDebounceTask?.cancel()
        var config = configPersistence.getConfig()
        config.autoRefresh = autoRefresh
        config.refreshInterval = refreshInterval
        config.showNotifications = showNotifications
        config.compactMode = compactMode
        config.sortOrder = sortOrder
        config.portPool = portPool
        config.tableColumns = tableColumns
        
        configPersistence.updateConfig(config)
    }
}
