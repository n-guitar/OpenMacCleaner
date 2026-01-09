import ArgumentParser
import Foundation
import OpenMacCleanerCore

@main
struct OpenCleaner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open-cleaner",
        abstract: "Open Mac Cleaner - System maintenance tool for macOS",
        version: "1.0.0",
        subcommands: [Interactive.self, Survey.self, Cleanup.self, Doctor.self],
        defaultSubcommand: Interactive.self
    )
}

// MARK: - Interactive Command

struct Interactive: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Interactive mode with menu-driven navigation (default)"
    )
    
    @Option(name: .long, help: "Interface language: en or ja")
    var lang: String = "ja"
    
    func run() async throws {
        var mode = InteractiveMode(language: lang)
        try await mode.run()
    }
}

// MARK: - Survey Command

struct Survey: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scan system for cleanup opportunities (dry-run, no changes made)"
    )
    
    @Flag(name: .long, help: "Deep scan including all categories")
    var deep: Bool = false
    
    @Option(name: .long, help: "Output format: markdown or json")
    var format: String = "markdown"
    
    @Option(name: .long, help: "Output language: en or ja")
    var lang: String = "en"
    
    @Option(name: .shortAndLong, help: "Output file path (optional)")
    var output: String?
    
    func run() async throws {
        print("🔍 Starting scan...")
        print("")
        
        let engine = ScanEngine()
        
        // Register scanners
        await engine.register([
            CacheScanner(),
            LogScanner(),
            OrphanedPrefsScanner(),
            AppDataScanner()
        ])
        
        let startTime = Date()
        let result = try await engine.scan()
        let duration = Date().timeIntervalSince(startTime)
        
        print("✅ Scan completed in \(String(format: "%.2f", duration)) seconds")
        print("📊 Found \(result.items.count) items totaling \(result.formattedTotalSize)")
        print("")
        
        // Generate report
        let reportFormat: ReportGenerator.Format = format.lowercased() == "json" ? .json : .markdown
        let reportLang: ReportGenerator.Language = lang.lowercased() == "ja" ? .japanese : .english
        
        let generator = ReportGenerator(format: reportFormat, language: reportLang)
        let report = try generator.generate(from: result)
        
        // Output report
        if let outputPath = output {
            try report.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("📄 Report saved to: \(outputPath)")
        } else {
            print(report)
        }
    }
}

// MARK: - Cleanup Command

struct Cleanup: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Clean up files (moves to Trash by default)"
    )
    
    @Flag(name: .long, help: "Only clean 'Safe' (green) items")
    var safe: Bool = false
    
    @Flag(name: .long, help: "Include 'Caution' (yellow) items")
    var includeCaution: Bool = false
    
    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var yes: Bool = false
    
    func run() async throws {
        print("🔍 Scanning for items to clean...")
        print("")
        
        let engine = ScanEngine()
        
        await engine.register([
            CacheScanner(),
            LogScanner(),
            OrphanedPrefsScanner(),
            AppDataScanner()
        ])
        
        let result = try await engine.scan()
        
        // Filter items based on flags
        var itemsToClean: [CleanupItem]
        
        if safe {
            itemsToClean = result.items.filter { $0.riskLevel == .green }
        } else if includeCaution {
            itemsToClean = result.items.filter { $0.riskLevel == .green || $0.riskLevel == .yellow }
        } else {
            itemsToClean = result.items.filter { $0.riskLevel == .green }
        }
        
        if itemsToClean.isEmpty {
            print("✨ No items to clean!")
            return
        }
        
        let totalSize = itemsToClean.reduce(0) { $0 + $1.size }
        let sizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        
        print("📋 Found \(itemsToClean.count) items to clean (\(sizeStr))")
        print("")
        
        // Show breakdown by risk level
        for level in RiskLevel.allCases {
            let levelItems = itemsToClean.filter { $0.riskLevel == level }
            if !levelItems.isEmpty {
                let levelSize = levelItems.reduce(0) { $0 + $1.size }
                let levelSizeStr = ByteCountFormatter.string(fromByteCount: levelSize, countStyle: .file)
                print("  \(level.emoji) \(level.displayName): \(levelItems.count) items (\(levelSizeStr))")
            }
        }
        print("")
        
        // Confirmation
        if !yes {
            print("⚠️  Items will be moved to Trash. Continue? [y/N] ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("❌ Cleanup cancelled.")
                return
            }
        }
        
        // Perform cleanup
        print("")
        print("🗑️  Moving items to Trash...")
        
        let safetyManager = SafetyManager()
        let results = try await safetyManager.moveToTrash(itemsToClean)
        
        let succeeded = results.filter { $0.success }.count
        let failed = results.filter { !$0.success }.count
        
        print("")
        print("✅ Cleanup complete!")
        print("   Moved: \(succeeded) items")
        if failed > 0 {
            print("   Failed: \(failed) items")
            for result in results where !result.success {
                print("     - \(result.item.path.lastPathComponent): \(result.error ?? "Unknown error")")
            }
        }
    }
}

