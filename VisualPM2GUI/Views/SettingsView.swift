import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int? = 1
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("设置")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Vertical Sidebar Navigation
            NavigationView {
                // Sidebar
                List {
                    NavigationLink(destination: generalSettings, tag: 1, selection: $selectedTab) {
                        Label("常规", systemImage: "gear")
                    }
                    NavigationLink(destination: networkSettings, tag: 2, selection: $selectedTab) {
                        Label("网络", systemImage: "network")
                    }
                    NavigationLink(destination: aboutSettings, tag: 3, selection: $selectedTab) {
                        Label("关于", systemImage: "info.circle")
                    }
                }
                .frame(minWidth: 150)
                .listStyle(.sidebar)
                
                // Detail view
                Group {
                    switch selectedTab {
                    case 1:
                        generalSettings
                    case 2:
                        networkSettings
                    case 3:
                        aboutSettings
                    default:
                        generalSettings
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 600, height: 420)
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
            VStack(alignment: .leading, spacing: 20) {
                Text("常规设置")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Divider()
                
                // Auto refresh
                Toggle("自动刷新", isOn: $state.autoRefresh)
                    .help("自动刷新服务状态")
                
                // Refresh interval
                HStack {
                    Text("刷新间隔")
                        .frame(width: 120, alignment: .leading)
                    
                    Slider(value: $state.refreshInterval, in: 1...60, step: 1) {
                        Text("刷新间隔")
                    }
                    
                    Text("\(Int(state.refreshInterval))秒")
                        .frame(width: 50)
                }
                .help("自动刷新的时间间隔")
                
                Divider()
                
                // Notifications
                Toggle("显示通知", isOn: $state.showNotifications)
                    .help("服务状态变化时显示通知")
                
                Divider()
                
                // Compact mode
                Toggle("紧凑模式", isOn: $state.compactMode)
                    .help("使用更紧凑的界面布局")
                
                Divider()
                
                // Advanced info
                Toggle("显示高级信息", isOn: $state.showAdvancedInfo)
                    .help("显示 CPU、内存、PID 等高级信息")
                
                Divider()
                
                // Sort order
                HStack {
                    Text("排序方式")
                        .frame(width: 120, alignment: .leading)
                    
                    Picker("排序方式", selection: $state.sortOrder) {
                        ForEach(AppState.SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Spacer()
                
                // Reset button
                HStack {
                    Spacer()
                    
                    Button("重置所有设置") {
                        state.autoRefresh = true
                        state.refreshInterval = 5.0
                        state.showNotifications = true
                        state.compactMode = false
                        state.sortOrder = .name
                        state.showAdvancedInfo = false
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Network Settings
    @ViewBuilder
    private var networkSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("网络设置")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Divider()
                
                Text("端口范围配置")
                    .font(.headline)
                
                // API ports
                HStack {
                    Text("API 端口范围:")
                        .frame(width: 140, alignment: .leading)

                    Text("\(state.portPool.apiRange.lowerBound) - \(state.portPool.apiRange.upperBound)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // Frontend ports
                HStack {
                    Text("前端端口范围:")
                        .frame(width: 140, alignment: .leading)

                    Text("\(state.portPool.frontendRange.lowerBound) - \(state.portPool.frontendRange.upperBound)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Used ports
                VStack(alignment: .leading, spacing: 10) {
                    Text("已使用端口:")
                        .font(.headline)
                    
                    if state.portPool.usedPorts.isEmpty {
                        Text("无")
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(state.portPool.usedPorts.sorted(), id: \.self) { port in
                                    HStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 6, height: 6)
                                        Text(":\(port)")
                                            .font(.system(.body, design: .monospaced))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                    }
                }
                
                Divider()
                
                // Scan port conflicts
                Button("扫描端口冲突") {
                    // TODO: Implement port conflict scanning
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - About Settings
    @ViewBuilder
    private var aboutSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("关于")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Visual PM2 GUI")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("版本 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("© 2026 豆爸")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("功能特性")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "checkmark.circle", text: "实时查看 PM2 服务状态")
                        FeatureRow(icon: "checkmark.circle", text: "快速启动/停止/重启服务")
                        FeatureRow(icon: "checkmark.circle", text: "自动端口检测")
                        FeatureRow(icon: "checkmark.circle", text: "日志快速查看")
                        FeatureRow(icon: "checkmark.circle", text: "服务分类和搜索")
                    }
                    .font(.body)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("技术栈")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• SwiftUI - macOS 原生 UI")
                        Text("• PM2 API - 进程管理")
                        Text("• Node.js - 后端集成")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 16)
            Text(text)
        }
    }
}
