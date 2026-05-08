import Foundation

// MARK: - Port Range
struct PortRange: Codable, Equatable {
    let lower: Int
    let upper: Int
    
    var closedRange: ClosedRange<Int> { lower...upper }
    
    init(_ range: ClosedRange<Int>) {
        self.lower = range.lowerBound
        self.upper = range.upperBound
    }
    
    // Convenience initializer for direct lower/upper values
    init(lower: Int, upper: Int) {
        self.lower = lower
        self.upper = upper
    }
}

// MARK: - Thread-safe Port Pool Manager
actor PortPoolManager {
    private var usedPorts: Set<Int> = []
    private let apiRange: ClosedRange<Int>
    private let frontendRange: ClosedRange<Int>
    
    init(apiRange: ClosedRange<Int> = 18920...18999,
         frontendRange: ClosedRange<Int> = 15920...15999) {
        self.apiRange = apiRange
        self.frontendRange = frontendRange
    }
    
    func allocatePort(category: ServiceCategory) -> Int? {
        let range = category == .api || category == .database ? apiRange : frontendRange
        for port in range {
            if !usedPorts.contains(port) && !isPortInUse(port) {
                usedPorts.insert(port)
                return port
            }
        }
        return nil
    }
    
    func releasePort(_ port: Int) {
        usedPorts.remove(port)
    }
    
    func markPortUsed(_ port: Int) {
        usedPorts.insert(port)
    }
    
    func getUsedPorts() -> Set<Int> {
        return usedPorts
    }
    
    func reset() {
        usedPorts.removeAll()
    }
    
    nonisolated private func isPortInUse(_ port: Int) -> Bool {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        task.waitUntilExit()
        
        return task.terminationStatus == 0
    }
}

// MARK: - Port Pool (Codable struct for persistence)
struct PortPool: Codable {
    var apiRange: PortRange
    var frontendRange: PortRange
    var usedPorts: Set<Int>
    
    init(apiRange: ClosedRange<Int> = 18920...18999,
         frontendRange: ClosedRange<Int> = 15920...15999,
         usedPorts: Set<Int> = []) {
        self.apiRange = PortRange(apiRange)
        self.frontendRange = PortRange(frontendRange)
        self.usedPorts = usedPorts
    }
    
    // Codable: use PortRange instead of ClosedRange<Int>
    enum CodingKeys: String, CodingKey {
        case apiRangeLower, apiRangeUpper
        case frontendRangeLower, frontendRangeUpper
        case usedPorts
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let apiLower = try container.decode(Int.self, forKey: .apiRangeLower)
        let apiUpper = try container.decode(Int.self, forKey: .apiRangeUpper)
        self.apiRange = PortRange(lower: apiLower, upper: apiUpper)
        let feLower = try container.decode(Int.self, forKey: .frontendRangeLower)
        let feUpper = try container.decode(Int.self, forKey: .frontendRangeUpper)
        self.frontendRange = PortRange(lower: feLower, upper: feUpper)
        self.usedPorts = try container.decode(Set<Int>.self, forKey: .usedPorts)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(apiRange.lower, forKey: .apiRangeLower)
        try container.encode(apiRange.upper, forKey: .apiRangeUpper)
        try container.encode(frontendRange.lower, forKey: .frontendRangeLower)
        try container.encode(frontendRange.upper, forKey: .frontendRangeUpper)
        try container.encode(usedPorts, forKey: .usedPorts)
    }
}
