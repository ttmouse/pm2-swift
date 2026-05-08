import Foundation

struct ProjectMetadata: Codable {
    var tags: [String] = []
    var notes: String = ""
    var autoStart: Bool = false
    var priority: Priority = .medium
}
