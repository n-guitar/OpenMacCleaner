import Foundation

/// Scanner for orphaned preference files (.plist files for apps that no longer exist)
public struct OrphanedPrefsScanner: Scanner {
    public let category: CleanupCategory = .brokenPrefs
    
    private let fileManager = FileManager.default
    
    public init() {}
    
    public func scan() async throws -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        let prefsPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences")
        
        guard fileManager.fileExists(atPath: prefsPath.path) else {
            return items
        }
        
        // Get list of installed apps
        let installedApps = getInstalledAppBundleIdentifiers()
        
        guard let enumerator = fileManager.enumerator(
            at: prefsPath,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return items
        }
        
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "plist" else { continue }
            
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            
            // Skip Apple system preferences
            if fileName.hasPrefix("com.apple.") {
                continue
            }
            
            // Skip ByHost preferences
            if fileName.contains(".ByHost.") {
                continue
            }
            
            // Check if this plist belongs to an installed app
            let bundleId = extractBundleIdentifier(from: fileName)
            
            if let bundleId = bundleId, !installedApps.contains(bundleId) {
                // This plist belongs to an app that's not installed
                let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let size = Int64(resourceValues?.fileSize ?? 0)
                let lastModified = resourceValues?.contentModificationDate
                
                let riskLevel = determineRiskLevel(bundleId: bundleId)
                let reason = generateReason(bundleId: bundleId, lastModified: lastModified)
                
                items.append(CleanupItem(
                    path: fileURL,
                    size: size,
                    category: .brokenPrefs,
                    riskLevel: riskLevel,
                    reason: reason,
                    lastModified: lastModified,
                    parentApp: bundleId
                ))
            }
        }
        
        return items
    }
    
    private func getInstalledAppBundleIdentifiers() -> Set<String> {
        var bundleIds = Set<String>()
        
        let appDirs = [
            "/Applications",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for appDir in appDirs {
            guard let apps = try? fileManager.contentsOfDirectory(atPath: appDir) else {
                continue
            }
            
            for app in apps where app.hasSuffix(".app") {
                let appPath = URL(fileURLWithPath: appDir).appendingPathComponent(app)
                let infoPlistPath = appPath.appendingPathComponent("Contents/Info.plist")
                
                if let plist = NSDictionary(contentsOf: infoPlistPath),
                   let bundleId = plist["CFBundleIdentifier"] as? String {
                    bundleIds.insert(bundleId)
                }
            }
        }
        
        return bundleIds
    }
    
    private func extractBundleIdentifier(from fileName: String) -> String? {
        // Common patterns: com.company.AppName, org.company.AppName
        if fileName.hasPrefix("com.") || fileName.hasPrefix("org.") || fileName.hasPrefix("net.") {
            // Take up to 3 components as bundle identifier
            let components = fileName.components(separatedBy: ".")
            if components.count >= 3 {
                return components.prefix(3).joined(separator: ".")
            }
            return fileName
        }
        return nil
    }
    
    private func determineRiskLevel(bundleId: String) -> RiskLevel {
        // Orphaned prefs are generally safe but might contain useful settings
        return .yellow
    }
    
    private func generateReason(bundleId: String, lastModified: Date?) -> LocalizedReason {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if let lastModified = lastModified {
            let dateStr = formatter.string(from: lastModified)
            return LocalizedReason(
                en: "Preference file for '\(bundleId)' - app no longer exists. Last modified: \(dateStr). May contain old settings.",
                ja: "'\(bundleId)' の設定ファイル - アプリは既に存在しません。最終更新: \(dateStr)。古い設定が含まれている可能性があります。"
            )
        }
        
        return LocalizedReason(
            en: "Preference file for '\(bundleId)' - app no longer exists. Can be deleted to clean up old settings.",
            ja: "'\(bundleId)' の設定ファイル - アプリは既に存在しません。古い設定を整理するために削除できます。"
        )
    }
}
