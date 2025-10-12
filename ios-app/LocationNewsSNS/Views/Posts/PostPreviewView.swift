import SwiftUI
import MapKit

// MARK: - 投稿プレビュー画面

struct PostPreviewView: View {
    let content: String
    let images: [UIImage]
    let location: CLLocationCoordinate2D?
    let locationName: String
    let tags: [String]
    let emergencyLevel: EmergencyLevel?
    let visibility: PostVisibility
    let allowComments: Bool
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // プレビューヘッダー
                    previewHeaderSection
                    
                    // 投稿プレビュー
                    postPreviewSection
                    
                    // 設定詳細
                    settingsDetailSection
                    
                    // 注意事項
                    disclaimerSection
                }
                .padding()
            }
            .navigationTitle("投稿プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("戻る") { dismiss() },
                trailing: Button("確認完了") { dismiss() }
                    .buttonStyle(.borderedProminent)
            )
        }
    }
    
    // MARK: - Preview Header Section
    
    @ViewBuilder
    private var previewHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(.blue)
                
                Text("投稿プレビュー")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("この内容で投稿されます。確認してから投稿してください。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Post Preview Section
    
    @ViewBuilder
    private var postPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ユーザー情報
            userInfoSection
            
            // 緊急度表示
            if let emergency = emergencyLevel {
                emergencyBadgeSection(emergency)
            }
            
            // 投稿内容
            contentSection
            
            // 画像
            if !images.isEmpty {
                imagesSection
            }
            
            // 位置情報
            if let location = location {
                locationSection(location)
            }
            
            // タグ
            if !tags.isEmpty {
                tagsSection
            }
            
            // インタラクション部分（プレビュー用）
            interactionPreviewSection
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var userInfoSection: some View {
        HStack(alignment: .top, spacing: 12) {
            // ユーザーアバター
            if let avatarURL = authService.currentUser?.avatarURL {
                AsyncImage(url: URL(string: avatarURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(authService.currentUser?.displayName ?? authService.currentUser?.username ?? "")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if authService.currentUser?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                    
                    Spacer()
                }
                
                Text("今")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func emergencyBadgeSection(_ emergency: EmergencyLevel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: emergency.iconName)
                .foregroundColor(emergency.color)
            
            Text(emergency.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(emergency.color)
            
            Spacer()
            
            Text("緊急情報")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(emergency.color.opacity(0.2))
                .foregroundColor(emergency.color)
                .cornerRadius(8)
        }
        .padding()
        .background(emergency.color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(emergency.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var contentSection: some View {
        Text(content)
            .font(.body)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private var imagesSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: images.count == 1 ? 1 : 2), spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: images.count == 1 ? 200 : 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    @ViewBuilder
    private func locationSection(_ location: CLLocationCoordinate2D) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(locationName.isEmpty ? "位置情報" : locationName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 4) {
                    Text("#\(tag)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    @ViewBuilder
    private var interactionPreviewSection: some View {
        HStack(spacing: 24) {
            // いいねボタン（プレビュー用）
            HStack(spacing: 4) {
                Image(systemName: "heart")
                    .foregroundColor(.gray)
                Text("0")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // コメントボタン（プレビュー用）
            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                    .foregroundColor(.gray)
                Text(allowComments ? "0" : "無効")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // シェアボタン（プレビュー用）
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.gray)
                Text("0")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 公開範囲表示
            HStack(spacing: 4) {
                Image(systemName: visibility.iconName)
                    .foregroundColor(.gray)
                Text(visibility.displayName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Settings Detail Section
    
    @ViewBuilder
    private var settingsDetailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("投稿設定")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                SettingRow(
                    icon: "eye",
                    title: "公開範囲",
                    value: visibility.displayName,
                    color: visibility.color
                )
                
                SettingRow(
                    icon: "bubble.left",
                    title: "コメント",
                    value: allowComments ? "許可" : "禁止",
                    color: allowComments ? .green : .red
                )
                
                if let emergency = emergencyLevel {
                    SettingRow(
                        icon: emergency.iconName,
                        title: "緊急度",
                        value: emergency.displayName,
                        color: emergency.color
                    )
                }
                
                if let location = location {
                    SettingRow(
                        icon: "location.fill",
                        title: "位置情報",
                        value: locationName.isEmpty ? "設定済み" : locationName,
                        color: .blue
                    )
                }
                
                if !tags.isEmpty {
                    SettingRow(
                        icon: "tag",
                        title: "タグ",
                        value: "\(tags.count)個",
                        color: .blue
                    )
                }
                
                if !images.isEmpty {
                    SettingRow(
                        icon: "photo",
                        title: "画像",
                        value: "\(images.count)枚",
                        color: .green
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Disclaimer Section
    
    @ViewBuilder
    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                
                Text("投稿に関する注意事項")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                DisclaimerItem(text: "投稿内容は利用規約に従って公開されます")
                DisclaimerItem(text: "不適切な内容は削除される場合があります")
                
                if emergencyLevel != nil {
                    DisclaimerItem(text: "緊急情報は優先的に表示され、より多くのユーザーに届きます")
                }
                
                if location != nil {
                    DisclaimerItem(text: "位置情報は他のユーザーに公開されます")
                }
                
                DisclaimerItem(text: "投稿後も編集・削除が可能です")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct SettingRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

struct DisclaimerItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Extensions

extension PostVisibility {
    var color: Color {
        switch self {
        case .public:
            return .green
        case .followers:
            return .blue
        case .area:
            return .purple
        case .private:
            return .orange
        }
    }

    var iconName: String {
        switch self {
        case .public:
            return "globe"
        case .followers:
            return "person.2"
        case .area:
            return "mappin.circle"
        case .private:
            return "lock"
        }
    }

    var displayName: String {
        switch self {
        case .public:
            return "全体公開"
        case .followers:
            return "フォロワーのみ"
        case .area:
            return "地域限定"
        case .private:
            return "非公開"
        }
    }
}

extension EmergencyLevel {
    var color: Color {
        switch self {
        case .low:
            return .yellow
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    var iconName: String {
        switch self {
        case .low:
            return "exclamationmark.circle"
        case .medium:
            return "exclamationmark.triangle"
        case .high:
            return "exclamationmark.triangle.fill"
        }
    }
}

// // #Preview {
//     PostPreviewView(
//         content: "これは投稿プレビューのテストです。実際の投稿内容がここに表示されます。緊急情報や位置情報、タグなども含まれる場合があります。",
//         images: [
//             UIImage(systemName: "photo")!,
//             UIImage(systemName: "camera")!
//         ],
//         location: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
//         locationName: "東京駅",
//         tags: ["テスト", "プレビュー", "投稿"],
//         emergencyLevel: EmergencyLevel.medium,
//         visibility: PostVisibility.public,
//         allowComments: true
//     )
//     .environmentObject(AuthService())
// }