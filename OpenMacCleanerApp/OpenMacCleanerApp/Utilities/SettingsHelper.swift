import SwiftUI
import AppKit

struct SettingsHelper {
    static func open() {
        // Method 1: Standard Selector
        // This usually works if the "Settings..." menu item exists
        NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)
        
        // Method 2: Fallback to activating app and trying to find the menu item
        // This is useful if the selector didn't catch for some reason
        if let menu = NSApp.mainMenu {
            // Usually under the App Name menu (first item)
            if let appMenu = menu.items.first?.submenu {
                // Look for item with standard tag or title
                for item in appMenu.items {
                    if item.action == Selector("showSettingsWindow:") {
                        NSApp.sendAction(item.action!, to: item.target, from: item)
                        return
                    }
                }
            }
        }
    }
}
