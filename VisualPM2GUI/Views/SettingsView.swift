import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "常规"
        case network = "网络"
        case about = "关于"
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .network: return "network"
            case .about: return "info.circle"
            }
        }
        
        var accentColor: Color {
            switch self {
            case .general: return ElectricBlue.base
            case .network: return .orange
            case .about: return .green
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            tabContent
        }
        .frame(width: 560, height: 480)
        .onDisappear {
            state.savePreferences()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18))
                .foregroundColor(ElectricBlue.base)
            
            Text("设置")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    // MARK: - Tab Content
    private var tabContent: some View {
        HStack(spacing: 0) {
            tabSidebar
                .frame(width: 140)
            
            Divider()
            
            tabDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Tab Sidebar
    private var tabSidebar: some View {
        VStack(spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func tabButton(for tab: SettingsTab) -> some View {
        Button(action: { selectedTab = tab }) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .foregroundColor(selectedTab == tab ? tab.accentColor : .secondary)
                    .frame(width: 20)
                
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: selectedTab == tab ? .medium : .regular))
                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == tab ? tab.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab Detail
    @ViewBuilder
    private var tabDetail: some View {
        Group {
            switch selectedTab {
            case .general: generalSettings
            case .network: networkSettings
            case .about: aboutSettings
            }
        }
        .padding(24)
    }
    
    // MARK: - General Settings
    @ViewBuilder
    private var generalSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                settingsCard(title: "刷新", icon: "arrow.clockwise") {
                    SettingToggle(title: "自动刷新", isOn: $state.autoRefresh)
                    
                    HStack {
                        Text("刷新间隔")
                            .font(.system(size: 13))
                        Spacer()
                        Slider(value: $state.refreshInterval, in: 1...60, step: 1)
                            .frame(width: 120)
                        Text("\(Int(state.refreshInterval))秒")
                            .font(AppFont.monoData)
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                    .disabled(!state.autoRefresh)
                    .opacity(state.autoRefresh ? 1 : 0.5)
                }
                
                settingsCard(title: "通知", icon: "bell") {
                    SettingToggle(title: "显示通知", isOn: $state.showNotifications)
                }
                
                settingsCard(title: "布局", icon: "square.grid.2x2") {
                    SettingToggle(title: "紧凑模式", isOn: $state.compactMode)
                }
                
                settingsCard(title: "排序", icon: "arrow.up.arrow.down") {
                    HStack {
                        Text("排序方式")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $state.sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
                
                HStack {
                    Spacer()
                    Button("重置默认") {
                        state.autoRefresh = true
                        state.refreshInterval = 5.0
                        state.showNotifications = true
                        state.compactMode = false
                        state.sortOrder = .name
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
    
    // MARK: - Network Settings
    @ViewBuilder
    private var networkSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                settingsCard(title: "端口范围", icon: "network") {
                    portRangeRow(label: "API 端口范围", range: state.portPool.apiRange)
                    portRangeRow(label: "前端端口范围", range: state.portPool.frontendRange)
                }
                
                settingsCard(title: "已使用端口", icon: "point.3.connected.trianglepath.dotted") {
                    if state.portPool.usedPorts.isEmpty {
                        Text("无")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(state.portPool.usedPorts.sorted(), id: \.self) { port in
                                portChip(port: port)
                            }
                        }
                    }
                }
                
                HStack {
                    Spacer()
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text("扫描端口冲突")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
    
    private func portRangeRow(label: String, range: PortRange) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Text("\(range.lower) - \(range.upper)")
                .font(AppFont.monoData)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func portChip(port: Int) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(ElectricBlue.base)
                .frame(width: 6, height: 6)
            Text(":\(port)")
                .font(AppFont.monoData)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(ElectricBlue.base.opacity(0.1))
        )
    }
    
    // MARK: - About Settings
    @ViewBuilder
    private var aboutSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ElectricBlue.base, ElectricBlue.dark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visual PM2 GUI")
                            .font(.system(size: 18, weight: .semibold))
                        Text("版本 1.0.0")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("© 2026 豆爸")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)
                
                settingsCard(title: "功能特性", icon: "star") {
                    VStack(alignment: .leading, spacing: 8) {
                        featureRow(icon: "checkmark.circle.fill", text: "实时查看 PM2 服务状态")
                        featureRow(icon: "checkmark.circle.fill", text: "快速启动/停止/重启服务")
                        featureRow(icon: "checkmark.circle.fill", text: "自动端口检测")
                        featureRow(icon: "checkmark.circle.fill", text: "日志快速查看")
                        featureRow(icon: "checkmark.circle.fill", text: "服务分类和搜索")
                    }
                }
                
                settingsCard(title: "技术栈", icon: "hammer") {
                    VStack(alignment: .leading, spacing: 6) {
                        techStackRow(icon: "swift", text: "SwiftUI - macOS 原生 UI")
                        techStackRow(icon: "server.rack", text: "PM2 API - 进程管理")
                        techStackRow(icon: "chevron.left.forwardslash.chevron.right", text: "Node.js - 后端集成")
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.green)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
        }
    }
    
    private func techStackRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Settings Card
private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(ElectricBlue.base)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
        
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(.leading, 4)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(nsColor: .controlBackgroundColor))
    )
}

// MARK: - Setting Toggle
private struct SettingToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 13))
        }
        .toggleStyle(.switch)
    }
}

// MARK: - Flow Layout
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        
        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            height = y + rowHeight
        }
    }
}
