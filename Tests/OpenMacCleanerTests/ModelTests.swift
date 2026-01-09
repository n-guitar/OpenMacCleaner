import XCTest
@testable import OpenMacCleanerCore

final class CleanupItemTests: XCTestCase {
    
    func testFormattedSize() {
        let item = CleanupItem(
            path: URL(fileURLWithPath: "/tmp/test"),
            size: 1_048_576, // 1 MB
            category: .userCache,
            riskLevel: .green,
            reason: LocalizedReason(en: "Test", ja: "テスト")
        )
        
        XCTAssertTrue(item.formattedSize.contains("MB") || item.formattedSize.contains("1"))
    }
    
    func testRiskLevelEmoji() {
        XCTAssertEqual(RiskLevel.green.emoji, "🟢")
        XCTAssertEqual(RiskLevel.yellow.emoji, "🟡")
        XCTAssertEqual(RiskLevel.red.emoji, "🔴")
    }
    
    func testLocalizedReason() {
        let reason = LocalizedReason(en: "English text", ja: "日本語テキスト")
        
        let enLocale = Locale(identifier: "en_US")
        let jaLocale = Locale(identifier: "ja_JP")
        
        XCTAssertEqual(reason.localized(for: enLocale), "English text")
        XCTAssertEqual(reason.localized(for: jaLocale), "日本語テキスト")
    }
}

final class ScanResultTests: XCTestCase {
    
    func testTotalSize() {
        let items = [
            CleanupItem(
                path: URL(fileURLWithPath: "/tmp/a"),
                size: 100,
                category: .userCache,
                riskLevel: .green,
                reason: LocalizedReason(en: "Test", ja: "テスト")
            ),
            CleanupItem(
                path: URL(fileURLWithPath: "/tmp/b"),
                size: 200,
                category: .logs,
                riskLevel: .yellow,
                reason: LocalizedReason(en: "Test", ja: "テスト")
            )
        ]
        
        let result = ScanResult(
            items: items,
            scanDuration: 1.0,
            scannedCategories: [.userCache, .logs]
        )
        
        XCTAssertEqual(result.totalSize, 300)
        XCTAssertEqual(result.safeItems.count, 1)
        XCTAssertEqual(result.safeTotalSize, 100)
    }
    
    func testGroupByCategory() {
        let items = [
            CleanupItem(
                path: URL(fileURLWithPath: "/tmp/a"),
                size: 100,
                category: .userCache,
                riskLevel: .green,
                reason: LocalizedReason(en: "Test", ja: "テスト")
            ),
            CleanupItem(
                path: URL(fileURLWithPath: "/tmp/b"),
                size: 200,
                category: .userCache,
                riskLevel: .green,
                reason: LocalizedReason(en: "Test", ja: "テスト")
            ),
            CleanupItem(
                path: URL(fileURLWithPath: "/tmp/c"),
                size: 300,
                category: .logs,
                riskLevel: .yellow,
                reason: LocalizedReason(en: "Test", ja: "テスト")
            )
        ]
        
        let result = ScanResult(
            items: items,
            scanDuration: 1.0,
            scannedCategories: [.userCache, .logs]
        )
        
        let byCategory = result.itemsByCategory
        XCTAssertEqual(byCategory[.userCache]?.count, 2)
        XCTAssertEqual(byCategory[.logs]?.count, 1)
    }
}
