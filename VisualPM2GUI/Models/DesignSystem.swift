import SwiftUI

// MARK: - Design System

/// Electric Blue 强调色调色板 (亮色/暗色双模式)
enum ElectricBlue {
    static let base = Color(red: 0.0, green: 0.478, blue: 1.0)       // #007AFF
    static let light = Color(red: 0.0, green: 0.478, blue: 1.0)       // 亮色模式
    static let dark = Color(red: 0.2, green: 0.6, blue: 1.0)          // 暗色模式稍亮
    static let dim = Color(red: 0.0, green: 0.4, blue: 0.85)          // 禁用/次要态
}

/// VD8 Cockpit 模式间距体系
enum VSpacing {
    /// 行内紧凑间距 (4pt)
    static let tight: CGFloat = 4
    /// 默认元素间距 (6pt)
    static let `default`: CGFloat = 6
    /// 区块间距 (8pt)
    static let block: CGFloat = 8
    /// 垂直行间距 (2pt)
    static let row: CGFloat = 2
}

/// 面板尺寸常量
enum PanelSize {
    /// 默认面板高度
    static let defaultHeight: CGFloat = 400
    /// 最小面板高度
    static let minHeight: CGFloat = 200
    /// 最大面板高度
    static let maxHeight: CGFloat = 800
    /// 拖拽手柄高度
    static let dragHandle: CGFloat = 6
}

/// 字体帮助方法
enum AppFont {
    /// 服务名称字体 - SF Pro Rounded Medium
    static let projectName = Font.system(size: 13, weight: .medium, design: .rounded)
    /// 数据数字字体 - SF Mono
    static let monoData = Font.system(size: 11, design: .monospaced)
    /// 辅助标签字体 - SF Pro Caption
    static let caption = Font.caption
    /// 较小辅助文本
    static let small = Font.system(size: 10)
}

/// 状态色 (降低饱和度适配 VD8)
extension ProcessStatus {
    var color: Color {
        switch self {
        case .online: return Color(red: 0.2, green: 0.7, blue: 0.3)    // 低饱和绿
        case .stopped: return Color(red: 0.55, green: 0.55, blue: 0.57) // 中性灰
        case .errored, .waitingRestart: return Color(red: 0.85, green: 0.35, blue: 0.15) // 橙红
        case .launching: return Color(red: 0.75, green: 0.65, blue: 0.15) // 暗金
        case .oneLaunchStatus: return Color(red: 0.5, green: 0.5, blue: 0.55) // 灰
        }
    }
}
