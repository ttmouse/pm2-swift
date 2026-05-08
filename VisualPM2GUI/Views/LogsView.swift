import SwiftUI

// MARK: - Logs View
struct LogsView: View {
    let project: PM2Project
    @State private var logs: String = ""
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showCopyAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("日志 - \(project.name)")
                    .font(.headline)

                Spacer()

                Button(action: copyLogs) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("复制")
                    }
                }
                .disabled(logs.isEmpty || isLoading)

                Button(action: loadLogs) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新")
                    }
                }
                .disabled(isLoading)

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

            // Content
            if isLoading {
                VStack {
                    ProgressView("加载日志中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("加载失败")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Log content with selection enabled
                    ScrollView([.vertical, .horizontal]) {
                        Text(logs.isEmpty ? "无日志内容" : logs)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                    }

                    // Bottom toolbar with copy hint
                    HStack {
                        Text("💡 提示：可以选择文本后按 Cmd+C 复制")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("全部复制") {
                            copyAllLogs()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(logs.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
        }
        .frame(width: 700, height: 500)
        .onAppear {
            loadLogs()
        }
        .alert("已复制", isPresented: $showCopyAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("日志内容已复制到剪贴板")
        }
    }

    private func loadLogs() {
        isLoading = true
        error = nil

        Task {
            do {
                let service = PM2Service()
                logs = try await service.fetchLogs(for: project.id, lines: 200)
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }

    private func copyLogs() {
        // 复制选中的文本（如果有）或全部日志
        copyAllLogs()
    }

    private func copyAllLogs() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logs, forType: .string)

        // 显示提示
        showCopyAlert = true
    }
}
