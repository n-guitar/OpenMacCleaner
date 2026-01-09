import Foundation

/// Safety manager for handling deletions with protection mechanisms
public actor SafetyManager {
    private let fileManager = FileManager.default
    
    /// Items that should never be deleted
    private var whitelist: Set<String> = []
    
    public init() {
        loadDefaultWhitelist()
    }
    
    // MARK: - Whitelist Management
    
    private func loadDefaultWhitelist() {
        // Apple system components
        // whitelist.insert("com.apple") // Too restrictive for caches
        // whitelist.insert("Apple")     // Too restrictive
        
        // Security software
        whitelist.insert("com.malwarebytes")
        whitelist.insert("com.crowdstrike")
        whitelist.insert("com.symantec")
        whitelist.insert("com.kaspersky")
        whitelist.insert("com.f-secure")
        whitelist.insert("com.avast")
        whitelist.insert("com.avg")
        whitelist.insert("com.eset")
        
        // Critical directories (should never delete contents)
        whitelist.insert("Keychains")
        whitelist.insert("Security")
    }
    
    public func addToWhitelist(_ pattern: String) {
        whitelist.insert(pattern)
    }
    
    public func removeFromWhitelist(_ pattern: String) {
        whitelist.remove(pattern)
    }
    
    public func isWhitelisted(_ item: CleanupItem) -> Bool {
        let path = item.path.path
        
        for pattern in whitelist {
            if path.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Deletion Operations
    
    /// Move items to trash (soft delete)
    public func moveToTrash(_ items: [CleanupItem]) async throws -> [CleanupResult] {
        var results: [CleanupResult] = []
        
        for item in items {
            // Check whitelist
            if isWhitelisted(item) {
                results.append(CleanupResult(
                    item: item,
                    success: false,
                    error: "Item is protected by whitelist"
                ))
                continue
            }
            
            do {
                var trashedURL: NSURL?
                try fileManager.trashItem(at: item.path, resultingItemURL: &trashedURL)
                
                results.append(CleanupResult(
                    item: item,
                    success: true,
                    trashedURL: trashedURL as URL?
                ))
            } catch {
                results.append(CleanupResult(
                    item: item,
                    success: false,
                    error: error.localizedDescription
                ))
            }
        }
        
        return results
    }
    
    /// Create APFS local snapshot before cleanup (requires sudo)
    public func createSnapshot() async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["localsnapshot"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            throw SafetyError.snapshotFailed(output)
        }
        
        return output
    }
}

/// Result of a cleanup operation
public struct CleanupResult: Sendable {
    public let item: CleanupItem
    public let success: Bool
    public let trashedURL: URL?
    public let error: String?
    
    public init(item: CleanupItem, success: Bool, trashedURL: URL? = nil, error: String? = nil) {
        self.item = item
        self.success = success
        self.trashedURL = trashedURL
        self.error = error
    }
}

/// Safety-related errors
public enum SafetyError: Error, LocalizedError {
    case snapshotFailed(String)
    case whitelistedItem
    case accessDenied
    
    public var errorDescription: String? {
        switch self {
        case .snapshotFailed(let message):
            return "Failed to create snapshot: \(message)"
        case .whitelistedItem:
            return "Item is protected and cannot be deleted"
        case .accessDenied:
            return "Access denied to perform this operation"
        }
    }
}
