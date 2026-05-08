import SwiftUI
import AppKit
import Foundation

// MARK: - Project Menu Item
struct ProjectMenuItem: View {
    let project: PM2Project
    @ObservedObject var state: AppState
    var tableLayout: Bool = false
    var nameColumnWidth: CGFloat = 260
    var portColumnWidth: CGFloat = 86
    var statusColumnWidth: CGFloat = 80
    var uptimeColumnWidth: CGFloat = 120
    var actionsColumnWidth: CGFloat = 132
    @State private var showingLogs = false
    @State private var hovering = false
    
    var body: some View {
        rowContent
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Color.secondary.opacity(0.1) : Color.clear)
        )
        .padding(.horizontal, tableLayout ? 12 : 8)
        .animation(Animation.spring(response: 0.35, dampingFraction: 0.8), value: hovering)
        .onHover { hovering in
            self.hovering = hovering
        }
        .sheet(isPresented: $showingLogs) {
            LogsView(project: project)
        }
        .contextMenu {
            Button("编辑项目") {
                print("Edit project: \(project.name)")
            }
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        if tableLayout {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(project.status.color)
                        .frame(width: 8, height: 8)

                    Text(project.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .lineLimit(1)
                }
                .frame(width: nameColumnWidth, alignment: .leading)

                Text(project.port.map { String($0) } ?? "-")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: portColumnWidth, alignment: .trailing)

                Text(project.uptimeFormatted)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(width: uptimeColumnWidth, alignment: .trailing)

                Spacer(minLength: 8)

                actionButtons
                    .frame(width: actionsColumnWidth, alignment: .trailing)
            }
        } else {
            HStack(spacing: 0) {
                Circle()
                    .fill(project.status.color)
                    .frame(width: 8, height: 8)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)

                HStack(spacing: 8) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(project.port.map { String($0) } ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text(project.uptimeFormatted)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .layoutPriority(1)

                Spacer()

                actionButtons
                    .padding(.trailing, 8)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            Group {
                // 启动/停止 合并为一个互斥按钮
                Button(action: {
                    Task {
                        if project.isOnline {
                            await state.stopProject(project.id)
                        } else {
                            await state.startProject(project.id)
                        }
                    }
                }) {
                    Image(systemName: project.isOnline ? "stop.fill" : "play.fill")
                        .font(.system(size: 10))
                }

                Button(action: {
                    Task { await state.restartProject(project.id) }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .disabled(project.isStopped)

                Button(action: { showingLogs = true }) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                }

                Button(action: {
                    print("[DEBUG] Safari button clicked for: \(project.name)")
                    print("[DEBUG] host: \(project.host ?? "nil")")
                    print("[DEBUG] port: \(project.port ?? -1)")
                    print("[DEBUG] fullURL: \(project.fullURL ?? "nil")")
                    
                    if let url = project.fullURL, let nsUrl = URL(string: url) {
                        print("[DEBUG] Opening URL: \(nsUrl.absoluteString)")
                        NSWorkspace.shared.open(nsUrl)
                    } else {
                        print("[DEBUG] fullURL is nil, calling openProjectURL")
                        Task { await state.openProjectURL(project) }
                    }
                }) {
                    Image(systemName: "safari")
                        .font(.system(size: 10))
                }
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .onHover { isHovering in
                if isHovering { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
            }
        }
    }

}
