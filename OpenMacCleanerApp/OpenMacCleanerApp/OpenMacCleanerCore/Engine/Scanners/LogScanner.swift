import Foundation

/// Scanner for log files in ~/Library/Logs
public struct LogScanner: Scanner {
    public let category: CleanupCategory = .logs
    
    private let fileManager = FileManager.default
    
    /// Age threshold in days for considering logs as safe to delete
    private let safeAgeDays: Int = 7
    
    public init() {}
    
    public func scan() async throws -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        // User Logs
        let userLogsPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
        
        if fileManager.fileExists(atPath: userLogsPath.path) {
            let logItems = try await scanDirectory(userLogsPath)
            items.append(contentsOf: logItems)
        }
        
        return items
    }
    
    private func scanDirectory(_ directory: URL) async throws -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .isDirectoryKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return items
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .isDirectoryKey
            ]) else {
                continue
            }
            
            let isDirectory = resourceValues.isDirectory ?? false
            if isDirectory {
                continue
            }
            
            // Only include log files
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "log" || ext == "txt" || ext == "crash" || ext == "diag" else {
                continue
            }
            
            let size = Int64(resourceValues.fileSize ?? 0)
            let lastModified = resourceValues.contentModificationDate
            
            // Skip very small files
            guard size > 1024 else { // > 1KB
                continue
            }
            
            let riskLevel = determineRiskLevel(fileURL: fileURL, lastModified: lastModified)
            let reason = generateReason(fileURL: fileURL, lastModified: lastModified, size: size)
            let parentApp = extractAppName(from: fileURL)
            
            items.append(CleanupItem(
                path: fileURL,
                size: size,
                category: .logs,
                riskLevel: riskLevel,
                reason: reason,
                lastModified: lastModified,
                parentApp: parentApp
            ))
        }
        
        return items
    }
    
    private func determineRiskLevel(fileURL: URL, lastModified: Date?) -> RiskLevel {
        let ext = fileURL.pathExtension.lowercased()
        
        // Crash reports are informational and safe to delete
        if ext == "crash" || ext == "diag" {
            return .green
        }
        
        // Old logs are safe
        if let lastModified = lastModified {
            let daysSinceModified = Calendar.current.dateComponents(
                [.day],
                from: lastModified,
                to: Date()
            ).day ?? 0
            
            if daysSinceModified > safeAgeDays {
                return .green
            }
        }
        
        // Recent logs might be useful for debugging
        return .yellow
    }
    
    private func generateReason(fileURL: URL, lastModified: Date?, size: Int64) -> LocalizedReason {
        let fileName = fileURL.lastPathComponent
        let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        let ext = fileURL.pathExtension.lowercased()
        
        if ext == "crash" {
            return LocalizedReason(
                en: "Crash report '\(fileName)' (\(sizeStr)). Old crash reports can be safely deleted.",
                ja: "クラッシュレポート '\(fileName)'（\(sizeStr)）。古いクラッシュレポートは削除しても安全です。"
            )
        }
        
        if let lastModified = lastModified {
            let daysSinceModified = Calendar.current.dateComponents(
                [.day],
                from: lastModified,
                to: Date()
            ).day ?? 0
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            let dateStr = formatter.string(from: lastModified)
            
            if daysSinceModified > safeAgeDays {
                return LocalizedReason(
                    en: "Log file '\(fileName)' (\(sizeStr)) was last modified \(daysSinceModified) days ago. Old logs are safe to delete.",
                    ja: "ログファイル '\(fileName)'（\(sizeStr)）は \(daysSinceModified) 日前に最終更新されました。古いログは削除しても安全です。"
                )
            } else {
                return LocalizedReason(
                    en: "Log file '\(fileName)' (\(sizeStr)) was modified recently (\(dateStr)). May contain useful debugging information.",
                    ja: "ログファイル '\(fileName)'（\(sizeStr)）は最近更新されました（\(dateStr)）。デバッグに有用な情報が含まれている可能性があります。"
                )
            }
        }
        
        return LocalizedReason(
            en: "Log file '\(fileName)' (\(sizeStr)). Log files can be deleted to free up space.",
            ja: "ログファイル '\(fileName)'（\(sizeStr)）。ログファイルは削除して容量を解放できます。"
        )
    }
    
    private func extractAppName(from url: URL) -> String? {
        // Try to extract app name from path
        let pathComponents = url.pathComponents
        
        // Look for typical patterns like com.apple.XYZ or AppName
        for component in pathComponents {
            if component.hasPrefix("com.") || component.hasPrefix("org.") {
                // Extract app name from bundle identifier
                let parts = component.components(separatedBy: ".")
                if parts.count >= 3 {
                    return parts.dropFirst(2).joined(separator: ".")
                }
            }
        }
        
        // Try parent directory name
        let parent = url.deletingLastPathComponent().lastPathComponent
        if parent != "Logs" && parent != "Library" {
            return parent
        }
        
        return nil
    }
}
