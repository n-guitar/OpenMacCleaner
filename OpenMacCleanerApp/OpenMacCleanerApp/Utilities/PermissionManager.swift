import Foundation
import AppKit

struct PermissionManager {
    /// Check if the app has Full Disk Access
    /// The most reliable way is to try to read a protected file/directory
    static func checkFullDiskAccess() -> Bool {
        let fileManager = FileManager.default
        let home = URL(fileURLWithPath: NSHomeDirectory())
        
        // Check 1: Safari (User Data)
        let safari = home.appendingPathComponent("Library/Safari")
        let safariAccessible = canList(safari)
        print("FDA Check - Safari: \(safariAccessible)")
        
        // Check 2: TCC.db (System Data - Gold Standard for FDA)
        // If we can read this, we DEFINITELY have FDA.
        let tccPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        let tccAccessible = fileManager.isReadableFile(atPath: tccPath)
        print("FDA Check - TCC.db: \(tccAccessible)")
        
        return safariAccessible || tccAccessible
    }
    
    private static func canList(_ url: URL) -> Bool {
        do {
            _ = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return true
        } catch {
            print("FDA Check Error for \(url.path): \(error)")
            return false
        }
    }
    
    /// Open System Settings > Privacy & Security > Full Disk Access
    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
