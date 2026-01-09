import Foundation
import OpenMacCleanerCore

/// Interactive CLI mode with cursor-based menu navigation
struct InteractiveMode {
    let isJapanese: Bool
    var currentResult: ScanResult?
    
    init(language: String) {
        self.isJapanese = language.lowercased() == "ja"
    }
    
    /// Format risk level with color
    private func riskMarker(_ level: RiskLevel) -> String {
        switch level {
        case .green:
            return "\(TerminalUI.green)● 安全\(TerminalUI.reset)"
        case .yellow:
            return "\(TerminalUI.yellow)● 注意\(TerminalUI.reset)"
        case .red:
            return "\(TerminalUI.red)● 危険\(TerminalUI.reset)"
        }
    }
    
    /// Plain risk marker without color (for labels)
    private func riskLabel(_ level: RiskLevel) -> String {
        switch level {
        case .green:
            return "安全"
        case .yellow:
            return "注意"
        case .red:
            return "危険"
        }
    }
    
    mutating func run() async throws {
        while true {
            let menuItems = buildMainMenu()
            
            guard let choice = TerminalUI.selectMenu(
                title: "Open Mac Cleaner",
                items: menuItems,
                showBack: false
            ) else {
                break  // User quit
            }
            
            switch choice {
            case 0:
                await runDiagnostics()
            case 1:
                try await runFullScan()
            case 2:
                if currentResult != nil {
                    try await browseResults()
                } else {
                    TerminalUI.showMessage(["スキャンを先に実行してください"])
                }
            case 3:
                break  // Exit
            default:
                break
            }
            
            if choice == 3 { break }
        }
    }
    
    private func buildMainMenu() -> [String] {
        var items = [
            "システム診断",
            "フルスキャン"
        ]
        
        if let result = currentResult {
            let size = result.formattedTotalSize
            items.append("結果を閲覧 (\(result.items.count)件, \(size))")
        } else {
            items.append("結果を閲覧 (未スキャン)")
        }
        
        items.append("終了")
        return items
    }
    
    // MARK: - Diagnostics
    
    private func runDiagnostics() async {
        var lines: [String] = []
        
        lines.append("")
        lines.append("システム診断")
        lines.append(String(repeating: "─", count: 50))
        lines.append("")
        
        // Disk
        lines.append("ディスク")
        if let (total, free, used) = getDiskInfo() {
            let usedPercent = Int((Double(used) / Double(total)) * 100)
            let freeStr = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
            let totalStr = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            
            lines.append("  合計: \(totalStr)")
            lines.append("  空き: \(freeStr)")
            
            let barLength = 30
            let filledLength = Int(Double(barLength) * Double(used) / Double(total))
            let bar = String(repeating: "#", count: filledLength) + String(repeating: "-", count: barLength - filledLength)
            lines.append("  使用率: [\(bar)] \(usedPercent)%")
        }
        
        lines.append("")
        
        // Memory
        lines.append("メモリ")
        if let (total, used) = getMemoryInfo() {
            let usedStr = ByteCountFormatter.string(fromByteCount: used, countStyle: .memory)
            let totalStr = ByteCountFormatter.string(fromByteCount: total, countStyle: .memory)
            let usedPercent = Int((Double(used) / Double(total)) * 100)
            
            lines.append("  合計: \(totalStr)")
            lines.append("  使用中: \(usedStr) (\(usedPercent)%)")
        }
        
        TerminalUI.showMessage(lines)
    }
    
    // MARK: - Full Scan
    
    private mutating func runFullScan() async throws {
        TerminalUI.showProgress("スキャン中...")
        
        let engine = ScanEngine()
        await engine.register([
            CacheScanner(),
            LogScanner(),
            OrphanedPrefsScanner(),
            AppDataScanner()
        ])
        
        let startTime = Date()
        currentResult = try await engine.scan()
        let duration = Date().timeIntervalSince(startTime)
        
        guard let result = currentResult else { return }
        
        var lines: [String] = []
        lines.append("")
        lines.append("スキャン完了 (\(String(format: "%.1f", duration))秒)")
        lines.append(String(repeating: "─", count: 50))
        lines.append("")
        lines.append("検出: \(result.items.count)件 / \(result.formattedTotalSize)")
        lines.append("")
        
        for level in RiskLevel.allCases {
            let items = result.items.filter { $0.riskLevel == level }
            let size = items.reduce(0) { $0 + $1.size }
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            lines.append("  \(riskMarker(level)) \(items.count)件 (\(sizeStr))")
        }
        
        TerminalUI.showMessage(lines)
    }
    
    // MARK: - Browse Results
    
