import SwiftUI

@main
struct OpenMacCleanerApp: App {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var localizationManager = LocalizationManager.shared
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    var body: some Scene {
        WindowGroup {
            Group {
                if viewModel.hasFullDiskAccess {
                    MainView()
                } else {
                    OnboardingView(viewModel: viewModel)
                }
            }
            .environmentObject(viewModel)
            .environmentObject(localizationManager)
            .preferredColorScheme(appTheme == .system ? nil : (appTheme == .dark ? .dark : .light))
            .onAppear {
                // Check permission on app launch
                viewModel.checkPermission()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        
        Settings {
            SettingsView()
                .environmentObject(localizationManager)
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject var l10n: LocalizationManager
    
    var body: some View {
        VStack(spacing: 32) {
            // Icon / Header
            VStack(spacing: 16) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 120, height: 120)
                    )
                
                Text(l10n.localized("welcome"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(l10n.localized("fda_required"))
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // Explanation
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.localized("step_1_title"))
                            .font(.headline)
                        Text(l10n.localized("step_1_desc"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.localized("step_2_title"))
                            .font(.headline)
                        Text(l10n.localized("step_2_desc"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.localized("step_3_title"))
                            .font(.headline)
                        Text(l10n.localized("step_3_desc"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 1, y: 1)
            
            // Action Buttons
            VStack(spacing: 16) {
                Button {
                    PermissionManager.openFullDiskAccessSettings()
                } label: {
                    Text(l10n.localized("open_settings"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .frame(width: 280)
                
                Button {
                    viewModel.checkPermission()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(l10n.localized("confirm"))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(48)
        .frame(minWidth: 600, minHeight: 500)
        .overlay(
            Menu {
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        l10n.language = lang
                    } label: {
                        if l10n.language == lang {
                            Label(lang.displayName, systemImage: "checkmark")
                        } else {
                            Text(lang.displayName)
                        }
                    }
                }
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .padding()
            .help(l10n.localized("settings_language")),
            alignment: .topTrailing
        )
    }
}

import AppKit

struct PermissionManager {
    /// Check if the app has Full Disk Access
    /// The most reliable way is to try to read a protected file/directory
    static func checkFullDiskAccess() -> Bool {
        // Checking ~/.Trash or ~/Library/Safari is a good litmus test
        let fileManager = FileManager.default
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let target = home.appendingPathComponent("Library/Safari")
        
        // trying to list the directory contents triggers TCC
        do {
            _ = try fileManager.contentsOfDirectory(at: target, includingPropertiesForKeys: nil)
            return true
        } catch {
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

// MARK: - Consolidated Settings View
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var l10n: LocalizationManager
    
    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem {
                    Label(l10n.localized("settings_general"), systemImage: "gear")
                }
                .tag("general")
        }
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject var l10n: LocalizationManager
    
    var body: some View {
        Form {
            Section {
                Picker(l10n.localized("settings_language"), selection: $l10n.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.inline)
                
                Text(l10n.localized("settings_language_desc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Picker(l10n.localized("settings_appearance"), selection: $viewModel.appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.inline)
                
                Text(l10n.localized("settings_appearance_desc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }
}

// MARK: - Settings Helper
struct SettingsHelper {
    static func open() {
        // Method 1: Standard Selector
        NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)
        
        // Method 2: Comprehensive Menu Search
        // Search for any menu item with keyEquivalent "," and Command modifier
        if let menu = NSApp.mainMenu {
            for item in menu.items {
                if let submenu = item.submenu {
                    for subItem in submenu.items {
                        if subItem.keyEquivalent == "," && subItem.keyEquivalentModifierMask.contains(.command) {
                            if let action = subItem.action {
                                NSApp.sendAction(action, to: subItem.target, from: subItem)
                                return
                            }
                        }
                    }
                }
            }
        }
    }
}
