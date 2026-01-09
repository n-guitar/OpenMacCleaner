import Foundation

/// Terminal UI utilities for cursor-based menu navigation
enum TerminalUI {
    
    // MARK: - ANSI Escape Codes
    
    static let escape = "\u{001B}["
    static let clearScreen = "\(escape)2J\(escape)H"
    static let clearLine = "\(escape)2K"
    static let hideCursor = "\(escape)?25l"
    static let showCursor = "\(escape)?25h"
    static let saveCursor = "\(escape)s"
    static let restoreCursor = "\(escape)u"
    static let bold = "\(escape)1m"
    static let reset = "\(escape)0m"
    static let inverse = "\(escape)7m"
    static let dim = "\(escape)2m"
    
    // Colors
    static let green = "\(escape)32m"
    static let yellow = "\(escape)33m"
    static let red = "\(escape)31m"
    static let cyan = "\(escape)36m"
    
    // Background colors
    static let bgGreen = "\(escape)42m"
    static let bgYellow = "\(escape)43m"
    static let bgRed = "\(escape)41m"
    
    static func moveUp(_ n: Int = 1) -> String { "\(escape)\(n)A" }
    static func moveDown(_ n: Int = 1) -> String { "\(escape)\(n)B" }
    static func moveTo(row: Int, col: Int) -> String { "\(escape)\(row);\(col)H" }
    
    // MARK: - Terminal Setup
    
    private static var originalTermios: termios?
    
    static func enableRawMode() {
        var raw = termios()
        tcgetattr(STDIN_FILENO, &raw)
        originalTermios = raw
        
        raw.c_lflag &= ~UInt(ICANON | ECHO)
        raw.c_cc.16 = 1  // VMIN
        raw.c_cc.17 = 0  // VTIME
        
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        print(hideCursor, terminator: "")
        fflush(stdout)
    }
    
    static func disableRawMode() {
        print(showCursor, terminator: "")
        if var original = originalTermios {
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
        }
    }
    
    static func readKey() -> Key {
        var buffer = [UInt8](repeating: 0, count: 3)
        let bytesRead = read(STDIN_FILENO, &buffer, 3)
        
        if bytesRead == 1 {
            switch buffer[0] {
            case 13, 10: return .enter
            case 27: return .escape
            case 113, 81: return .quit  // q or Q
            default: return .char(Character(UnicodeScalar(buffer[0])))
            }
        } else if bytesRead == 3 && buffer[0] == 27 && buffer[1] == 91 {
            switch buffer[2] {
            case 65: return .up
            case 66: return .down
            case 67: return .right
            case 68: return .left
            default: return .unknown
            }
        }
        
        return .unknown
    }
    
    enum Key {
        case up, down, left, right
        case enter, escape, quit
        case char(Character)
        case unknown
    }
    
    // MARK: - Menu Selection
    
    /// Display a menu and let user select with arrow keys
    /// Returns the selected index (0-based) or nil if cancelled
    static func selectMenu(
        title: String,
        items: [String],
        selectedIndex: Int = 0,
        showBack: Bool = true
    ) -> Int? {
        enableRawMode()
        defer { disableRawMode() }
        
        var currentIndex = selectedIndex
        let allItems = showBack ? items + ["戻る"] : items
        
        while true {
            // Clear and redraw
            print(clearScreen, terminator: "")
            
            // Title
            print("")
            print("  \(bold)\(title)\(reset)")
            print("  " + String(repeating: "─", count: 50))
            print("")
            
            // Menu items
            for (index, item) in allItems.enumerated() {
                if index == currentIndex {
                    print("  \(inverse) > \(item) \(reset)")
                } else {
                    print("      \(item)")
                }
            }
            
            print("")
            print("  \(dim)↑↓: 選択  Enter: 決定  q: 戻る\(reset)")
            
            fflush(stdout)
            
            // Read input
            let key = readKey()
            
            switch key {
            case .up:
                currentIndex = (currentIndex - 1 + allItems.count) % allItems.count
            case .down:
                currentIndex = (currentIndex + 1) % allItems.count
            case .enter:
                if showBack && currentIndex == allItems.count - 1 {
                    return nil  // Back selected
                }
                return currentIndex
            case .escape, .quit:
                return nil
            case .char(let c):
                // Number selection (1-9)
                if let num = Int(String(c)), num >= 1 && num <= items.count {
                    return num - 1
                }
            default:
                break
            }
        }
    }
    
    /// Display a list with pagination and let user select
    static func selectList(
        title: String,
        items: [(label: String, detail: String)],
        pageSize: Int = 15
    ) -> Int? {
        enableRawMode()
        defer { disableRawMode() }
        
        var currentIndex = 0
        var pageOffset = 0
        
        while true {
            // Ensure current index is visible
            if currentIndex < pageOffset {
                pageOffset = currentIndex
            } else if currentIndex >= pageOffset + pageSize {
                pageOffset = currentIndex - pageSize + 1
            }
            
            let visibleItems = Array(items.dropFirst(pageOffset).prefix(pageSize))
            
            print(clearScreen, terminator: "")
            
            // Title
            print("")
            print("  \(bold)\(title)\(reset)")
            print("  " + String(repeating: "─", count: 50))
            print("")
            
            // Items
            for (i, item) in visibleItems.enumerated() {
                let globalIndex = pageOffset + i
                if globalIndex == currentIndex {
                    print("  \(inverse) > \(item.label) \(reset)")
                    if !item.detail.isEmpty {
                        print("      \(dim)\(item.detail)\(reset)")
                    }
                } else {
                    print("      \(item.label)")
                }
            }
            
            print("")
            print("  \(dim)\(pageOffset + 1)-\(min(pageOffset + pageSize, items.count)) / \(items.count)件\(reset)")
            print("")
            print("  \(dim)↑↓: 選択  Enter: 詳細  q: 戻る\(reset)")
            
            fflush(stdout)
            
            let key = readKey()
            
            switch key {
            case .up:
                if currentIndex > 0 {
                    currentIndex -= 1
                }
            case .down:
                if currentIndex < items.count - 1 {
                    currentIndex += 1
                }
            case .left:
                if pageOffset > 0 {
                    pageOffset = max(0, pageOffset - pageSize)
                    currentIndex = pageOffset
                }
            case .right:
                if pageOffset + pageSize < items.count {
                    pageOffset = min(items.count - pageSize, pageOffset + pageSize)
                    currentIndex = pageOffset
                }
            case .enter:
                return currentIndex
            case .escape, .quit:
                return nil
            default:
                break
            }
        }
    }
    
