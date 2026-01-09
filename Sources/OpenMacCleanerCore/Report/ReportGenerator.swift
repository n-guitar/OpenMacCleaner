import Foundation

/// Generates reports from scan results in various formats
public struct ReportGenerator {
    public enum Format {
        case json
        case markdown
    }
    
    public enum Language {
        case english
        case japanese
    }
    
    private let format: Format
    private let language: Language
    
    public init(format: Format = .markdown, language: Language = .english) {
        self.format = format
        self.language = language
    }
    
    public func generate(from result: ScanResult) throws -> String {
        switch format {
        case .json:
            return try generateJSON(from: result)
        case .markdown:
            return generateMarkdown(from: result)
        }
    }
    
    // MARK: - JSON Generation
    
    private func generateJSON(from result: ScanResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(result)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    // MARK: - Markdown Generation
    
    private func generateMarkdown(from result: ScanResult) -> String {
        var lines: [String] = []
        
        // Header
        if language == .japanese {
            lines.append("# 🔍 Open Mac Cleaner スキャンレポート")
            lines.append("")
            lines.append(formatDate(result.scanDate))
            lines.append("")
        } else {
            lines.append("# 🔍 Open Mac Cleaner Scan Report")
            lines.append("")
            lines.append(formatDate(result.scanDate))
            lines.append("")
        }
        
        // Summary
        lines.append(generateSummary(result))
        lines.append("")
        
        // Risk Level Summary
        lines.append(generateRiskLevelSummary(result))
        lines.append("")
        
        // Items by Category
        lines.append(generateCategoryBreakdown(result))
        lines.append("")
        
        // Detailed Items
        lines.append(generateDetailedItems(result))
        
        return lines.joined(separator: "\n")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        if language == .japanese {
            formatter.locale = Locale(identifier: "ja_JP")
        }
        return formatter.string(from: date)
    }
    
    private func generateSummary(_ result: ScanResult) -> String {
        let header = language == .japanese ? "## 📊 サマリー" : "## 📊 Summary"
        let duration = String(format: "%.2f", result.scanDuration)
        
        var lines = [header, ""]
        
        if language == .japanese {
            lines.append("| 項目 | 値 |")
            lines.append("|------|-----|")
            lines.append("| 検出アイテム数 | \(result.items.count) |")
            lines.append("| 合計サイズ | \(result.formattedTotalSize) |")
            lines.append("| スキャン時間 | \(duration)秒 |")
            lines.append("| 安全に削除可能 | \(ByteCountFormatter.string(fromByteCount: result.safeTotalSize, countStyle: .file)) |")
        } else {
            lines.append("| Property | Value |")
            lines.append("|----------|-------|")
            lines.append("| Items Found | \(result.items.count) |")
            lines.append("| Total Size | \(result.formattedTotalSize) |")
            lines.append("| Scan Duration | \(duration)s |")
            lines.append("| Safe to Delete | \(ByteCountFormatter.string(fromByteCount: result.safeTotalSize, countStyle: .file)) |")
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func generateRiskLevelSummary(_ result: ScanResult) -> String {
        let header = language == .japanese ? "## 🚦 リスクレベル別" : "## 🚦 Risk Level Breakdown"
        var lines = [header, ""]
        
        for level in RiskLevel.allCases {
            let items = result.items.filter { $0.riskLevel == level }
            let size = items.reduce(0) { $0 + $1.size }
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            
            let name = language == .japanese ? level.displayNameJa : level.displayName
            lines.append("- \(level.emoji) **\(name)**: \(items.count) items (\(sizeStr))")
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func generateCategoryBreakdown(_ result: ScanResult) -> String {
        let header = language == .japanese ? "## 📁 カテゴリ別" : "## 📁 Category Breakdown"
        var lines = [header, ""]
        
        let itemsByCategory = result.itemsByCategory
        
        for category in CleanupCategory.allCases {
            guard let items = itemsByCategory[category], !items.isEmpty else { continue }
            
            let size = items.reduce(0) { $0 + $1.size }
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            let name = language == .japanese ? category.displayNameJa : category.displayName
            
            lines.append("### \(name)")
            lines.append("")
            lines.append("\(items.count) items, \(sizeStr)")
            lines.append("")
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func generateDetailedItems(_ result: ScanResult) -> String {
        let header = language == .japanese ? "## 📋 詳細リスト" : "## 📋 Detailed Items"
        var lines = [header, ""]
        
        // Group by risk level for easier reading
        for level in RiskLevel.allCases {
            let items = result.items.filter { $0.riskLevel == level }
            guard !items.isEmpty else { continue }
            
            let levelName = language == .japanese ? level.displayNameJa : level.displayName
            lines.append("### \(level.emoji) \(levelName)")
            lines.append("")
            
            // Show top 20 per category to keep report manageable
            for item in items.prefix(20) {
                let reason = language == .japanese ? item.reason.ja : item.reason.en
                lines.append("- **\(item.path.lastPathComponent)** (\(item.formattedSize))")
                lines.append("  - Path: `\(item.path.path)`")
                lines.append("  - \(reason)")
                lines.append("")
            }
            
            if items.count > 20 {
                let more = language == .japanese ? "...他 \(items.count - 20) 件" : "...and \(items.count - 20) more"
                lines.append("*\(more)*")
                lines.append("")
            }
        }
        
        return lines.joined(separator: "\n")
    }
}
