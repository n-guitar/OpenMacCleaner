import SwiftUI

class SettingsViewModel: ObservableObject {
    @AppStorage("appTheme") var appTheme: AppTheme = .system
}

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
