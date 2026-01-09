import SwiftUI

struct ScanView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var l10n: LocalizationManager
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App title
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Text(l10n.localized("app_title"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(l10n.localized("app_subtitle"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Scan button
            Button {
                Task {
                    await viewModel.startScan()
                }
            } label: {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.accentColor.opacity(isHovering ? 0.2 : 0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 60,
                                endRadius: 130
                            )
                        )
                        .frame(width: 260, height: 260)
                    
                    // Main button
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan,
                                    Color.blue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 160)
                        .shadow(color: .blue.opacity(0.4), radius: isHovering ? 20 : 10, x: 0, y: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    if viewModel.isScanning {
                        // Progress ring
                        Circle()
                            .trim(from: 0, to: viewModel.scanProgress)
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: viewModel.scanProgress)
                        
                        VStack(spacing: 4) {
                            Text(l10n.localized("scanning"))
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(Int(viewModel.scanProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                            Text(l10n.localized("scan"))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isScanning)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .scaleEffect(isHovering ? 1.05 : 1.0)
            
            // Status text
            if let result = viewModel.scanResult {
                VStack(spacing: 8) {
                    Text(l10n.localized("privious_scan_result"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 16) {
                        Label {
                            Text(l10n.localized("selected_items_count").replacingOccurrences(of: " items selected", with: "").replacingOccurrences(of: "件の項目を選択中", with: "") + "\(result.items.count) Items") // Quick fix for generic count usage
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "doc")
                                .foregroundColor(.secondary)
                        }
                        
                        Label {
                            Text(result.formattedTotalSize)
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "internaldrive")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Button {
                SettingsHelper.open()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding()
            .help(l10n.localized("open_settings")),
            alignment: .topTrailing
        )
    }
}

#Preview {
    ScanView()
        .environmentObject(AppViewModel())
        .environmentObject(LocalizationManager.shared)
        .frame(width: 800, height: 600)
}
