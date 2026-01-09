import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        Group {
            if viewModel.scanResult == nil {
                ScanView()
            } else {
                CleanupManagerView()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Cleanup Manager (3-Column Layout)

struct CleanupManagerView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var l10n: LocalizationManager
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    viewModel.scanResult = nil
                    viewModel.currentView = .scan
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(l10n.localized("back"))
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(l10n.localized("cleanup_manager"))
                    .font(.headline)
                
                Spacer()
                
                // Sort menu
                Menu {
                    Button(l10n.localized("sort_size")) { viewModel.sortBy = .size }
                    Button(l10n.localized("sort_name")) { viewModel.sortBy = .name }
                } label: {
                    HStack {
                        Text(l10n.localized("sort_by"))
                            .foregroundColor(.secondary)
                        Text(viewModel.sortBy == .size ? l10n.localized("sort_size") : l10n.localized("sort_name"))
                            .foregroundColor(.accentColor)
                        Image(systemName: "chevron.down")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                }
                
                // Settings Button
                Button {
                    SettingsHelper.open()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(l10n.localized("open_settings"))
                .padding(.leading, 8)
            }
            .padding()
            .background(.bar)
            
            // 3-Column with NavigationSplitView (resizable)
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // Column 1: Categories
                CategoryColumn()
                    .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 250)
            } content: {
                // Column 2: Sub-categories
                SubCategoryColumn()
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 350)
            } detail: {
                // Column 3: Items
                ItemsColumn()
            }
            
            Divider()
            
            // Bottom bar
            BottomActionBar()
        }
    }
}

// MARK: - Column 1: Categories

struct CategoryColumn: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var l10n: LocalizationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(viewModel.categoryGroups, id: \.name) { group in
                    CategoryRow(
                        name: group.name,
                        icon: group.icon,
                        isSelected: viewModel.selectedCategoryGroup == group.name
                    )
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.selectedCategoryGroup = group.name
                            viewModel.selectedSubCategory = nil
                            viewModel.selectedRiskFilter = nil // Reset filter to avoid confusion
                        }
                    }
                }
            .padding(.vertical, 8)
        }
    }
    }
}

struct CategoryRow: View {
    let name: String
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 24)
            
            Text(name)
                .font(.body)
                .fontWeight(.semibold) // Bolder
                .foregroundColor(isSelected ? .primary : .primary.opacity(0.8))
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .overlay(
            Rectangle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 4),
            alignment: .leading
        )
    }
}

// MARK: - Column 2: Sub-categories

struct SubCategoryColumn: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var l10n: LocalizationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedCategoryGroup ?? l10n.localized("group_all")) // Fallback to "All" or "Category"
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(viewModel.categoryDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding()
            
            Divider()
            
            // Sub-category list
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(viewModel.subCategories, id: \.name) { sub in
                        SubCategoryRow(
                            name: sub.name,
                            size: sub.formattedSize,
                            isSelected: viewModel.selectedSubCategory == sub.name,
                            color: sub.color
                        )
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) {
                                viewModel.selectedSubCategory = sub.name
                            }
                        }
                    }
                }
                .padding(8)
            }
        }
        .background(Color.black.opacity(0.15))
    }
}

struct SubCategoryRow: View {
    let name: String
    let size: String
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "folder.fill")
                        .foregroundColor(color)
                )
            
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium) // Slightly bolder
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 4)
            
            Text(size)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Column 3: Items

