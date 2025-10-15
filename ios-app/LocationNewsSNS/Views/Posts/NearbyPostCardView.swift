import SwiftUI
import MapKit

// MARK: - 近くの投稿カードビュー（縦スクロール用）

struct NearbyPostCardView: View {
    let post: Post
    let onTap: () -> Void
    let onLocationTap: (() -> Void)?
    let onUserTap: (() -> Void)?

    @State private var showingFullImage = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // ヘッダー: ユーザー情報と緊急度
                headerSection

                // 投稿内容
                contentSection

                // 画像（もしあれば）- mediaUrlsは削除されたためコメントアウト
                // if let imageUrl = post.mediaUrls?.first {
                //     imageSection(imageUrl: imageUrl)
                // }

                // 位置情報とカテゴリ
                locationCategorySection

                // インタラクション（いいね、コメント、時間）
                interactionSection
            }
            .padding(12)
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 12) {
            // ユーザーアバター
            Button(action: { onUserTap?() }) {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(post.userName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(timeAgoText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 緊急度バッジ
            if post.isUrgent {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text("緊急")
                        .font(.system(size: 10))
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red)
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        Text(post.content)
            .font(.body)
            .foregroundColor(.primary)
            .lineLimit(4)
            .multilineTextAlignment(.leading)
    }

    // MARK: - Image Section

    @ViewBuilder
    private func imageSection(imageUrl: String) -> some View {
        CachedAsyncImage(url: URL(string: imageUrl)) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipped()
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 200)
                .overlay(ProgressView())
        }
        .cornerRadius(8)
    }

    // MARK: - Location & Category Section

    @ViewBuilder
    private var locationCategorySection: some View {
        HStack(spacing: 16) {
            // 位置情報
            if post.latitude != nil && post.longitude != nil {
                Button(action: { onLocationTap?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text(distanceText)
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }

            // カテゴリ
            HStack(spacing: 4) {
                Image(systemName: post.category.iconName)
                    .font(.system(size: 12))
                Text(post.category.displayName)
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Interaction Section

    @ViewBuilder
    private var interactionSection: some View {
        HStack(spacing: 20) {
            // いいね
            HStack(spacing: 4) {
                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundColor(post.isLiked ? .red : .secondary)
                Text("\(post.likeCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // コメント
            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("\(post.commentCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // シェア
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("\(post.shareCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var distanceText: String {
        if let distance = post.distance {
            if distance < 1000 {
                return "\(Int(distance))m"
            } else {
                return String(format: "%.1fkm", distance / 1000)
            }
        }
        return post.address ?? "近く"
    }

    private var timeAgoText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: post.createdAt, relativeTo: Date())
    }
}

// MARK: - Post Extensions for UI

extension Post {
    var isLiked: Bool {
        // TODO: 実際のいいね状態を管理
        return false
    }
}

// MARK: - Preview

// #Preview {
//     ScrollView {
//         VStack(spacing: 16) {
//             NearbyPostCardView(
//                 post: Post(
//                     id: UUID(),
//                     userId: UUID(),
//                     content: "近くのカフェで美味しいコーヒーを見つけました！雰囲気も最高です。",
//                     latitude: 35.6762,
//                     longitude: 139.6503,
//                     category: .business,
//                     likeCount: 12,
//                     commentCount: 3,
//                     shareCount: 1,
//                     createdAt: Date().addingTimeInterval(-3600)
//                 ),
//                 onTap: {},
//                 onLocationTap: {},
//                 onUserTap: {}
//             )
//
//             NearbyPostCardView(
//                 post: Post(
//                     id: UUID(),
//                     userId: UUID(),
//                     content: "駅前で火災発生。消防車が到着しています。付近の方は注意してください。",
//                     latitude: 35.6812,
//                     longitude: 139.7671,
//                     category: .emergency,
//                     emergencyLevel: .high,
//                     likeCount: 45,
//                     commentCount: 12,
//                     shareCount: 8,
//                     createdAt: Date().addingTimeInterval(-300)
//                 ),
//                 onTap: {},
//                 onLocationTap: {},
//                 onUserTap: {}
//             )
//         }
//         .padding()
//     }
//     .background(Color.gray.opacity(0.1))
// }
