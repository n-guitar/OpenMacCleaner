import Foundation
import AppKit

struct PermissionManager {
    /// Check if the app has Full Disk Access
    /// The most reliable way is to try to read a protected file/directory
    static func checkFullDiskAccess() -> Bool {
        // Checking ~/.Trash or ~/Library/Safari is a good litmus test
        let fileManager = FileManager.default
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let target = home.appendingPathComponent("Library/Safari")
        
        // We only need to check readability
        return fileManager.isReadableFile(atPath: target.path)
    }
    
    /// Open System Settings > Privacy & Security > Full Disk Access
    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
