# Spec: PM2 项目分组与组管理功能

## Context

pm2-swift macOS 状态栏应用管理着大量 PM2 进程（16+）。随着项目数量增长，平铺列表变得难以管理。分组逻辑不合理（如 `XM-bazi-backend` 和 `xm-console-api` 被归入同一组），组级操作（启动/停止组内所有项目）的 UI 反馈不可靠——toggle 开关在异步操作完成前就弹回，让用户误以为操作失败。

PRD 已定义完整需求（[PRD-group-management.md](../../PRD-group-management.md)），代码已部分实现但缺乏系统性 review 和最终验证。

## Current State

### Already Implemented

| 模块 | 文件 | 状态 |
|------|------|------|
| `projectGroupKey` 计算属性 | [PM2Project.swift](../../VisualPM2GUI/Models/PM2Project.swift:196) | ✅ 已完成 |
| `startProjectsInGroup` / `stopProjectsInGroup` | [AppState.swift](../../VisualPM2GUI/Models/AppState.swift:346) | ✅ 已完成 |
| `isGroupOnline` | [AppState.swift](../../VisualPM2GUI/Models/AppState.swift:376) | ✅ 已完成 |
| `sortedGroupedProjects` | [AppState.swift](../../VisualPM2GUI/Models/AppState.swift:393) | ✅ 已完成 |
| 分组 UI（折叠/展开、组头部、Toggle） | [StatusBarMenu.swift](../../VisualPM2GUI/Views/StatusBarMenu.swift:302) | ✅ 已完成 |
| `pendingGroupToggles` @State 绑定 | [StatusBarMenu.swift](../../VisualPM2GUI/Views/StatusBarMenu.swift:18) | ✅ 已完成（staged） |
| Toggle disabled during pending | [StatusBarMenu.swift](../../VisualPM2GUI/Views/StatusBarMenu.swift:379) | ✅ 已完成（staged） |
| pm2_wrapper.js 相对路径解析 | [pm2_wrapper.js](../../scripts/pm2_wrapper.js:248) | ✅ 已完成（staged） |

### Code Flow Trace

```
用户点击组 Toggle
  → Binding.get: isGroupActive || pendingGroupToggles.contains(groupName)
  → Binding.set: pendingGroupToggles.insert(groupName)
    → Task { state.startProjectsInGroup / stopProjectsInGroup }
      → 用 withTaskGroup 并行处理组内每个项目
        → 每个项目调用 startProject / stopProject
          → 乐观 UI → PM2 IPC → refresh
      → ConfigManager 持久化意图
    → pendingGroupToggles.remove(groupName)
```

### Gaps vs PRD

| PRD 需求 | 当前状态 | 备注 |
|---------|---------|------|
| **User Story #11**: Errored 项目的组视觉区分 | ✅ 已完成 | 组头部已显示 `exclamationmark.triangle.fill` 橙色图标 |
| **Error handling**: 组操作的部分失败回滚 | ⚠️ 部分 | 单个项目有回滚，但组级无聚合错误处理 |
| **Retry logic**: 指数退避重试 | ⚠️ 需验证 | PM2Service 中有重试机制，但需确认组操作场景 |
| **测试覆盖**: 分组逻辑 + IPC 参数验证 | ✅ 已完成 | `Tests/VisualPM2GUITests/GroupManagementTests.swift` 含 11 个 XCTest 用例 |

## Implementation Plan

### Step 1: 组级操作错误聚合

- **文件**: `VisualPM2GUI/Models/AppState.swift`
- **修改**: `startProjectsInGroup` 和 `stopProjectsInGroup` 收集错误信息
- **逻辑**: `withTaskGroup` 中每个子任务捕获错误，汇总后在组操作完成后一次性通知
- **通知**: 如果组内部分项目失败，发送聚合通知（如 "xm-console 组: 2/5 项目启动失败"）

### Step 2: pm2_wrapper.js 错误处理加固

- **文件**: `scripts/pm2_wrapper.js`
- **当前问题**: 部分命令的 stderr 输出格式不统一
- **修改**: 统一所有命令退出路径，确保 stderr 输出 `{"error": "..."}` 格式

## Files to Modify (Summary)

| 文件 | 修改类型 |
|------|---------|
| `VisualPM2GUI/Models/AppState.swift` | Step 1: 组级错误聚合 |
| `scripts/pm2_wrapper.js` | Step 2: 错误格式一致化 |

## Notes

- **Errored 组视觉标记**: 已在 `StatusBarMenu.swift` 中实现（`hasErrored` 检测 + `exclamationmark.triangle.fill` 橙色图标），无需额外修改
- **测试文件**: `Tests/VisualPM2GUITests/GroupManagementTests.swift` 已存在（11 个 XCTest 用例覆盖 `projectGroupKey` 和 `AppState` 分组逻辑），无需新建

## Verification

1. **编译验证**: `xcodebuild build -scheme VisualPM2GUI`
2. **运行时验证**: 启动 app，确认分组视图正常渲染
3. **组操作验证**: 点击组 toggle，确认：
   - Toggle 在操作期间保持在"开"位
   - Toggle 在操作期间 disabled 不可点击
   - 操作完成后 toggle 反映真实状态
4. **过滤验证**: 搜索框输入文字，分组视图正确过滤
5. **Errored 验证**: 创建一个 errored 状态的项目，确认组头部有视觉标记
6. **测试运行**: Product → Test 或 `xcodebuild test`
