import Foundation

// MARK: - Port Pool
struct PortPool: Codable {
    let apiRange: ClosedRange<Int>
    let frontendRange: ClosedRange<Int>
    var usedPorts: Set<Int>
    
    init(apiRange: ClosedRange<Int> = 18920...18999,
         frontendRange: ClosedRange<Int> = 15920...15999,
         usedPorts: Set<Int> = []) {
        self.apiRange = apiRange
        self.frontendRange = frontendRange
        self.usedPorts = usedPorts
    }
    
    mutating func allocatePort(category: ServiceCategory) -> Int? {
        let range = category == .api || category == .database ? apiRange : frontendRange
        for port in range {
            if !usedPorts.contains(port) && !isPortInUse(port) {
                usedPorts.insert(port)
                return port
            }
        }
        return nil
    }
    
    mutating func releasePort(_ port: Int) {
        usedPorts.remove(port)
    }
    
    func isPortInUse(_ port: Int) -> Bool {
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
    
    func findAvailablePort(in range: ClosedRange<Int>) -> Int? {
        for port in range {
            if !usedPorts.contains(port) && !isPortInUse(port) {
                return port
            }
        }
        return nil
    }
}
