import SwiftUI
import AppKit
import Foundation
import Combine

// MARK: - Status Bar Menu
struct StatusBarMenu: View {
    enum ListSortKey {
        case name
        case status
        case port
        case uptime
    }

    @ObservedObject var state: AppState
    @State private var showingSettings = false
    @State private var collapsedGroups: Set<String> = []
    @State private var pendingGroupToggles: Set<String> = []
    @State private var hasInitializedCollapsedGroups = false
    @State private var panelHeight: CGFloat = 400
    @State private var showGroupedView: Bool = true
    @State private var listSortKey: ListSortKey = .name
    @State private var listSortAscending: Bool = true
    @State private var dragStartNameWidth: CGFloat?
    @State private var dragStartPortWidth: CGFloat?
    @State private var dragStartStatusWidth: CGFloat?
    @State private var dragStartUptimeWidth: CGFloat?
    @State private var dragStartActionsWidth: CGFloat?

    init(state: AppState) {
        self.state = state
    }

    // MARK: - Ghostty Helper
    
    private func openInGhostty(path: String) {
        let targetDirectory = resolveGhosttyDirectory(from: path)
        let escapedPath = targetDirectory
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        set targetPath to "\(escapedPath)"

        tell application "System Events"
            if exists process "Ghostty" then
                tell process "Ghostty"
                    set frontmost to true
                    if (count of windows) > 0 then
                        keystroke "t" using command down
                    else
                        keystroke "n" using command down
                    end if
                end tell
            else
                tell application "Ghostty" to activate
            end if
        end tell

        delay 0.25

        tell application "System Events"
            tell process "Ghostty"
                set frontmost to true
                keystroke "cd " & quoted form of targetPath & " && clear"
                key code 36
            end tell
        end tell
        """

        executeAppleScript(script, name: "Ghostty") { error in
            if let error = error {
                // Fallback: try to open Terminal instead
                self.openInTerminal(path: targetDirectory)
            }
        }
    }
    
    private func openInTerminal(path: String) {
        let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "cd \"\(escapedPath)\" && clear"
        end tell
        """
        executeAppleScript(script, name: "Terminal", completion: nil)
    }
    
    private func openInFinder(path: String) {
        let targetDirectory = resolveGhosttyDirectory(from: path)
        let url = URL(fileURLWithPath: targetDirectory)
        NSWorkspace.shared.open(url)
    }
    
    private func executeAppleScript(_ source: String, name: String, completion: ((Error?) -> Void)?) {
        if let scriptObject = NSAppleScript(source: source) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                NSLog("AppleScript (\(name)) failed: \(errorMessage)")
                
                // Notify user about the failure
                DispatchQueue.main.async {
                    let notification = NSUserNotification()
                    notification.title = "\(name) 操作失败"
                    notification.informativeText = errorMessage
                    notification.soundName = NSUserNotificationDefaultSoundName
                    NSUserNotificationCenter.default.deliver(notification)
                }
                
                completion?(NSError(domain: "AppleScript", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            } else {
                completion?(nil)
            }
        } else {
            completion?(NSError(domain: "AppleScript", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create AppleScript"]))
        }
    }

    private func resolveGhosttyDirectory(from path: String) -> String {
        let expandedPath = NSString(string: path).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return expandedPath
            }
            return URL(fileURLWithPath: expandedPath).deletingLastPathComponent().path
        }

        return expandedPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Tabs
            HStack(spacing: 0) {
                // Tabs with counts
                ForEach(AppState.TabType.allCases, id: \.self) { tab in
                    Button(action: { state.selectedTab = tab }) {
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                            Text("(\(tabCount(for: tab)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(state.selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                if state.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 15, height: 15)
                }

                Spacer()

                HStack(spacing: 12) {
                    // 分组切换
                    Button(action: { showGroupedView.toggle() }) {
                        Image(systemName: showGroupedView ? "rectangle.stack" : "list.bullet")
                    }.buttonStyle(.plain).help(showGroupedView ? "列表视图" : "分组视图")

                    Button(action: { Task { await state.refresh() } }) {
                        Image(systemName: "arrow.clockwise")
                    }.buttonStyle(.plain).help("刷新")

                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }.buttonStyle(.plain).help("设置")

                    Button(action: {
                        let task = Process()
                        task.launchPath = "/usr/bin/open"
                        task.arguments = [Bundle.main.bundlePath]
                        task.launch()
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "arrow.clockwise.circle")
                    }.buttonStyle(.plain).help("重启")

                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Image(systemName: "power")
                    }.buttonStyle(.plain).help("退出")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()
            
            searchBar
            Divider()

            // Project list
            projectList
                .frame(maxHeight: .infinity)
            
            // Drag handle
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 6)
                .contentShape(Rectangle())
                .onHover { isHovering in
                    if isHovering { NSCursor.resizeUpDown.push() }
                    else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            panelHeight = max(200, min(800, panelHeight + value.translation.height))
                        }
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingSettings) {
            SettingsView(state: state)
        }
        .onAppear {
            if !hasInitializedCollapsedGroups {
                syncCollapsedGroups()
                hasInitializedCollapsedGroups = true
            }
        }
        .onChange(of: state.projects) { _, _ in
            syncCollapsedGroups()
        }
    }

