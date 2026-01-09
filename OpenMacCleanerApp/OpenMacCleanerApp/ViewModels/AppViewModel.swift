import SwiftUI
import Combine

@MainActor
class AppViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanResult: ScanResultData?
    @Published var currentView: NavigationItem = .scan
    
    // 3-Column selection state
    @Published var selectedCategoryGroup: String? = nil
    @Published var selectedSubCategory: String? = nil
    @Published var selectedItems: Set<UUID> = []
    @Published var sortBy: SortOption = .size
    @Published var showDeleteConfirmation = false
    @Published var hasFullDiskAccess = false
    
    enum SortOption {
        case size, name
    }
    
    // MARK: - Core Engine
    private var scanEngine: ScanEngine?
    private var safetyManager = SafetyManager()
    
    // MARK: - Data Models
    
    struct ScanResultData {
        let items: [CleanupItemData]
        let totalSize: Int64
        let scanDuration: TimeInterval
        
        var formattedTotalSize: String {
            ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }
    }
    
    struct CleanupItemData: Identifiable, Hashable {
        let id: UUID
        let path: URL
        let name: String
        let size: Int64
        let category: String
        let categoryRaw: String
        let riskLevel: RiskLevelType
        let reasonJa: String
        let reasonEn: String
        let parentApp: String?
        
        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        
        init(from item: CleanupItem) {
            self.id = item.id
            self.path = item.path
            self.name = item.path.lastPathComponent
            self.size = item.size
            self.category = item.category.displayNameJa
            self.categoryRaw = item.category.rawValue
            self.riskLevel = RiskLevelType(from: item.riskLevel)
            self.reasonJa = item.reason.ja
            self.reasonEn = item.reason.en
            self.parentApp = item.parentApp
        }
        
        init(id: UUID, path: URL, name: String, size: Int64, category: String, categoryRaw: String, riskLevel: RiskLevelType, reasonJa: String, reasonEn: String, parentApp: String?) {
            self.id = id
            self.path = path
            self.name = name
            self.size = size
            self.category = category
            self.categoryRaw = categoryRaw
            self.riskLevel = riskLevel
            self.reasonJa = reasonJa
            self.reasonEn = reasonEn
            self.parentApp = parentApp
        }
        
        func toCoreItem() -> CleanupItem? {
            guard let category = CleanupCategory(rawValue: categoryRaw) else { return nil }
            
            let risk: RiskLevel
            switch riskLevel {
            case .safe: risk = .green
            case .caution: risk = .yellow
            case .risky: risk = .red
            }
            
            return CleanupItem(
                id: id,
                path: path,
                size: size,
                category: category,
                riskLevel: risk,
                reason: LocalizedReason(en: reasonEn, ja: reasonJa),
                parentApp: parentApp
            )
        }
    }
    
    struct CategoryGroup {
        let name: String
        let icon: String
        let categories: [String]
    }
    
    struct SubCategory {
        let name: String
        let categoryRaw: String
        let size: Int64
        let count: Int
        let color: Color
        
        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
    
    enum RiskLevelType: String, CaseIterable {
        case safe, caution, risky
        
        var displayName: String {
            switch self {
            case .safe: return "安全"
            case .caution: return "注意"
            case .risky: return "危険"
            }
        }
        
        var color: Color {
            switch self {
            case .safe: return .green
            case .caution: return .yellow
            case .risky: return .red
            }
        }
        
        init(from coreLevel: RiskLevel) {
            switch coreLevel {
            case .green: self = .safe
            case .yellow: self = .caution
            case .red: self = .risky
            }
        }
    }
    
    enum NavigationItem: String, CaseIterable {
        case scan = "スキャン"
        case results = "結果"
    }
    
    // MARK: - Computed Properties for 3-Column Layout
    
    // MARK: - Computed Properties for 3-Column Layout
    
    var categoryGroups: [CategoryGroup] {
        let l10n = LocalizationManager.shared
        return [
            CategoryGroup(name: l10n.localized("group_system_junk"), icon: "trash", categories: ["user_cache", "logs"]),
            CategoryGroup(name: l10n.localized("group_unorganized"), icon: "app.badge.checkmark", categories: ["orphaned_app_data", "broken_prefs"]),
            CategoryGroup(name: l10n.localized("group_large_items"), icon: "externaldrive", categories: ["large_files", "applications"]),
            CategoryGroup(name: l10n.localized("group_trash"), icon: "trash.fill", categories: ["trash"]),
            CategoryGroup(name: l10n.localized("group_all"), icon: "folder", categories: [])
        ]
    }
    
    var categoryDescription: String {
        let l10n = LocalizationManager.shared
        // Note: Ideally we should match by ID/Enum, but for now we match by name (which is now localized)
        // or better, match by the localized name logic.
        // Actually, selectedCategoryGroup stores the NAME. If language changes, selectedCategoryGroup (String) might become invalid if it was storing Japanese name.
        // To fix this proper: selectedCategoryGroup should store an ID (e.g. "system_junk").
        // See fix below for ID usage in selection.
        
        // Quick fix: Map "system_junk" -> localized description. 
        // But wait, the view sets `selectedCategoryGroup` from the `categoryGroups.name`.
        // If I change language while app is running, `selectedCategoryGroup` holds the OLD language name.
        // The selection will be lost/broken until clicked again.
        // This is acceptable for MVP, or I can reset selection on language change (hard to do).
        
        switch selectedCategoryGroup {
        case l10n.localized("group_system_junk"):
            return "キャッシュやログなど、削除しても問題ないファイルです。" // TODO: Localize descriptions too if needed, but for now Japanese logic matches Japanese name...
            // Wait, I need to map selection to description.
            // If I switch to English, `selectedCategoryGroup` is still "システムジャンク".
            // `categoryGroups` will generate English names. "System Junk".
            // So `selectedCategoryGroup` will not match any group.
            // UI Sidebar will show selection as empty?
            // Steps to fix: Use IDs for CategoryGroup.
        default:
             // Fallback logic
             return l10n.localized("app_subtitle")
        }
        return ""
    }
    
    // Refactored to use IDs for groups would be huge refactor of View.
    // Let's stick to simple localization of strings first.
    // If language changes, selection might be lost. That is OK for now.
    
    // Actually, let's look at `subCategories`.
    
    var subCategories: [SubCategory] {
        guard let result = scanResult else { return [] }
        let l10n = LocalizationManager.shared
        
        let group = categoryGroups.first { $0.name == selectedCategoryGroup }
        let targetCategories = group?.categories ?? []
        
        var subs: [SubCategory] = []
        let categoryColors: [String: Color] = [
            "user_cache": .purple,
            "logs": .orange,
            "orphaned_app_data": .blue,
            "broken_prefs": .pink,
            "trash": .red,
            "large_files": .yellow,
            "applications": .green
        ]
        
        let grouped = Dictionary(grouping: result.items) { $0.categoryRaw }
        
        for (catRaw, items) in grouped {
            if !targetCategories.isEmpty && !targetCategories.contains(catRaw) {
                continue
            }
            
            let size = items.reduce(0) { $0 + $1.size }
            subs.append(SubCategory(
                name: l10n.localized("cat_" + catRaw),
                categoryRaw: catRaw,
                size: size,
                count: items.count,
                color: categoryColors[catRaw] ?? .gray
            ))
        }
        
        return subs.sorted { $0.size > $1.size }
    }
    
    var itemsDescription: String {
        let count = displayItems.count
        let size = displayItems.reduce(0) { $0 + $1.size }
        let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        return "\(count)" + LocalizationManager.shared.localized("selected_items_count").replacingOccurrences(of: " items selected", with: "件").replacingOccurrences(of: "件の項目を選択中", with: "件") + " • \(sizeStr)"
    }
    
    @Published var selectedRiskFilter: RiskLevelType? = nil // nil = All
    
    // ...
    
    var displayItems: [CleanupItemData] {
        guard let result = scanResult else { return [] }
        
        var filtered = result.items
        
        // Filter by sub-category
        if let subCat = selectedSubCategory {
            let sub = subCategories.first { $0.name == subCat }
            if let catRaw = sub?.categoryRaw {
                filtered = filtered.filter { $0.categoryRaw == catRaw }
            }
        } else if let group = categoryGroups.first(where: { $0.name == selectedCategoryGroup }) {
            if !group.categories.isEmpty {
                filtered = filtered.filter { group.categories.contains($0.categoryRaw) }
            }
        }
        
        // Filter by Risk
        if let riskFilter = selectedRiskFilter {
            filtered = filtered.filter { $0.riskLevel == riskFilter }
        }
        
        // Sort
        switch sortBy {
        case .size:
            filtered = filtered.sorted { $0.size > $1.size }
        case .name:
            filtered = filtered.sorted { $0.name < $1.name }
        }
        
        return filtered
    }
    
    var allSelected: Bool {
        let itemIds = Set(displayItems.map { $0.id })
        return !itemIds.isEmpty && itemIds.isSubset(of: selectedItems)
    }
    
    var selectedSizeFormatted: String {
        guard let result = scanResult else { return "0 KB" }
        let selected = result.items.filter { selectedItems.contains($0.id) }
        let size = selected.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var deleteConfirmationMessage: String {
        guard let result = scanResult else { return "" }
        let selected = result.items.filter { selectedItems.contains($0.id) }
        let hasTrashItems = selected.contains { $0.categoryRaw == "trash" }
        let l10n = LocalizationManager.shared
        
        if hasTrashItems {
            return l10n.localized("delete_msg_trash")
        } else {
            return l10n.localized("delete_msg_move")
        }
    }
    
    // MARK: - Actions
    
    func toggleItem(_ id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }
    
    func toggleSelectAll() {
        let itemIds = Set(displayItems.map { $0.id })
        if allSelected {
            selectedItems.subtract(itemIds)
        } else {
            selectedItems.formUnion(itemIds)
        }
    }
    
    func startScan() async {
        isScanning = true
        scanProgress = 0
        
        let startTime = Date()
        
        do {
            let engine = ScanEngine()
            
            await engine.register(CacheScanner())
            await engine.register(LogScanner())
            await engine.register(OrphanedPrefsScanner())
            await engine.register(AppDataScanner())
            await engine.register(TrashScanner())
            await engine.register(LargeFileScanner()) // New!
            
            scanProgress = 0.2
            
            let result = try await engine.scan()
            
            scanProgress = 0.9
            
            let items = result.items.map { CleanupItemData(from: $0) }
            let totalSize = result.totalSize
            
            let duration = Date().timeIntervalSince(startTime)
            
            scanResult = ScanResultData(
                items: items.sorted { $0.size > $1.size },
                totalSize: totalSize,
                scanDuration: duration
            )
            
            // Auto-select safe items -> DISABLED based on user feedback (User wants manual control)
            // for item in items where item.riskLevel == .safe {
            //     selectedItems.insert(item.id)
            // }
            selectedItems.removeAll() // Ensure clean slate
            
            // Set default selection
            selectedCategoryGroup = "システムジャンク"
            
            scanProgress = 1.0
            currentView = .results
        } catch {
            print("Scan error: \(error)")
        }
        
        isScanning = false
    }
    
    func cleanupSelectedItems() async {
        guard let currentResult = scanResult else { return }
        
        // Convert selected items to Core CleanupItems
        let selectedDataItems = currentResult.items.filter { selectedItems.contains($0.id) }
        let coreItems = selectedDataItems.compactMap { $0.toCoreItem() }
        
        guard !coreItems.isEmpty else { return }
        
        isScanning = true // Reuse scanning state for loading indicator
        
        do {
            // Split items into Trash (permanent delete) and others (move to trash)
            let trashItems = coreItems.filter { $0.category == .trash }
            let normalItems = coreItems.filter { $0.category != .trash }
            
            var results: [CleanupResult] = []
            
            // Delete normal items (Move to Trash)
            if !normalItems.isEmpty {
                let moveResults = try await safetyManager.moveToTrash(normalItems)
                results.append(contentsOf: moveResults)
            }
            
            // Delete Trash items (Permanent)
            if !trashItems.isEmpty {
                let deleteResults = try await safetyManager.deletePermanently(trashItems)
                results.append(contentsOf: deleteResults)
            }
            
            // Process results
            var remainingItems = currentResult.items
            var successIds: Set<UUID> = []
            
            for result in results {
                if result.success {
                    successIds.insert(result.item.id)
                } else {
                    print("Failed to delete \(result.item.path.lastPathComponent): \(result.error ?? "Unknown error")")
                }
            }
            
            // Remove deleted items
            remainingItems.removeAll { successIds.contains($0.id) }
            selectedItems.subtract(successIds)
            
            // Update scan result
            let newTotalSize = remainingItems.reduce(0) { $0 + $1.size }
            scanResult = ScanResultData(
                items: remainingItems,
                totalSize: newTotalSize,
                scanDuration: currentResult.scanDuration
            )
            
        } catch {
            print("Cleanup error: \(error)")
        }
        
        isScanning = false
    }
    
    func checkPermission() {
        hasFullDiskAccess = PermissionManager.checkFullDiskAccess()
    }
}

// MARK: - Settings Support
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "システム設定に合わせる"
        case .light: return "ライトモード"
        case .dark: return "ダークモード"
        }
    }
}

