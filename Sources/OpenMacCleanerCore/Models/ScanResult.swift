import Foundation

/// Result of a scan operation
public struct ScanResult: Identifiable, Codable, Sendable {
    public let id: UUID
    public let items: [CleanupItem]
    public let scanDate: Date
    public let scanDuration: TimeInterval
    public let scannedCategories: [CleanupCategory]
    
    public init(
        id: UUID = UUID(),
        items: [CleanupItem],
        scanDate: Date = Date(),
        scanDuration: TimeInterval,
        scannedCategories: [CleanupCategory]
    ) {
        self.id = id
        self.items = items
        self.scanDate = scanDate
        self.scanDuration = scanDuration
        self.scannedCategories = scannedCategories
    }
    
    /// Total size of all items
    public var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    /// Formatted total size
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    /// Items grouped by category
    public var itemsByCategory: [CleanupCategory: [CleanupItem]] {
        Dictionary(grouping: items, by: \.category)
    }
    
    /// Items grouped by risk level
    public var itemsByRiskLevel: [RiskLevel: [CleanupItem]] {
        Dictionary(grouping: items, by: \.riskLevel)
    }
    
    /// Count of items by risk level
    public var riskLevelCounts: [RiskLevel: Int] {
        itemsByRiskLevel.mapValues { $0.count }
    }
    
    /// Total size by risk level
    public var sizeByRiskLevel: [RiskLevel: Int64] {
        itemsByRiskLevel.mapValues { items in
            items.reduce(0) { $0 + $1.size }
        }
    }
    
    /// Only safe (green) items
    public var safeItems: [CleanupItem] {
        items.filter { $0.riskLevel == .green }
    }
    
    /// Total size of safe items
    public var safeTotalSize: Int64 {
        safeItems.reduce(0) { $0 + $1.size }
    }
}
