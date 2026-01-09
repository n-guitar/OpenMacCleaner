import Foundation

/// Protocol that all scanners must implement
public protocol Scanner: Sendable {
    /// The category this scanner handles
    var category: CleanupCategory { get }
    
    /// Scan for cleanup items
    func scan() async throws -> [CleanupItem]
}

/// Main scan engine that orchestrates all scanners
public actor ScanEngine {
    private var scanners: [any Scanner] = []
    private var isScanning = false
    
    public init() {}
    
    /// Register a scanner
    public func register(_ scanner: any Scanner) {
        scanners.append(scanner)
    }
    
    /// Register multiple scanners
    public func register(_ scanners: [any Scanner]) {
        self.scanners.append(contentsOf: scanners)
    }
    
    /// Run all registered scanners
    public func scan(categories: [CleanupCategory]? = nil) async throws -> ScanResult {
        guard !isScanning else {
            throw ScanError.alreadyScanning
        }
        
        isScanning = true
        defer { isScanning = false }
        
        let startTime = Date()
        let activeScanners: [any Scanner]
        
        if let categories = categories {
            activeScanners = scanners.filter { categories.contains($0.category) }
        } else {
            activeScanners = scanners
        }
        
        // Run all scanners concurrently
        var allItems: [CleanupItem] = []
        
        try await withThrowingTaskGroup(of: [CleanupItem].self) { group in
            for scanner in activeScanners {
                group.addTask {
                    try await scanner.scan()
                }
            }
            
            for try await items in group {
                allItems.append(contentsOf: items)
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let scannedCategories = activeScanners.map(\.category)
        
        return ScanResult(
            items: allItems.sorted { $0.size > $1.size },
            scanDuration: duration,
            scannedCategories: scannedCategories
        )
    }
    
    /// Check if currently scanning
    public func isScanningNow() -> Bool {
        isScanning
    }
}

/// Scan errors
public enum ScanError: Error, LocalizedError {
    case alreadyScanning
    case accessDenied(path: String)
    case invalidPath(path: String)
    
    public var errorDescription: String? {
        switch self {
        case .alreadyScanning:
            return "A scan is already in progress"
        case .accessDenied(let path):
            return "Access denied to: \(path)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        }
    }
}