    private func syncCollapsedGroups() {
        let currentGroups = Set(state.sortedGroupedProjects.map { $0.groupName })
        collapsedGroups = collapsedGroups.intersection(currentGroups)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("搜索服务...", text: $state.filterText).textFieldStyle(.plain)
            if !state.filterText.isEmpty {
                Button(action: { state.filterText = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func tabCount(for tab: AppState.TabType) -> Int {
        switch tab {
        case .all:
            return state.projects.count
        case .active:
            return state.onlineCount
        case .inactive:
            return state.stoppedCount
        }
    }
    
    private var projectList: some View {
        Group {
            if !showGroupedView {
                VStack(spacing: 0) {
                    listHeader
                    Divider()

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            if sortedListProjects.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(sortedListProjects) { project in
                                    ProjectMenuItem(
                                        project: project,
                                        state: state,
                                        tableLayout: true,
                                        nameColumnWidth: nameColumnWidth,
                                        portColumnWidth: portColumnWidth,
                                        statusColumnWidth: statusColumnWidth,
                                        uptimeColumnWidth: uptimeColumnWidth,
                                        actionsColumnWidth: actionsColumnWidth
                                    )
                                        .id("flat-project-row-\(project.id)")
                                    if project.id != sortedListProjects.last?.id {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            }
                        }
                        .id("flat-project-list")
                    }
                }
            } else {
                let groupedItems = state.sortedGroupedProjects.map { group in
                    (id: "group-\(group.groupName)", name: group.groupName, projects: group.projects)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        if state.filteredProjects.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(groupedItems, id: \.id) { group in
                                let projectGroup = group.name
                                let groupProjects = group.projects
                                let isCollapsed = collapsedGroups.contains(projectGroup)
                                let isGroupActive = groupProjects.contains { $0.isOnline }
                                let hasErrored = groupProjects.contains { $0.isErrored }

                                HStack(spacing: 8) {
                                    Button(action: {
                                        if isCollapsed {
                                            collapsedGroups.remove(projectGroup)
                                        } else {
                                            collapsedGroups.insert(projectGroup)
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.secondary)
                                            if hasErrored {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.orange)
                                            }
                                            Text("\(projectGroup) (\(groupProjects.count))")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    Spacer()

                                    Button(action: {
                                        if let firstProject = groupProjects.first {
                                            openInGhostty(path: firstProject.projectPath)
                                        }
                                    }) {
                                        Image(systemName: "terminal")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("在 Ghostty 中打开")

                                    Button(action: {
                                        if let firstProject = groupProjects.first {
                                            openInFinder(path: firstProject.projectPath)
                                        }
                                    }) {
                                        Image(systemName: "folder")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("在 Finder 中打开")

                                    Toggle("", isOn: Binding(
                                        get: { isGroupActive || pendingGroupToggles.contains(projectGroup) },
                                        set: { isOn in
                                            pendingGroupToggles.insert(projectGroup)
                                            Task {
                                                if isOn {
                                                    await state.startProjectsInGroup(projectGroup)
                                                } else {
                                                    await state.stopProjectsInGroup(projectGroup)
                                                }
                                                pendingGroupToggles.remove(projectGroup)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.switch)
                                    .scaleEffect(0.7)
                                    .frame(width: 36)
                                    .disabled(pendingGroupToggles.contains(projectGroup))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.clear)
                                .id("group-header-\(projectGroup)")

                                if !isCollapsed {
                                    let projectItems = groupProjects.map { project in
                                        (id: "group-project-\(project.id)", project: project)
                                    }
                                    ForEach(projectItems, id: \.id) { item in
                                        ProjectMenuItem(
                                            project: item.project,
                                            state: state,
                                            tableLayout: true,
                                            nameColumnWidth: nameColumnWidth,
                                            portColumnWidth: portColumnWidth,
                                            statusColumnWidth: statusColumnWidth,
                                            uptimeColumnWidth: uptimeColumnWidth,
                                            actionsColumnWidth: actionsColumnWidth
                                        )
                                            .id("group-project-row-\(item.project.id)")
                                        if item.project.id != groupProjects.last?.id {
                                            Divider().padding(.leading, 60)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .id("grouped-project-list")
                }
            }
        }
        .animation(.none, value: collapsedGroups)
    }

    private var sortedListProjects: [PM2Project] {
        state.filteredProjects.sorted { lhs, rhs in
            if lhs.id == rhs.id { return false }

            switch listSortKey {
            case .name:
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if comparison == .orderedSame {
                    return listSortAscending ? lhs.id < rhs.id : lhs.id > rhs.id
                }
                return listSortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
            case .status:
                let left = statusRank(lhs.status)
                let right = statusRank(rhs.status)
                if left == right {
                    let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                    if comparison == .orderedSame {
                        return listSortAscending ? lhs.id < rhs.id : lhs.id > rhs.id
                    }
                    return listSortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
                }
                return listSortAscending ? left < right : left > right
            case .port:
                let left = lhs.port ?? Int.max
                let right = rhs.port ?? Int.max
                if left == right {
                    let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                    if comparison == .orderedSame {
                        return listSortAscending ? lhs.id < rhs.id : lhs.id > rhs.id
                    }
                    return listSortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
                }
                return listSortAscending ? left < right : left > right
            case .uptime:
                if lhs.uptime == rhs.uptime {
                    let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                    if comparison == .orderedSame {
                        return listSortAscending ? lhs.id < rhs.id : lhs.id > rhs.id
                    }
                    return listSortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
                }
                return listSortAscending ? lhs.uptime < rhs.uptime : lhs.uptime > rhs.uptime
            }
        }
    }

    private var listHeader: some View {
        HStack(spacing: 0) {
            resizableHeaderColumn(
                width: nameColumnWidth,
                dragStart: $dragStartNameWidth,
                title: {
                    HStack(spacing: 10) {
                        sortHeaderButton(title: "状态", key: .status)
                        sortHeaderButton(title: "服务", key: .name)
                    }
                },
                alignment: .leading,
                onWidthChange: { width in
                    updateNameColumnWidth(width)
                }
            )

            resizableHeaderColumn(
                width: portColumnWidth,
                dragStart: $dragStartPortWidth,
                title: {
                    sortHeaderButton(title: "端口", key: .port)
                },
                alignment: .trailing,
                onWidthChange: { width in
                    updatePortColumnWidth(width)
                }
            )

            resizableHeaderColumn(
                width: uptimeColumnWidth,
                dragStart: $dragStartUptimeWidth,
                title: { sortHeaderButton(title: "时长", key: .uptime) },
                alignment: .trailing,
                onWidthChange: { width in
                    updateUptimeColumnWidth(width)
                }
            )

            Spacer(minLength: 8)

            Text("操作")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: actionsColumnWidth, alignment: .trailing)
                .overlay(alignment: .trailing) {
                    resizeHandle(
                        onChanged: { value in
                            if dragStartActionsWidth == nil {
                                dragStartActionsWidth = actionsColumnWidth
                            }
                            let next = (dragStartActionsWidth ?? actionsColumnWidth) + value.translation.width
                            updateActionsColumnWidth(next)
                        },
                        onEnded: {
                            dragStartActionsWidth = nil
                            state.savePreferences()
                        }
                    )
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func sortHeaderButton(title: String, key: ListSortKey) -> some View {
        Button(action: {
            if listSortKey == key {
                listSortAscending.toggle()
            } else {
                listSortKey = key
                listSortAscending = true
            }
        }) {
            HStack(spacing: 4) {
                Text(title)
                if listSortKey == key {
                    Image(systemName: listSortAscending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .font(.caption)
            .foregroundColor(listSortKey == key ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func statusRank(_ status: ProcessStatus) -> Int {
        switch status {
        case .online:
            return 0
        case .launching:
            return 1
        case .waitingRestart:
            return 2
        case .stopped:
            return 3
        case .errored:
            return 4
        case .oneLaunchStatus:
            return 5
        }
    }

    private var nameColumnWidth: CGFloat { CGFloat(state.tableColumns.name) }
    private var portColumnWidth: CGFloat { CGFloat(state.tableColumns.port) }
    private var statusColumnWidth: CGFloat { CGFloat(state.tableColumns.status) }
    private var uptimeColumnWidth: CGFloat { CGFloat(state.tableColumns.uptime) }
    private var actionsColumnWidth: CGFloat { CGFloat(state.tableColumns.actions) }

    private func updateNameColumnWidth(_ width: CGFloat) {
        updateTableColumns {
            $0.name = Double(clamp(width, min: 160, max: 420))
        }
    }

    private func updatePortColumnWidth(_ width: CGFloat) {
        updateTableColumns {
            $0.port = Double(clamp(width, min: 70, max: 180))
        }
    }

    private func updateStatusColumnWidth(_ width: CGFloat) {
        updateTableColumns {
            $0.status = Double(clamp(width, min: 64, max: 160))
        }
    }

    private func updateUptimeColumnWidth(_ width: CGFloat) {
        updateTableColumns {
            $0.uptime = Double(clamp(width, min: 90, max: 220))
        }
    }

    private func updateActionsColumnWidth(_ width: CGFloat) {
        updateTableColumns {
            $0.actions = Double(clamp(width, min: 110, max: 220))
        }
    }

    private func updateTableColumns(_ update: (inout TableColumnWidths) -> Void) {
        var columns = state.tableColumns
        update(&columns)
        state.tableColumns = columns
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }

    private func resizableHeaderColumn<Content: View>(
        width: CGFloat,
        dragStart: Binding<CGFloat?>,
        @ViewBuilder title: () -> Content,
        alignment: Alignment,
        onWidthChange: @escaping (CGFloat) -> Void
    ) -> some View {
        title()
            .frame(width: width, alignment: alignment)
            .overlay(alignment: .trailing) {
                resizeHandle(
                    onChanged: { value in
                        if dragStart.wrappedValue == nil {
                            dragStart.wrappedValue = width
                        }
                        let next = (dragStart.wrappedValue ?? width) + value.translation.width
                        onWidthChange(next)
                    },
                    onEnded: {
                        dragStart.wrappedValue = nil
                        state.savePreferences()
                    }
                )
            }
    }

    private func resizeHandle(
        onChanged: @escaping (DragGesture.Value) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .onHover { isHovering in
                if isHovering { NSCursor.resizeLeftRight.push() }
                else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(onChanged)
                    .onEnded { _ in onEnded() }
            )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 40)).foregroundColor(.secondary)
            Text(state.filterText.isEmpty ? "无服务" : "未找到匹配的服务").font(.caption).foregroundColor(.secondary)
        }.frame(height: 120)
    }
}
