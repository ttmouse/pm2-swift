import Foundation

// MARK: - PM2 Service Error
enum PM2ServiceError: Error, LocalizedError {
    case nodeNotFound
    case scriptNotFound
    case commandFailed(String)
    case invalidResponse
    case portDetectionFailed
    case maxRetriesExceeded(String)

    var errorDescription: String? {
        switch self {
        case .nodeNotFound: return "Node.js not found."
        case .scriptNotFound: return "PM2 wrapper script not found."
        case .commandFailed(let cmd): return "Command '\(cmd)' failed."
        case .invalidResponse: return "Invalid response from PM2."
        case .portDetectionFailed: return "Failed to detect port."
        case .maxRetriesExceeded(let msg): return "Max retries exceeded: \(msg)"
        }
    }
}

// MARK: - PM2 Service Protocol
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

// MARK: - PM2 Service
class PM2Service: PM2ServiceProtocol {
    private let nodePath: String
    private let scriptPath: String
    private let queue = DispatchQueue(label: "com.visualpm2.api", qos: .userInitiated)

    init() {
        self.nodePath = PM2Service.findNodePath() ?? "/opt/homebrew/bin/node"
        self.scriptPath = PM2Service.resolveScriptPath()
    }

    private static func findNodePath() -> String? {
        let possiblePaths = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
        ]
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = ["node"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        if task.terminationStatus == 0,
           let data = try? pipe.fileHandleForReading.readToEnd(),
           let nodePath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return nodePath
        }
        return nil
    }

    private static func resolveScriptPath() -> String {
        let fileBased = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts")
            .appendingPathComponent("pm2_wrapper.js")
            .path
        
        let bundleBased = Bundle.main.resourceURL?
            .appendingPathComponent("scripts")
            .appendingPathComponent("pm2_wrapper.js")
            .path
        
        let candidates = [fileBased, bundleBased].compactMap { $0 }
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        return candidates.first ?? fileBased
    }

    func fetchProjects() async throws -> [PM2Project] {
        let jsonString = try await executePM2Command("list")
        guard let data = jsonString.data(using: .utf8) else {
            throw PM2ServiceError.invalidResponse
        }
        do {
            let result = try JSONDecoder().decode([PM2Project].self, from: data)
            return result
        } catch {
            throw PM2ServiceError.invalidResponse
        }
    }

    func startProject(_ id: String) async throws {
        _ = try await executePM2Command("start", id)
    }

    func stopProject(_ id: String) async throws {
        _ = try await executePM2Command("stop", id)
    }

    func restartProject(_ id: String) async throws {
        _ = try await executePM2Command("restart", id)
    }

    func deleteProject(_ id: String) async throws {
        _ = try await executePM2Command("delete", id)
    }

    func fetchLogs(for id: String, lines: Int = 100) async throws -> String {
        return try await executePM2Command("logs", id, String(lines))
    }

    func flushLogs() async throws {
        _ = try await executePM2Command("flush")
    }

    func saveState() async throws {
        _ = try await executePM2Command("save")
    }

    func scanForNewProjects() async throws -> [DiscoveredApp] {
        let jsonString = try await executePM2Command("scan")
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let apps = json["apps"] as? [[String: Any]] else {
            return []
        }
        
        return apps.compactMap { app -> DiscoveredApp? in
            guard let name = app["name"] as? String,
                  let configPath = app["configPath"] as? String else { return nil }
            
            return DiscoveredApp(
                name: name,
                configPath: configPath,
                projectPath: app["projectPath"] as? String ?? "",
                script: app["script"] as? String,
                port: app["port"] as? Int,
                category: app["category"] as? String ?? "Other"
            )
        }
    }

    func startDiscoveredApp(configPath: String, appName: String) async throws {
        _ = try await executePM2Command("start-app", configPath, appName)
    }

    // 带重试机制的 PM2 命令执行
    private func executePM2Command(_ arguments: String..., maxRetries: Int = 3) async throws -> String {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    queue.async {
                        do {
                            let result = try self.executePM2CommandSync(arguments: arguments)
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            } catch {
                lastError = error
                if attempt < maxRetries {
                    // 指数退避: 0.3s, 0.6s, 1.2s...
                    let delay = UInt64(pow(2.0, Double(attempt - 1)) * 300_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }
        
        throw lastError ?? PM2ServiceError.maxRetriesExceeded(arguments.joined(separator: " "))
    }

    private func executePM2CommandSync(arguments: [String]) throws -> String {
        guard FileManager.default.fileExists(atPath: nodePath) else {
            throw PM2ServiceError.nodeNotFound
        }
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw PM2ServiceError.scriptNotFound
        }

        let task = Process()
        task.launchPath = nodePath
        task.arguments = [scriptPath] + arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        task.launch()
        task.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        if task.terminationStatus != 0 {
            if let errorString = String(data: stderrData, encoding: .utf8),
               let errorData = errorString.data(using: .utf8),
               let errorDict = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
               let errorMessage = errorDict["error"] as? String {
                throw PM2ServiceError.commandFailed(errorMessage)
            }
            throw PM2ServiceError.commandFailed("Unknown error")
        }

        guard let output = String(data: stdoutData, encoding: .utf8) else {
            throw PM2ServiceError.invalidResponse
        }
        return output
    }
}