    /// Multi-select with checkboxes
    /// Returns selected indices or nil if cancelled
    static func multiSelect(
        title: String,
        items: [(label: String, size: Int64)],
        preselected: Set<Int> = [],
        pageSize: Int = 15
    ) -> Set<Int>? {
        enableRawMode()
        defer { disableRawMode() }
        
        var currentIndex = 0
        var pageOffset = 0
        var selected = preselected
        
        while true {
            // Ensure current index is visible
            if currentIndex < pageOffset {
                pageOffset = currentIndex
            } else if currentIndex >= pageOffset + pageSize {
                pageOffset = currentIndex - pageSize + 1
            }
            
            let visibleItems = Array(items.enumerated().dropFirst(pageOffset).prefix(pageSize))
            
            // Calculate selected size
            let selectedSize = selected.reduce(Int64(0)) { sum, idx in
                sum + items[idx].size
            }
            let selectedSizeStr = ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
            
            print(clearScreen, terminator: "")
            
            // Title
            print("")
            print("  \(bold)\(title)\(reset)")
            print("  " + String(repeating: "─", count: 50))
            print("  選択中: \(selected.count)件 (\(selectedSizeStr))")
            print("")
            
            // Items
            for (globalIndex, item) in visibleItems {
                let checkbox = selected.contains(globalIndex) ? "[x]" : "[ ]"
                let sizeStr = ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
                
                if globalIndex == currentIndex {
                    print("  \(inverse) > \(checkbox) \(item.label) (\(sizeStr)) \(reset)")
                } else {
                    print("      \(checkbox) \(item.label) (\(sizeStr))")
                }
            }
            
            print("")
            print("  \(dim)\(pageOffset + 1)-\(min(pageOffset + pageSize, items.count)) / \(items.count)件\(reset)")
            print("")
            print("  \(dim)↑↓: 移動  Space: 選択/解除  a: 全選択  n: 全解除  Enter: 確定  q: キャンセル\(reset)")
            
            fflush(stdout)
            
            let key = readKey()
            
            switch key {
            case .up:
                if currentIndex > 0 {
                    currentIndex -= 1
                }
            case .down:
                if currentIndex < items.count - 1 {
                    currentIndex += 1
                }
            case .left:
                if pageOffset > 0 {
                    pageOffset = max(0, pageOffset - pageSize)
                    currentIndex = pageOffset
                }
            case .right:
                if pageOffset + pageSize < items.count {
                    pageOffset = min(items.count - pageSize, pageOffset + pageSize)
                    currentIndex = pageOffset
                }
            case .char(" "):
                // Toggle selection
                if selected.contains(currentIndex) {
                    selected.remove(currentIndex)
                } else {
                    selected.insert(currentIndex)
                }
                // Move to next item
                if currentIndex < items.count - 1 {
                    currentIndex += 1
                }
            case .char("a"), .char("A"):
                // Select all
                selected = Set(0..<items.count)
            case .char("n"), .char("N"):
                // Select none
                selected = []
            case .enter:
                return selected
            case .escape, .quit:
                return nil
            default:
                break
            }
        }
    }
    
    /// Display confirmation dialog
    static func confirm(message: String) -> Bool {
        enableRawMode()
        defer { disableRawMode() }
        
        var selected = false  // Default to No
        
        while true {
            print(clearScreen, terminator: "")
            print("")
            print("  \(message)")
            print("")
            
            if selected {
                print("      いいえ")
                print("  \(inverse) > はい \(reset)")
            } else {
                print("  \(inverse) > いいえ \(reset)")
                print("      はい")
            }
            
            print("")
            print("  \(dim)↑↓: 選択  Enter: 決定\(reset)")
            
            fflush(stdout)
            
            let key = readKey()
            
            switch key {
            case .up, .down:
                selected = !selected
            case .enter:
                return selected
            case .escape, .quit:
                return false
            default:
                break
            }
        }
    }
    
    /// Show a message and wait for key press
    static func showMessage(_ lines: [String], waitForKey: Bool = true) {
        print(clearScreen, terminator: "")
        print("")
        for line in lines {
            print("  \(line)")
        }
        
        if waitForKey {
            print("")
            print("  \(dim)何かキーを押してください...\(reset)")
            fflush(stdout)
            
            enableRawMode()
            _ = readKey()
            disableRawMode()
        } else {
            fflush(stdout)
        }
    }
    
    /// Show progress
    static func showProgress(_ message: String) {
        print(clearScreen, terminator: "")
        print("")
        print("  \(message)")
        fflush(stdout)
    }
}
