import SwiftUI

// MARK: - Main App
@main
struct VisualPM2GUIApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainWindow(state: appState)
                .frame(minWidth: 500, minHeight: 400)
        }
        // 移除 .windowStyle(.hiddenTitleBar) 可能会让系统自带的窗口标题栏回来，
        // 如果想彻底隐藏标题栏但让窗口变得可拖拽，通常会使用 windowStyle(.hiddenTitleBar)
        // 并手动添加一个拖拽区域，目前代码已经实现了 MainWindow 的内容，
        // 我们只需确保它不显示额外的系统标题栏。
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView(state: appState)
        }
    }
}

// MARK: - Main Window
struct MainWindow: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Content - 直接使用 StatusBarMenu 的项目列表逻辑
            StatusBarMenu(state: state)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