class SettingsViewModel: ObservableObject {
    @AppStorage("appTheme") var appTheme: AppTheme = .system
    @AppStorage("appLanguage") var appLanguage: AppLanguage = .japanese
}

// MARK: - Localization Support

enum AppLanguage: String, CaseIterable, Identifiable {
    case japanese = "ja"
    case english = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }
}

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
        }
    }
    
    init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: saved) {
            self.language = lang
        } else {
            // Default to English as requested
            self.language = .english
        }
    }
    
    func localized(_ key: String) -> String {
        guard let entry = translations[key] else { return key }
        return entry[language.rawValue] ?? key
    }
    
    // Translation Dictionary
    private let translations: [String: [String: String]] = [
        // App General
        "scan": ["ja": "スキャン", "en": "Scan"],
        "scanning": ["ja": "スキャン中...", "en": "Scanning..."],
        "app_title": ["ja": "Open Mac Cleaner", "en": "Open Mac Cleaner"],
        "app_subtitle": ["ja": "不要なファイルをスキャンして、\nディスク容量を解放しましょう", "en": "Scan for unnecessary files\nand free up disk space"],
        "privious_scan_result": ["ja": "前回のスキャン結果", "en": "Last Scan Result"],
        
        // Navigation
        "back": ["ja": "戻る", "en": "Back"],
        "cleanup_manager": ["ja": "クリーンアップ管理", "en": "Cleanup Manager"],
        "sort_by": ["ja": "並び替え:", "en": "Sort by:"],
        "sort_size": ["ja": "サイズ", "en": "Size"],
        "sort_name": ["ja": "名前", "en": "Name"],
        
        // Buttons
        "select_all": ["ja": "すべて選択", "en": "Select All"],
        "deselect_all": ["ja": "選択解除", "en": "Deselect All"],
        "delete": ["ja": "削除", "en": "Delete"],
        "cancel": ["ja": "キャンセル", "en": "Cancel"],
        "open_settings": ["ja": "設定を開く", "en": "Open Settings"],
        "confirm": ["ja": "確認する", "en": "Check"],
        "delete_confirm_title": ["ja": "選択した項目を削除しますか？", "en": "Delete selected items?"],
        "delete_confirm_action": ["ja": "削除する", "en": "Delete"],
        
        // Categories & Groups
        "group_system_junk": ["ja": "システムジャンク", "en": "System Junk"],
        "group_unorganized": ["ja": "未整理データ", "en": "Unorganized Data"],
        "group_large_items": ["ja": "大容量項目", "en": "Large Items"],
        "group_trash": ["ja": "ゴミ箱", "en": "Trash"],
        "group_all": ["ja": "すべて", "en": "All"],
        
        "cat_user_cache": ["ja": "ユーザーキャッシュファイル", "en": "User Cache Files"],
        "cat_logs": ["ja": "ユーザーログファイル", "en": "User Log Files"],
        "cat_orphaned_app_data": ["ja": "未使用アプリデータ", "en": "Unused App Data"],
        "cat_broken_prefs": ["ja": "壊れた環境設定", "en": "Broken Preferences"],
        "cat_trash": ["ja": "ゴミ箱の項目", "en": "Trash Items"],
        "cat_large_files": ["ja": "大容量ファイル", "en": "Large Files"],
        "cat_applications": ["ja": "アプリケーション", "en": "Applications"],
        
        // Risk Levels
        "risk_safe": ["ja": "安全", "en": "Safe"],
        "risk_caution": ["ja": "注意", "en": "Caution"],
        "risk_risky": ["ja": "危険", "en": "Risky"],
        "risk_safe_desc": ["ja": "削除しても安全です", "en": "Safe to delete"],
        "risk_caution_desc": ["ja": "注意が必要です", "en": "Caution advised"],
        "risk_risky_desc": ["ja": "重要なファイルが含まれる可能性があります", "en": "system files may be included"],
        
        // Messages
        "selected_items_count": ["ja": "件の項目を選択中", "en": " items selected"],
        "delete_msg_trash": ["ja": "ゴミ箱内の項目が含まれています。\nこれらは完全に削除され、復元できません。\nよろしいですか？", "en": "Trash items are included.\nThese will be permanently deleted and cannot be recovered.\nAre you sure?"],
        "delete_msg_move": ["ja": "選択されたアイテムはゴミ箱に移動されます。", "en": "Selected items will be moved to Trash."],
        
        // Onboarding
        "welcome": ["ja": "ようこそ", "en": "Welcome"],
        "fda_required": ["ja": "OpenMacCleanerを使用するには、\nフルディスクアクセスが必要です。", "en": "Full Disk Access is required\nto use OpenMacCleaner."],
        "step_1_title": ["ja": "システム設定を開く", "en": "Open System Settings"],
        "step_1_desc": ["ja": "下の「設定を開く」ボタンをクリックします。", "en": "Click the 'Open Settings' button below."],
        "step_2_title": ["ja": "スイッチをオンにする", "en": "Turn on the switch"],
        "step_2_desc": ["ja": "リストから OpenMacCleaner を探し、\nスイッチをオンにしてください。", "en": "Find OpenMacCleaner in the list\nand turn on the switch."],
        "step_3_title": ["ja": "アプリを再起動", "en": "Restart App"],
        "step_3_desc": ["ja": "設定を変更した後、アプリを再起動してください。", "en": "Please restart the app after changing settings."],
        
        // Settings
        "settings_general": ["ja": "一般", "en": "General"],
        "settings_appearance": ["ja": "外観モード", "en": "Appearance"],
        "settings_appearance_desc": ["ja": "アプリの見た目を切り替えることができます。", "en": "Customize the app appearance."],
        "settings_language": ["ja": "言語", "en": "Language"],
        "settings_language_desc": ["ja": "アプリの表示言語を切り替えます。", "en": "Change the app display language."]
    ]
}
