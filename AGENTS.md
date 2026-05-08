# AGENTS.md

This file provides guidance to Qoder (qoder.com) when working with code in this repository.

## Build Commands

```bash
# Build via script
./build.sh

# Build via Xcode
xcodebuild build -scheme VisualPM2GUI

# Run built app
open build/VisualPM2GUI.app

# Install Node.js dependencies (required before first build)
cd scripts && npm install
```

**Prerequisites**: Accept Xcode license once with `sudo xcodebuild -license`

## Architecture

```
┌─────────────────────────────────────────────────┐
│           StatusBarMenu (SwiftUI)               │
│  ┌───────────────────────────────────────────┐  │
│  │  ProjectMenuItem / LogsView / SettingsView │  │
│  └───────────────────────────────────────────┘  │
└──────────────────────┬────────────────────────┘
                       │ Child Process (Process.launchPath)
┌──────────────────────▼────────────────────────┐
│            PM2Service.swift                    │
│  - Runs node with pm2_wrapper.js as child     │
│  - Async/await wrapper for Process calls       │
└──────────────────────┬────────────────────────┘
                       │ PM2 Protocol
┌──────────────────────▼────────────────────────┐
│            pm2_wrapper.js                      │
│  - Connects to PM2 daemon via pm2 npm package │
│  - Commands: list, start, stop, restart,      │
│              delete, logs, flush, save, scan   │
└────────────────────────────────────────────────┘
```

## Key Communication Patterns

### Swift → Node.js IPC

`PM2Service` spawns a child `Process` that runs `node scripts/pm2_wrapper.js <command> [args]`:

- stdout: JSON response or data
- stderr: Error JSON `{"error": "message"}`
- Exit code 0 = success, non-zero = failure

### PM2 Service API

```swift
protocol PM2ServiceProtocol {
    func fetchProjects() async throws -> [PM2Project]
    func startProject(_ id: String) async throws
    func stopProject(_ id: String) async throws
    func restartProject(_ id: String) async throws
    func deleteProject(_ id: String) async throws
    func fetchLogs(for id: String, lines: Int) async throws -> String
    func flushLogs() async throws
    func saveState() async throws
    func scanForNewProjects() async throws -> [DiscoveredApp]
    func startDiscoveredApp(configPath: String, appName: String) async throws
}
```

## Code Conventions

- **No force unwrapping**: Use `if let` / `guard let` for optionals
- **Naming**: camelCase for variables/functions, PascalCase for types
- **Error handling**: Throw typed `PM2ServiceError` enum variants
- **Thread safety**: `PM2Service` uses a serial DispatchQueue

## Project Structure

```
VisualPM2GUI/
├── Models/           # PM2Project, AppState, AppConfig, PortPool
├── Services/         # PM2Service (IPC with Node.js)
├── Views/           # StatusBarMenu, ProjectMenuItem, LogsView, SettingsView
└── VisualPM2GUIApp.swift   # App entry point

scripts/
└── pm2_wrapper.js    # Node.js PM2 API wrapper
```

## Configuration

- **Bundle ID**: `com.douba.pm2-swift`
- **Target**: macOS 14.0+ (arm64/x86_64)
- **PM2 ecosystem config**: `/Users/douba/.pm2/ecosystem.config.js`
- **Project directories scanned**: See `PROJECT_DIRS` in `pm2_wrapper.js`

## Commit Format

```
<type>(<scope>): <description>

Types: fix, feat, docs, chore, refactor
Scopes: pm2-swift, pm2, configs
```
