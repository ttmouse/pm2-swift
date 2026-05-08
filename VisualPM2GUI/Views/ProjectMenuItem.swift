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
    var isGrouped: Bool = false
    @State private var showingLogs = false
    @State private var hovering = false
    
    var body: some View {
        rowContent
        .padding(.vertical, 6)
        .padding(.leading, isGrouped ? 4 : 0)
        .background(
            Color.secondary.opacity(hovering ? 0.1 : 0)
        )
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
                // 状态列 - 状态点居中
                Circle()
                    .fill(project.status.color)
                    .frame(width: 8, height: 8)
                    .frame(width: statusColumnWidth, alignment: .center)

                // 服务名列 - 名称左对齐
                Text(project.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .frame(width: nameColumnWidth, alignment: .leading)

                // 端口列 - 右对齐
                Text(project.port.map { String($0) } ?? "-")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                    .frame(width: portColumnWidth, alignment: .trailing)

                // 运行时长列 - 纯英文等宽，右对齐数字对齐
                Text(project.uptimeFormattedCompact)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: uptimeColumnWidth, alignment: .trailing)

                Spacer(minLength: 8)

                // 操作按钮列 - 右对齐
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
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
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
            .frame(width: 22, height: 22)
            .disabled(state.pendingStarts.contains(project.id) || state.pendingStops.contains(project.id))

            Button(action: {
                Task { await state.restartProject(project.id) }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
            }
            .frame(width: 22, height: 22)
            .disabled(project.isStopped || state.pendingStarts.contains(project.id) || state.pendingStops.contains(project.id))

            Button(action: { showingLogs = true }) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
            }
            .frame(width: 22, height: 22)

            Button(action: {
                // 优先使用 resolvedURL（已知端口），其次 fullURL，最后猜测
                if let urlString = project.resolvedURL ?? project.fullURL,
                   let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                } else {
                    // 没有已知端口，使用 guessPortForProject
                    Task { await state.openProjectURL(project) }
                }
            }) {
                Image(systemName: "safari")
                    .font(.system(size: 10))
            }
            .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovering in
            if isHovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

}