struct ItemsColumn: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var l10n: LocalizationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedSubCategory ?? viewModel.selectedCategoryGroup ?? l10n.localized("group_all"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(viewModel.itemsDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Risk Filter (Custom Colored Buttons)
                if viewModel.selectedCategoryGroup != l10n.localized("group_trash") {
                    HStack(spacing: 4) {
                        FilterButton(
                            title: l10n.localized("group_all"),
                            color: .secondary,
                            isSelected: viewModel.selectedRiskFilter == nil,
                            action: { viewModel.selectedRiskFilter = nil }
                        )
                        
                        FilterButton(
                            title: l10n.localized("risk_safe"),
                            color: .green,
                            isSelected: viewModel.selectedRiskFilter == .safe,
                            action: { viewModel.selectedRiskFilter = .safe }
                        )
                        
                        FilterButton(
                            title: l10n.localized("risk_caution"),
                            color: .yellow,
                            isSelected: viewModel.selectedRiskFilter == .caution,
                            action: { viewModel.selectedRiskFilter = .caution }
                        )
                        
                        FilterButton(
                            title: l10n.localized("risk_risky"),
                            color: .red,
                            isSelected: viewModel.selectedRiskFilter == .risky,
                            action: { viewModel.selectedRiskFilter = .risky }
                        )
                    }
                    .padding(.horizontal, 8)
                }
                
                Spacer()
                
                // Select all toggle
                Button {
                    viewModel.toggleSelectAll()
                } label: {
                    Text(viewModel.allSelected ? l10n.localized("deselect_all") : l10n.localized("select_all"))
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Items list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.displayItems) { item in
                        ItemRow(
                            item: item,
                            isSelected: viewModel.selectedItems.contains(item.id)
                        )
                        .onTapGesture {
                            viewModel.toggleItem(item.id)
                        }
                    }
                }
                .padding(8)
            }
        }
    }
}

struct ItemRow: View {
    let item: AppViewModel.CleanupItemData
    let isSelected: Bool
    @State private var isHovering = false
    @EnvironmentObject var l10n: LocalizationManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.system(size: 18))
            
            // App icon placeholder
            // Use NSWorkspace to get the actual file icon
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.path.path))
                .resizable()
                .frame(width: 32, height: 32)
            
            // Name and Description
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.bold) // Bold
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if !item.reasonJa.isEmpty {
                    Text(item.reasonJa)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Risk indicator
            Circle()
                .fill(item.riskLevel.color)
                .frame(width: 8, height: 8)
                .help(item.riskLevel.displayName + ": " + (item.riskLevel == .safe ? l10n.localized("risk_safe_desc") : (item.riskLevel == .caution ? l10n.localized("risk_caution_desc") : l10n.localized("risk_risky_desc"))))
            
            // Size
            Text(item.formattedSize)
                .font(.body.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .trailing)
            
            // Button Area (Reveal in Finder OR Open Settings)
            Group {
                if item.riskLevel == .risky && item.categoryRaw == "trash" && item.size == 0 {
                    Button {
                        // Open Full Disk Access settings
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text(l10n.localized("open_settings"))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([item.path])
                    } label: {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }
            }
        }

        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func iconFor(_ category: String) -> String {
        switch category {
        case "user_cache": return "folder.badge.gearshape"
        case "logs": return "doc.text"
        case "orphaned_app_data": return "app.badge.checkmark"
        case "broken_prefs": return "gearshape.2"
        case "trash": return "trash.fill"
        case "large_files": return "arrow.up.left.and.arrow.down.right.circle"
        default: return "doc"
        }
    }
}

// MARK: - Bottom Action Bar

struct BottomActionBar: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var l10n: LocalizationManager
    
    var body: some View {
        HStack {
            // Selection count
            Text("\(viewModel.selectedItems.count)" + l10n.localized("selected_items_count"))
                .foregroundColor(.secondary)
            
            Text(viewModel.selectedSizeFormatted)
                .foregroundColor(.primary)
                .fontWeight(.semibold)
            
            if !viewModel.selectedItems.isEmpty {
                Button {
                    viewModel.selectedItems.removeAll()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help(l10n.localized("deselect_all"))
            }
            
            Spacer()
            
            // Clean button
            Button {
                viewModel.showDeleteConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isScanning {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    // Need "Processing" key, falling back to English if missing or adding todo
                    Text(viewModel.isScanning ? "Processing..." : l10n.localized("delete"))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedItems.isEmpty || viewModel.isScanning)
            .opacity((viewModel.selectedItems.isEmpty || viewModel.isScanning) ? 0.5 : 1)
            .alert(l10n.localized("delete_confirm_title"), isPresented: $viewModel.showDeleteConfirmation) {
                Button(l10n.localized("delete_confirm_action"), role: .destructive) {
                    Task {
                        await viewModel.cleanupSelectedItems()
                    }
                }
                Button(l10n.localized("cancel"), role: .cancel) { }
            } message: {
                Text(viewModel.deleteConfirmationMessage)
            }
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
        }
        .padding()
        .background(.bar)
    }
}

#Preview {
    MainView()
        .environmentObject(AppViewModel())
        .frame(width: 900, height: 600)
}

struct FilterButton: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? color : Color.gray.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}
