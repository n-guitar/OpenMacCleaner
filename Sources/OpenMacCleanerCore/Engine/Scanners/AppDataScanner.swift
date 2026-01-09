import Foundation

/// Scanner for Application Support data from apps that no longer exist
public struct AppDataScanner: Scanner {
    public let category: CleanupCategory = .orphanedAppData
    
    private let fileManager = FileManager.default
    
    public init() {}
    
    public func scan() async throws -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        let installedApps = getInstalledAppBundleIdentifiers()
        
        // NOTE: Application Support scan disabled for safety
        // Folder names don't reliably match app names, leading to false positives
        // Only Containers are scanned (bundle ID based, reliable matching)
        
        // Scan Containers only (bundle ID = folder name, reliable)
        let containersPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers")
        
        if fileManager.fileExists(atPath: containersPath.path) {
            items.append(contentsOf: try await scanContainers(containersPath, installedApps: installedApps))
        }
        
        return items
    }
    
    private func scanApplicationSupport(_ directory: URL, installedApps: Set<String>) async throws -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return items
        }
        
        for itemURL in contents {
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues?.isDirectory == true else { continue }
            
            let dirName = itemURL.lastPathComponent
            
            // Skip Apple system directories
            if dirName.hasPrefix("com.apple.") || dirName == "Apple" {
                continue
            }
            
            // Check if this looks like a bundle identifier
            let bundleId = extractBundleIdentifier(from: dirName)
            
            if let bundleId = bundleId, !installedApps.contains(bundleId) {
                // This directory belongs to an uninstalled app
                let size = try await calculateDirectorySize(itemURL)
                
                if size > 1_000_000 { // Only include if > 1MB
                    let reason = generateReason(for: bundleId, location: "Application Support")
                    
                    items.append(CleanupItem(
                        path: itemURL,
                        size: size,
                        category: .orphanedAppData,
                        riskLevel: .yellow,
                        reason: reason,
                        parentApp: bundleId
                    ))
                }
            }
        }
        
        return items
    }
    
    private func scanContainers(_ directory: URL, installedApps: Set<String>) async throws -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return items
        }
        
        for itemURL in contents {
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues?.isDirectory == true else { continue }
            
            let dirName = itemURL.lastPathComponent
            
            // Skip Apple containers
            if dirName.hasPrefix("com.apple.") {
                continue
            }
            
            // Container directories are named by bundle identifier
            if !installedApps.contains(dirName) {
                let size = try await calculateDirectorySize(itemURL)
                
                if size > 1_000_000 { // Only include if > 1MB
                    let reason = generateReason(for: dirName, location: "Containers")
                    
                    items.append(CleanupItem(
                        path: itemURL,
                        size: size,
                        category: .orphanedAppData,
                        riskLevel: .yellow,
                        reason: reason,
                        parentApp: dirName
                    ))
                }
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
                    
                    // Add app name (without .app)
                    let appName = app.replacingOccurrences(of: ".app", with: "")
                    bundleIds.insert(appName)
                    
                    // Add vendor name from bundle ID (e.g., "com.google.Chrome" -> "Google")
                    let parts = bundleId.split(separator: ".")
                    if parts.count >= 2 {
                        let vendor = String(parts[1]).capitalized
                        bundleIds.insert(vendor)
                    }
                    
                    // Add last component of bundle ID (e.g., "com.googlecode.iterm2" -> "iterm2", "iTerm2")
                    if let lastPart = parts.last {
                        let name = String(lastPart)
                        bundleIds.insert(name)
                        bundleIds.insert(name.capitalized)
                        bundleIds.insert(name.uppercased())
                        // Handle camelCase variations
                        bundleIds.insert(name.prefix(1).uppercased() + name.dropFirst())
                    }
                    
                    // Add common variations of app names
                    // "Visual Studio Code" -> "Code", "VSCode"
                    let words = appName.split(separator: " ")
                    for word in words {
                        bundleIds.insert(String(word))
                    }
                    
                    // Add CFBundleName if available
                    if let bundleName = plist["CFBundleName"] as? String {
                        bundleIds.insert(bundleName)
                    }
                }
            }
        }
        
        return bundleIds
    }
    
    private func extractBundleIdentifier(from dirName: String) -> String? {
        // Common patterns: com.company.AppName, org.company.AppName
        if dirName.hasPrefix("com.") || dirName.hasPrefix("org.") || dirName.hasPrefix("net.") || dirName.hasPrefix("io.") {
            return dirName
        }
        return dirName // Treat directory name as potential app identifier
    }
    
    private func calculateDirectorySize(_ directory: URL) async throws -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if resourceValues?.isDirectory == false {
                totalSize += Int64(resourceValues?.fileSize ?? 0)
            }
        }
        
        return totalSize
    }
    
    private func generateReason(for bundleId: String, location: String) -> LocalizedReason {
        LocalizedReason(
            en: "Data for '\(bundleId)' in \(location) - app no longer installed. Contains application settings and data that can be removed.",
            ja: "'\(bundleId)' の \(location) データ - アプリは既にインストールされていません。アプリケーションの設定とデータが含まれています。"
        )
    }
}
