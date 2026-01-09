import Foundation

/// Represents a single item that can be cleaned up
public struct CleanupItem: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let path: URL
    public let size: Int64
    public let category: CleanupCategory
    public let riskLevel: RiskLevel
    public let reason: LocalizedReason
    public let lastAccessed: Date?
    public let lastModified: Date?
    public let parentApp: String?
    
    public init(
        id: UUID = UUID(),
        path: URL,
        size: Int64,
        category: CleanupCategory,
        riskLevel: RiskLevel,
        reason: LocalizedReason,
        lastAccessed: Date? = nil,
        lastModified: Date? = nil,
        parentApp: String? = nil
    ) {
        self.id = id
        self.path = path
        self.size = size
        self.category = category
        self.riskLevel = riskLevel
        self.reason = reason
        self.lastAccessed = lastAccessed
        self.lastModified = lastModified
        self.parentApp = parentApp
    }
    
    /// Formatted size string (e.g., "1.5 MB")
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// Risk level for cleanup items
public enum RiskLevel: String, CaseIterable, Codable, Sendable {
    case green = "safe"
    case yellow = "caution"
    case red = "risky"
    
    public var displayName: String {
        switch self {
        case .green: return "Safe"
        case .yellow: return "Caution"
        case .red: return "Risky"
        }
    }
    
    public var displayNameJa: String {
        switch self {
        case .green: return "安全"
        case .yellow: return "注意"
        case .red: return "危険"
        }
    }
    
    public var emoji: String {
        switch self {
        case .green: return "🟢"
        case .yellow: return "🟡"
        case .red: return "🔴"
        }
    }
    
    public var description: String {
        switch self {
        case .green: return "Deleting this file will not affect your system."
        case .yellow: return "Deleting may reduce convenience. Consider before removing."
        case .red: return "Deleting may require reconfiguration. Proceed with caution."
        }
    }
    
    public var descriptionJa: String {
        switch self {
        case .green: return "削除してもシステムに影響はありません。"
        case .yellow: return "削除すると利便性が下がる可能性があります。"
        case .red: return "削除すると再設定が必要になる可能性があります。"
        }
    }
}

/// Category of cleanup items
public enum CleanupCategory: String, CaseIterable, Codable, Sendable {
    case userCache = "user_cache"
    case logs = "logs"
    case orphanedAppData = "orphaned_app_data"
    case brokenPrefs = "broken_prefs"
    case localizations = "localizations" // Keep for compatibility if needed
    case downloads = "downloads"
    case trash = "trash"
    case largeFiles = "large_files"
    case applications = "applications"
    
    public var displayName: String {
        switch self {
        case .userCache: return "User Cache"
        case .logs: return "User Logs"
        case .orphanedAppData: return "Orphaned App Data"
        case .brokenPrefs: return "Broken Preferences"
        case .localizations: return "Unused Languages"
        case .downloads: return "Downloads"
        case .trash: return "Trash"
        case .largeFiles: return "Large Files"
        case .applications: return "Applications"
        }
    }
    
    public var displayNameJa: String {
        switch self {
        case .userCache: return "ユーザーキャッシュ"
        case .logs: return "ユーザーログ"
        case .orphanedAppData: return "未使用アプリデータ"
        case .brokenPrefs: return "壊れた環境設定"
        case .localizations: return "未使用言語"
        case .downloads: return "ダウンロード"
        case .trash: return "ゴミ箱"
        case .largeFiles: return "大容量ファイル"
        case .applications: return "アプリケーション"
        }
    }
    
    public var icon: String {
        switch self {
        case .userCache: return "archivebox"
        case .logs: return "doc.text"
        case .orphanedAppData: return "app.badge.checkmark"
        case .brokenPrefs: return "gear"
        case .localizations: return "globe"
        case .downloads: return "arrow.down.circle"
        case .trash: return "trash"
        case .largeFiles: return "arrow.up.left.and.arrow.down.right.circle"
        case .applications: return "app.fill"
        }
    }
}

/// Localized reason for deletion
public struct LocalizedReason: Hashable, Codable, Sendable {
    public let en: String
    public let ja: String
    
    public init(en: String, ja: String) {
        self.en = en
        self.ja = ja
    }
    
    public func localized(for locale: Locale = .current) -> String {
        if locale.language.languageCode?.identifier == "ja" {
            return ja
        }
        return en
    }
}