    private func browseResults() async throws {
        guard let result = currentResult else { return }
        
        while true {
            let choice = TerminalUI.selectMenu(
                title: "結果を閲覧",
                items: [
                    "リスクレベル別",
                    "カテゴリ別",
                    "サイズ順"
                ]
            )
            
            guard let choice = choice else { return }
            
            switch choice {
            case 0:
                browseByRiskLevel(result)
            case 1:
                browseByCategory(result)
            case 2:
                browseBySize(result)
            default:
                break
            }
        }
    }
    
    private func browseByRiskLevel(_ result: ScanResult) {
        var menuItems: [String] = []
        var levelList: [RiskLevel] = []
        
        for level in RiskLevel.allCases {
            let items = result.items.filter { $0.riskLevel == level }
            guard !items.isEmpty else { continue }
            
            let size = items.reduce(0) { $0 + $1.size }
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            menuItems.append("\(riskMarker(level)) \(items.count)件 (\(sizeStr))")
            levelList.append(level)
        }
        
        guard let choice = TerminalUI.selectMenu(
            title: "リスクレベル別",
            items: menuItems
        ) else { return }
        
        let selectedLevel = levelList[choice]
        let items = result.items.filter { $0.riskLevel == selectedLevel }
        showItemsList(items)
    }
    
    private func browseByCategory(_ result: ScanResult) {
        var menuItems: [String] = []
        var categoryList: [CleanupCategory] = []
        
        for category in CleanupCategory.allCases {
            let items = result.items.filter { $0.category == category }
            guard !items.isEmpty else { continue }
            
            let size = items.reduce(0) { $0 + $1.size }
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            menuItems.append("\(category.displayNameJa) \(items.count)件 (\(sizeStr))")
            categoryList.append(category)
        }
        
        guard let choice = TerminalUI.selectMenu(
            title: "カテゴリ別",
            items: menuItems
        ) else { return }
        
        let selectedCategory = categoryList[choice]
        let items = result.items.filter { $0.category == selectedCategory }
        showItemsList(items)
    }
    
    private func browseBySize(_ result: ScanResult) {
        let sorted = result.items.sorted { $0.size > $1.size }
        showItemsList(sorted)
    }
    
    private func showItemsList(_ items: [CleanupItem]) {
        let listItems = items.map { item -> (label: String, detail: String) in
            let name = item.path.lastPathComponent
            let sizeStr = item.formattedSize
            return (
                label: "\(riskMarker(item.riskLevel)) \(name) (\(sizeStr))",
                detail: item.path.path
            )
        }
        
        while true {
            guard let selected = TerminalUI.selectList(
                title: "アイテム一覧 (\(items.count)件)",
                items: listItems
            ) else { return }
            
            showItemDetail(items[selected])
        }
    }
    
    private func showItemDetail(_ item: CleanupItem) {
        var lines: [String] = []
        lines.append("")
        lines.append("アイテム詳細")
        lines.append(String(repeating: "─", count: 50))
        lines.append("")
        lines.append("ファイル: \(item.path.lastPathComponent)")
        lines.append("パス: \(item.path.path)")
        lines.append("サイズ: \(item.formattedSize)")
        lines.append("カテゴリ: \(item.category.displayNameJa)")
        lines.append("リスク: \(riskMarker(item.riskLevel))")
        
        if let app = item.parentApp {
            lines.append("関連アプリ: \(app)")
        }
        
        lines.append("")
        lines.append(String(repeating: "─", count: 50))
        lines.append("削除理由:")
        lines.append(item.reason.ja)
        
        TerminalUI.showMessage(lines)
    }
    
    // MARK: - System Info
    
    private func getDiskInfo() -> (total: Int64, free: Int64, used: Int64)? {
        let fileManager = FileManager.default
        guard let attrs = try? fileManager.attributesOfFileSystem(forPath: "/") else { return nil }
        
        let total = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        let used = total - free
        
        return (total, free, used)
    }
    
    private func getMemoryInfo() -> (total: Int64, used: Int64)? {
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        var len = MemoryLayout<Int64>.size
        var memsize: Int64 = 0
        
        if sysctl(&mib, 2, &memsize, &len, nil, 0) == 0 {
            var stats = vm_statistics64()
            var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
            
            let result = withUnsafeMutablePointer(to: &stats) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
                }
            }
            
            if result == KERN_SUCCESS {
                let pageSize = Int64(vm_kernel_page_size)
                let activeMemory = Int64(stats.active_count) * pageSize
                let wiredMemory = Int64(stats.wire_count) * pageSize
                let compressedMemory = Int64(stats.compressor_page_count) * pageSize
                let usedMemory = activeMemory + wiredMemory + compressedMemory
                
                return (memsize, usedMemory)
            }
        }
        
        return nil
    }
}
