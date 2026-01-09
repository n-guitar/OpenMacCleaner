import Foundation

/// Scanner for user cache files in ~/Library/Caches
public struct CacheScanner: Scanner {
    public let category: CleanupCategory = .userCache
    
    private let fileManager = FileManager.default
    
    public init() {}
    
    public func scan() async throws -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        // User Caches
        let userCachesPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches")
        
        if fileManager.fileExists(atPath: userCachesPath.path) {
            let cacheItems = try await scanDirectory(userCachesPath)
            items.append(contentsOf: cacheItems)
        }
        
        return items
    }
    
    private func scanDirectory(_ directory: URL) async throws -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .contentAccessDateKey,
                .contentModificationDateKey,
                .isDirectoryKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return items
        }
        
        // Group files by app (top-level directory in Caches)
        var appCaches: [String: (size: Int64, files: [URL], lastAccessed: Date?)] = [:]
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [
                .fileSizeKey,
                .contentAccessDateKey,
                .isDirectoryKey
            ]) else {
                continue
            }
            
            let isDirectory = resourceValues.isDirectory ?? false
            if isDirectory {
                continue
            }
            
            let size = Int64(resourceValues.fileSize ?? 0)
            let lastAccessed = resourceValues.contentAccessDate
            
            // Get app name from path (first component after Caches/)
            let relativePath = fileURL.path.replacingOccurrences(
                of: directory.path + "/",
                with: ""
            )
            let appName = relativePath.components(separatedBy: "/").first ?? "Unknown"
            
            var entry = appCaches[appName] ?? (size: 0, files: [], lastAccessed: nil)
            entry.size += size
            entry.files.append(fileURL)
            if let accessed = lastAccessed {
                if entry.lastAccessed == nil || accessed > entry.lastAccessed! {
                    entry.lastAccessed = accessed
                }
            }
            appCaches[appName] = entry
        }
        
        // Create cleanup items for each app's cache
        for (appName, data) in appCaches where data.size > 0 {
            let appCacheDir = directory.appendingPathComponent(appName)
            let riskLevel = determineRiskLevel(appName: appName, lastAccessed: data.lastAccessed)
            let reason = generateReason(appName: appName, lastAccessed: data.lastAccessed, size: data.size)
            
            items.append(CleanupItem(
                path: appCacheDir,
                size: data.size,
                category: .userCache,
                riskLevel: riskLevel,
                reason: reason,
                lastAccessed: data.lastAccessed,
                parentApp: appName
            ))
        }
        
        return items
    }
    
    private func determineRiskLevel(appName: String, lastAccessed: Date?) -> RiskLevel {
        // System caches that are frequently regenerated are safe
        let safePatterns = [
            "com.apple.",
            "CloudKit",
            "Metadata",
            "Safari" // Safari cache can be safely cleared
        ]
        
        for pattern in safePatterns {
            if appName.contains(pattern) {
                return .green
            }
        }
        
        // Old caches (not accessed in 30+ days) are generally safe
        if let lastAccessed = lastAccessed {
            let daysSinceAccess = Calendar.current.dateComponents(
                [.day],
                from: lastAccessed,
                to: Date()
            ).day ?? 0
            
            if daysSinceAccess > 30 {
                return .green
            }
        }
        
        // Recent caches might affect app performance
        return .yellow
    }
    
    private func generateReason(appName: String, lastAccessed: Date?, size: Int64) -> LocalizedReason {
        let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        
        if let lastAccessed = lastAccessed {
            let daysSinceAccess = Calendar.current.dateComponents(
                [.day],
                from: lastAccessed,
                to: Date()
            ).day ?? 0
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            let dateStr = formatter.string(from: lastAccessed)
            
            if daysSinceAccess > 30 {
                return LocalizedReason(
                    en: "Cache for '\(appName)' (\(sizeStr)) hasn't been accessed in \(daysSinceAccess) days (since \(dateStr)). Safe to delete.",
                    ja: "'\(appName)' のキャッシュ（\(sizeStr)）は \(daysSinceAccess) 日間アクセスされていません（最終: \(dateStr)）。削除しても安全です。"
                )
            } else {
                return LocalizedReason(
                    en: "Cache for '\(appName)' (\(sizeStr)) was last accessed on \(dateStr). The app may need to rebuild cache after deletion.",
                    ja: "'\(appName)' のキャッシュ（\(sizeStr)）は \(dateStr) に最後にアクセスされました。削除後、アプリがキャッシュを再構築する可能性があります。"
                )
            }
        }
        
        return LocalizedReason(
            en: "Cache for '\(appName)' (\(sizeStr)). Can be safely deleted; the app will recreate it as needed.",
            ja: "'\(appName)' のキャッシュ（\(sizeStr)）。削除しても、アプリが必要に応じて再作成します。"
        )
    }
}