// MARK: - Doctor Command

struct Doctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Diagnose system health (disk space, memory, etc.)"
    )
    
    @Option(name: .long, help: "Output language: en or ja")
    var lang: String = "en"
    
    func run() async throws {
        let isJapanese = lang.lowercased() == "ja"
        
        print(isJapanese ? "🏥 システム診断を実行中..." : "🏥 Running system diagnostics...")
        print("")
        
        // Disk Space
        print(isJapanese ? "💾 ディスク容量" : "💾 Disk Space")
        print("─".repeating(40))
        
        if let diskInfo = getDiskInfo() {
            let usedPercent = Int((Double(diskInfo.used) / Double(diskInfo.total)) * 100)
            let freeStr = ByteCountFormatter.string(fromByteCount: diskInfo.free, countStyle: .file)
            let totalStr = ByteCountFormatter.string(fromByteCount: diskInfo.total, countStyle: .file)
            
            print(isJapanese ? "  合計: \(totalStr)" : "  Total: \(totalStr)")
            print(isJapanese ? "  空き: \(freeStr)" : "  Free: \(freeStr)")
            print(isJapanese ? "  使用率: \(usedPercent)%" : "  Used: \(usedPercent)%")
            
            // Visual bar
            let barLength = 30
            let filledLength = Int(Double(barLength) * Double(diskInfo.used) / Double(diskInfo.total))
            let bar = String(repeating: "█", count: filledLength) + String(repeating: "░", count: barLength - filledLength)
            print("  [\(bar)]")
            
            // Warning if low
            if diskInfo.free < 10_000_000_000 { // < 10GB
                print("")
                print(isJapanese ? "  ⚠️  ディスク容量が少なくなっています！" : "  ⚠️  Low disk space warning!")
            }
        }
        print("")
        
        // Memory
        print(isJapanese ? "🧠 メモリ" : "🧠 Memory")
        print("─".repeating(40))
        
        if let memInfo = getMemoryInfo() {
            let usedStr = ByteCountFormatter.string(fromByteCount: memInfo.used, countStyle: .memory)
            let totalStr = ByteCountFormatter.string(fromByteCount: memInfo.total, countStyle: .memory)
            let usedPercent = Int((Double(memInfo.used) / Double(memInfo.total)) * 100)
            
            print(isJapanese ? "  合計: \(totalStr)" : "  Total: \(totalStr)")
            print(isJapanese ? "  使用中: \(usedStr) (\(usedPercent)%)" : "  Used: \(usedStr) (\(usedPercent)%)")
        }
        print("")
        
        // Quick scan preview
        print(isJapanese ? "🔍 クイックスキャン" : "🔍 Quick Scan")
        print("─".repeating(40))
        
        let engine = ScanEngine()
        await engine.register([CacheScanner(), LogScanner(), OrphanedPrefsScanner(), AppDataScanner()])
        
        let result = try await engine.scan()
        
        print(isJapanese
            ? "  削除可能: \(result.formattedTotalSize) (\(result.safeItems.count) 安全な項目)"
            : "  Cleanable: \(result.formattedTotalSize) (\(result.safeItems.count) safe items)")
        print("")
        
        print(isJapanese ? "💡 ヒント: 'open-cleaner survey' で詳細レポートを生成" : "💡 Tip: Run 'open-cleaner survey' for detailed report")
    }
    
    private func getDiskInfo() -> (total: Int64, free: Int64, used: Int64)? {
        let fileManager = FileManager.default
        guard let attrs = try? fileManager.attributesOfFileSystem(forPath: "/") else {
            return nil
        }
        
        let total = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        let used = total - free
        
        return (total, free, used)
    }
    
    private func getMemoryInfo() -> (total: Int64, used: Int64)? {
        var size = 0
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        
        var len = MemoryLayout<Int64>.size
        var memsize: Int64 = 0
        
        if sysctl(&mib, 2, &memsize, &len, nil, 0) == 0 {
            // Get used memory from vm_statistics
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

// Helper extension
extension String {
    func repeating(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}
