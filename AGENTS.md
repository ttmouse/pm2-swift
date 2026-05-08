# Repository Guidelines

## Project Structure

```
pm2-swift/
├── VisualPM2GUI/           # Xcode/SwiftUI macOS app
│   ├── Models/             # Data models (PM2Project, AppState, AppConfig, PortPool)
│   ├── Services/           # Service layer (PM2Service)
│   ├── Views/              # SwiftUI views (StatusBarMenu, ProjectMenuItem, LogsView, SettingsView)
│   ├── VisualPM2GUIApp.swift
│   └── Info.plist
├── scripts/                # Node.js scripts (pm2_wrapper.js, package.json)
├── build/                   # Build output directory
├── build.sh                # Build script
└── *.md                    # Documentation
```

## Build & Run Commands

| Command | Description |
|---------|-------------|
| `./build.sh` | Compile Swift files and create app bundle in `build/VisualPM2GUI.app` |
| `open build/VisualPM2GUI.app` | Launch the built application |
| `cd scripts && npm install` | Install Node.js dependencies |
| `xcodebuild build -scheme VisualPM2GUI` | Build via Xcode |

**Prerequisites**: Accept Xcode license once with `sudo xcodebuild -license`

## Coding Style

- **Language**: Swift with SwiftUI for macOS
- **No Force Unwrapping**: Use `if let` / `guard let` for optionals
- **Naming**: camelCase for variables/functions, PascalCase for types
- **Architecture**: MVVM pattern (Models → Services → Views)
- **Error Handling**: Handle errors explicitly, never silently fail

## Project Conventions

- **Bundle ID**: `com.douba.visual-pm2-gui`
- **Target**: macOS 14.0+ (arm64/x86_64)
- **Frameworks**: SwiftUI, Cocoa, AppKit, Foundation

## Commit & PR Guidelines

Commits follow conventional format:
```
<type>(<scope>): <description>

Types: fix, feat, docs, chore, refactor, test
Scopes: visual-pm2-gui, pm2, configs, etc.
```

Examples from git history:
- `fix(visual-pm2-gui): 显示全量项目并修复 args 字段解析问题`
- `feat(业务视图): 更新企业客户分层维度与可视化布局`
- `docs: add gap analysis for web knowledge base implementation`

## Testing

No formal test suite configured. For manual testing, verify:
- Status bar icon appears with PM2 service list
- Start/Stop/Restart actions work correctly
- Log viewer displays output
- Search and filter functions properly

## Architecture

```
┌─────────────────────────────────────┐
│         StatusBarMenu (SwiftUI)     │
│  ┌─────────────────────────────────┐│
│  │    ProjectMenuItem List         ││
│  │    LogsView / SettingsView      ││
│  └─────────────────────────────────┘│
└─────────────────┬───────────────────┘
                  │ IPC (XPC/Process)
┌─────────────────▼───────────────────┐
│       PM2Service (Swift)            │
│    Calls Node.js pm2_wrapper.js    │
└─────────────────┬───────────────────┘
                  │ Node.js API
┌─────────────────▼───────────────────┐
│     PM2 (Node.js process manager)  │
└─────────────────────────────────────┘
```

## Key Files

| File | Purpose |
|------|---------|
| `VisualPM2GUIApp.swift` | App entry point, status bar integration |
| `PM2Service.swift` | PM2 IPC communication via child process |
| `AppState.swift` | Global app state management |
| `PM2Project.swift` | PM2 process data model |
| `scripts/pm2_wrapper.js` | Node.js PM2 API wrapper |
