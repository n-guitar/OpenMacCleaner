import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: AppViewModel
    
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
                
                Text("ようこそ")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("OpenMacCleanerを使用するには、\nフルディスクアクセスが必要です。")
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
                        Text("システム設定を開く")
                            .font(.headline)
                        Text("下の「設定を開く」ボタンをクリックします。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("スイッチをオンにする")
                            .font(.headline)
                        Text("リストから OpenMacCleanerApp を探し、\nスイッチをオンにしてください。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("アプリを再起動")
                            .font(.headline)
                        Text("設定を変更した後、アプリを再起動してください。")
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
                    Text("設定を開く")
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
                        Text("確認する")
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(48)
        .frame(minWidth: 600, minHeight: 500)
    }
}
