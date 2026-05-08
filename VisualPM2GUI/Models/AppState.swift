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
    @Published var showAdvancedInfo: Bool = false
    @Published var tableColumns: TableColumnWidths = .default
    
    // MARK: - User Intent Persistence (用户意图持久化)
    private var configManager = ConfigManager.shared

    // MARK: - Tabs
    enum TabType: String, CaseIterable {
        case all = "全部"
        case active = "激活的"
        case inactive = "未激活的"
    }
    @Published var selectedTab: TabType = .all {
        didSet { updateFilteredProjects() }
    }
    
    // MARK: - Dependencies
    private let pm2Service: PM2ServiceProtocol
    private var refreshTimer: Timer?
    private var isRefreshing = false
    private var isApplyingPreferences = false
    
    // MARK: - Sort Order
    enum SortOrder: String, CaseIterable {
        case name = "名称"
        case status = "状态"
        case cpu = "CPU"
        case memory = "内存"
        case uptime = "运行时长"
    }
    
    init(pm2Service: PM2ServiceProtocol = PM2Service()) {
        self.pm2Service = pm2Service
        isApplyingPreferences = true
        loadPreferences()
        isApplyingPreferences = false

        if autoRefresh {
            restartAutoRefresh()
        }

        Task {
            await refresh(showLoading: true)
            // DEBUG: 记录加载结果
            let logMessage = "AppState init: loaded \(projects.count) projects, filtered: \(filteredProjects.count)\n"
            if let data = logMessage.data(using: .utf8) {
                try? data.write(to: URL(fileURLWithPath: "/tmp/visual-pm2-app.log"))
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Actions
    func refresh(showLoading: Bool = false) async {
        let startMsg = "refresh START showLoading=\(showLoading) isRefreshing=\(isRefreshing)\n"
        FileHandle.standardError.write(startMsg.data(using: .utf8)!)
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
            let logMsg = "refresh: fetched \(projects.count) projects\n"
            try logMsg.write(toFile: "/tmp/visual-pm2-app.log", atomically: true, encoding: .utf8)
            FileHandle.standardError.write(logMsg.data(using: .utf8)!)
            sortProjects()
        } catch {
            self.error = error
            let logMsg = "refresh error: \(error)\n"
            FileHandle.standardError.write(logMsg.data(using: .utf8)!)
            if showNotifications {
                sendNotification(title: "刷新失败", message: error.localizedDescription)
            }
        }

        if showLoading {
            isLoading = false
        }
        isRefreshing = false
        // 移除了 ensureUserIntent() 调用，避免干扰用户手动操作
    }
    
    // MARK: - User Intent Persistence
    // 仅在应用启动时调用一次，不在每次 refresh 时调用
    func applyUserIntentOnce() async {
        let stoppedProjectIds = ConfigManager.shared.getConfig().stoppedProjects
        
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
        // 乐观UI：立即更新状态
        pendingStarts.insert(id)
        updateProjectStatus(id, to: .online)

        do {
            try await pm2Service.startProject(id)

            // 等待一小段时间让 PM2 完成启动
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒

            // 清除pending状态并刷新
            pendingStarts.remove(id)
            await refresh()

            // 从停止列表中移除（用户明确启动了）
            ConfigManager.shared.markProjectStarted(id)

            // 自动保存 PM2 状态
            try? await pm2Service.saveState()

            if showNotifications {
                let project = projects.first { $0.id == id }
                sendNotification(title: "服务已启动", message: project?.name ?? id)
            }
        } catch {
            // 失败：回滚状态
            pendingStarts.remove(id)
            await refresh()
            self.error = error
            sendNotification(title: "启动失败", message: error.localizedDescription)
        }
    }

    func stopProject(_ id: String) async {
        // 乐观UI：立即更新状态
        pendingStops.insert(id)
        updateProjectStatus(id, to: .stopped)

        do {
            try await pm2Service.stopProject(id)

            // 等待一小段时间让 PM2 完成停止
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒

            // 清除pending状态并刷新
            pendingStops.remove(id)
            await refresh()

            // 添加到停止列表（用户明确停止了）
            ConfigManager.shared.markProjectStopped(id)

            // 自动保存 PM2 状态
            try? await pm2Service.saveState()

            if showNotifications {
                let project = projects.first { $0.id == id }
                sendNotification(title: "服务已停止", message: project?.name ?? id)
            }
        } catch {
            // 失败：回滚状态
            pendingStops.remove(id)
            await refresh()
            self.error = error
            sendNotification(title: "停止失败", message: error.localizedDescription)
        }
    }

    func restartProject(_ id: String) async {
        // 乐观UI：立即显示重启中状态
        updateProjectStatus(id, to: .launching)

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

    // MARK: - Helper: 乐观UI更新
    // Note: PM2Project is a struct with let properties, so true optimistic UI
    // requires architectural changes. Currently relies on refresh after operations.
    // The pendingStarts/pendingStops sets are used for count calculations.
    private func updateProjectStatus(_ id: String, to status: ProcessStatus) {
        // Stub: actual status comes from PM2 after refresh()
        // Optimistic UI is handled via pendingStarts/pendingStops sets
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
        await withTaskGroup(of: Void.self) { group in
            for project in groupProjects {
                group.addTask { await self.startProject(project.id) }
            }
        }
        
        // 从停止列表中移除整个组
        for project in groupProjects {
            ConfigManager.shared.markProjectStarted(project.id)
        }
    }

    func stopProjectsInGroup(_ projectGroupKey: String) async {
        let groupProjects = projects.filter { $0.projectGroupKey == projectGroupKey && $0.isOnline }
        await withTaskGroup(of: Void.self) { group in
            for project in groupProjects {
                group.addTask { await self.stopProject(project.id) }
            }
        }
        
        // 添加整个组到停止列表
        var config = ConfigManager.shared.getConfig()
        for project in groupProjects {
            config.stoppedProjects.insert(project.id)
        }
        ConfigManager.shared.updateConfig(config)
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
        let grouped = Dictionary(grouping: filteredProjects) { $0.projectGroupKey }
        
        return grouped.map { ($0.key, $0.value) }.sorted { a, b in
            let aActive = a.projects.contains { $0.isOnline }
            let bActive = b.projects.contains { $0.isOnline }
            
            if aActive != bActive {
                return aActive
            }
            return a.groupName < b.groupName
        }
    }
    
    private func updateFilteredProjects() {
        var result = projects

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        switch selectedTab {
        case .all:
            break
        case .active:
            result = result.filter { $0.isOnline }
        case .inactive:
            result = result.filter { !$0.isOnline }
        }

        if !filterText.isEmpty {
            result = result.filter { project in
                project.name.localizedCaseInsensitiveContains(filterText) ||
                project.id.localizedCaseInsensitiveContains(filterText) ||
                (project.tags?.contains { $0.localizedCaseInsensitiveContains(filterText) } ?? false)
            }
        }

        filteredProjects = result
    }

    private func sortProjects() {
        switch sortOrder {
        case .name:
            projects.sort { $0.name < $1.name }
        case .status:
            projects.sort { $0.status.rawValue < $1.status.rawValue }
        case .cpu:
            projects.sort { $0.cpu > $1.cpu }
        case .memory:
            projects.sort { $0.memory > $1.memory }
        case .uptime:
            projects.sort { $0.uptime > $1.uptime }
        }
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
        let config = ConfigManager.shared.getConfig()
        self.autoRefresh = config.autoRefresh
        self.refreshInterval = config.refreshInterval
        self.showNotifications = config.showNotifications
        self.compactMode = config.compactMode
        // Map config sort order to app state sort order
        switch config.sortOrder {
        case .name: self.sortOrder = .name
        case .status: self.sortOrder = .status
        case .cpu: self.sortOrder = .cpu
        case .memory: self.sortOrder = .memory
        case .uptime: self.sortOrder = .uptime
        }
        self.showAdvancedInfo = config.showAdvancedInfo
        self.portPool = config.portPool
        self.tableColumns = config.tableColumns
    }
    
    func savePreferences() {
        var config = ConfigManager.shared.getConfig()
        config.autoRefresh = autoRefresh
        config.refreshInterval = refreshInterval
        config.showNotifications = showNotifications
        config.compactMode = compactMode
        // Map app state sort order to config sort order
        switch sortOrder {
        case .name: config.sortOrder = .name
        case .status: config.sortOrder = .status
        case .cpu: config.sortOrder = .cpu
        case .memory: config.sortOrder = .memory
        case .uptime: config.sortOrder = .uptime
        }
        config.showAdvancedInfo = showAdvancedInfo
        config.portPool = portPool
        config.tableColumns = tableColumns
        
        ConfigManager.shared.updateConfig(config)
    }
}
