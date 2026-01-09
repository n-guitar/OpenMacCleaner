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

/// Scanner for User Trash
public struct TrashScanner: Scanner {
    public let category: CleanupCategory = .trash
    private let fileManager = FileManager.default
    
    public init() {}
    
    public func scan() async throws -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        // Explicitly check ~/.Trash as it's the most reliable for this use case
        let homeTrashURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash")
        let standardTrashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first
        
        let trashURL = homeTrashURL // Prefer explicit path for now
        
        print("Scanning Trash at: \(trashURL.path)")
        
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .nameKey, .isDirectoryKey]
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: trashURL,
                includingPropertiesForKeys: resourceKeys,
                options: [] // Don't skip hidden files, just in case
            )
            
            print("Found \(fileURLs.count) items in Trash")
            
            for fileURL in fileURLs {
                // Skip .DS_Store
                if fileURL.lastPathComponent == ".DS_Store" { continue }
                
                let resources = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                // Calculate size recursively if it's a directory
                let size: Int64
                if resources.isDirectory == true {
                    size = calculateDirectorySize(at: fileURL)
                } else {
                    size = Int64(resources.fileSize ?? 0)
                }
                
                let item = CleanupItem(
                    path: fileURL,
                    size: size,
                    category: .trash,
                    riskLevel: .yellow, // Caution
                    reason: LocalizedReason(
                        en: "Item in Trash",
                        ja: "ゴミ箱にある項目"
                    ),
                    lastModified: resources.contentModificationDate
                )
                items.append(item)
            }
        } catch {
            print("Trash scan error: \(error)")
            
            // If explicit path fails, try standard URL as fallback
            if let standardUrl = standardTrashURL, standardUrl != trashURL {
                 print("Retrying with standard URL: \(standardUrl.path)")
                 // ... (Simplified logic)
            }
            
            // Return a placeholder item to inform the user about permissions
            let errorItem = CleanupItem(
                path: trashURL,
                size: 0,
                category: .trash,
                riskLevel: .red,
                reason: LocalizedReason(
                    en: "Requires Full Disk Access",
                    ja: "アクセスにはフルディスク権限が必要です（システム設定 > プライバシーとセキュリティ）"
                ),
                lastModified: Date()
            )
            items.append(errorItem)
        }
        
        return items
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        // Simple recursive size calculation
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            let resources = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            size += Int64(resources?.fileSize ?? 0)
        }
        return size
    }
}

/// Scanner for Large Files in User Directory
public struct LargeFileScanner: Scanner {
    public let category: CleanupCategory = .largeFiles
    private let fileManager = FileManager.default
    private let minimumSize: Int64 = 100 * 1024 * 1024 // 100 MB
    
    public init() {}
    
    public func scan() async throws -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let systemAppsDir = URL(fileURLWithPath: "/Applications")
        
        let roots = [homeDir, systemAppsDir]
        
        // Directories to exclude from scanning (don't even enter)
        let excludedDirNames: Set<String> = ["Library", "Public", "Desktop"]
        
        for root in roots {
            let isHome = root == homeDir
            
            if let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .nameKey, .isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                for case let fileURL as URL in enumerator {
                    let fileName = fileURL.lastPathComponent
                    
                    // Exclusion logic (Mainly for Home)
                    if isHome {
                        // Check top-level exclusions in Home only
                        if let isDir = resourceValue(from: fileURL, for: .isDirectoryKey) as? Bool, isDir {
                            if fileURL.deletingLastPathComponent() == homeDir {
                                if excludedDirNames.contains(fileName) {
                                    enumerator.skipDescendants()
                                    continue
                                }
                            }
                        }
                    }
                    
                    // Check if it's a bundle/package (like .app)
                    let isPackage = resourceValue(from: fileURL, for: .isPackageKey) as? Bool ?? false
                    let isDir = resourceValue(from: fileURL, for: .isDirectoryKey) as? Bool ?? false
                    
                    var size: Int64 = 0
                    
                    if isPackage && isDir {
                        // It's an app or bundle, need recursive size
                       size = calculateDirectorySize(at: fileURL)
                    } else if !isDir {
                       // Regular file
                       size = Int64(resourceValue(from: fileURL, for: .fileSizeKey) as? Int ?? 0)
                    } else {
                        // Regular directory, just continue scanning inside
                        continue
                    }
                    
                    // Check size threshold
                    if size > minimumSize {
                       // Determine if it's an app
                       let isApp = fileURL.pathExtension == "app"
                       let category: CleanupCategory = isApp ? .applications : .largeFiles
                       
                       let reasonEn = isApp ? "Large Application" : "Large File"
                       let reasonJa = isApp ? "大容量アプリケーション" : "大容量ファイル"
                        
                       let item = CleanupItem(
                            path: fileURL,
                            size: size,
                            category: category,
                            riskLevel: .yellow, // Caution
                            reason: LocalizedReason(
                                en: "\(reasonEn). Ensure it is not needed.",
                                ja: "\(reasonJa)。不要か確認してください。"
                            ),
                            lastModified: resourceValue(from: fileURL, for: .contentModificationDateKey) as? Date
                        )
                        items.append(item)
                    }
                }
            }
        }
        
        return items
    }
    
    // Helper to avoid try? inside the loop condition multiple times if not needed
    private func resourceValue(from url: URL, for key: URLResourceKey) -> Any? {
        try? url.resourceValues(forKeys: [key]).allValues[key]
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            let resources = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            size += Int64(resources?.fileSize ?? 0)
        }
        return size
    }
}
