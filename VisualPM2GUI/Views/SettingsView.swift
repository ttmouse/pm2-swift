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
            case .general: return "gear"
            case .network: return "network"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("设置")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
            
            // Sidebar + Detail
            NavigationSplitView {
                List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(.system(size: 13))
                        .padding(.vertical, 2)
                }
                .listStyle(.sidebar)
                .frame(minWidth: 140)
            } detail: {
                Group {
                    switch selectedTab {
                    case .general: generalSettings
                    case .network: networkSettings
                    case .about: aboutSettings
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 420)
        }
        .frame(width: 600, height: 450)
        .onDisappear {
            state.savePreferences()
        }
    }
    
    // MARK: - General Settings
    @ViewBuilder
    private var generalSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionView(title: "刷新") {
                    Toggle("自动刷新", isOn: $state.autoRefresh)
                    
                    HStack {
                        Text("刷新间隔")
                            .frame(width: 100, alignment: .leading)
                        Slider(value: $state.refreshInterval, in: 1...60, step: 1)
                        Text("\(Int(state.refreshInterval))秒")
                            .font(AppFont.monoData)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .disabled(!state.autoRefresh)
                }
                
                SectionView(title: "通知") {
                    Toggle("显示通知", isOn: $state.showNotifications)
                }
                
                SectionView(title: "布局") {
                    Toggle("紧凑模式", isOn: $state.compactMode)
                }
                
                SectionView(title: "排序") {
                    HStack {
                        Text("排序方式")
                            .frame(width: 100, alignment: .leading)
                        Picker("排序方式", selection: $state.sortOrder) {
                            ForEach(AppState.SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
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
            .padding(16)
        }
    }
    
    // MARK: - Network Settings
    @ViewBuilder
    private var networkSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionView(title: "端口范围") {
                    HStack {
                        Text("API 端口范围:")
                            .frame(width: 120, alignment: .leading)
                        Text("\(state.portPool.apiRange.lower) - \(state.portPool.apiRange.upper)")
                            .font(AppFont.monoData)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("前端端口范围:")
                            .frame(width: 120, alignment: .leading)
                        Text("\(state.portPool.frontendRange.lower) - \(state.portPool.frontendRange.upper)")
                            .font(AppFont.monoData)
                            .foregroundColor(.secondary)
                    }
                }
                
                SectionView(title: "已使用端口") {
                    if state.portPool.usedPorts.isEmpty {
                        Text("无")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(state.portPool.usedPorts.sorted(), id: \.self) { port in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(ElectricBlue.base)
                                            .frame(width: 5, height: 5)
                                        Text(":\(port)")
                                            .font(AppFont.monoData)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 100)
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Button("扫描端口冲突") {
                    // TODO: Implement port conflict scanning
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
            }
            .padding(16)
        }
    }
    
    // MARK: - About Settings
    @ViewBuilder
    private var aboutSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionView(title: "Visual PM2 GUI") {
                    Text("版本 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("© 2026 豆爸")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                SectionView(title: "功能特性") {
                    FeatureRow(icon: "checkmark.circle", text: "实时查看 PM2 服务状态")
                    FeatureRow(icon: "checkmark.circle", text: "快速启动/停止/重启服务")
                    FeatureRow(icon: "checkmark.circle", text: "自动端口检测")
                    FeatureRow(icon: "checkmark.circle", text: "日志快速查看")
                    FeatureRow(icon: "checkmark.circle", text: "服务分类和搜索")
                }
                
                SectionView(title: "技术栈") {
                    Text("SwiftUI - macOS 原生 UI").font(.caption).foregroundColor(.secondary)
                    Text("PM2 API - 进程管理").font(.caption).foregroundColor(.secondary)
                    Text("Node.js - 后端集成").font(.caption).foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
        }
    }
}

// MARK: - Settings Section
private struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(.leading, 2)
        }
        .padding(.vertical, 8)
        
        Divider()
    }
}

// MARK: - Feature Row
private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(ElectricBlue.base)
                .font(.system(size: 12))
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
        }
    }
}
