import SwiftUI
import MapKit

// MARK: - Date Formatter Singleton

/// パフォーマンス最適化: RelativeDateTimeFormatterのシングルトン化
private extension RelativeDateTimeFormatter {
    static let shared: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

// MARK: - 近くの投稿カルーセルビュー

struct NearbyPostsCarouselView: View {
    @Binding var posts: [Post]
    @Binding var selectedPost: Post?

    let onPostTapped: ((Post) -> Void)?
    let onLocationTapped: ((CLLocationCoordinate2D) -> Void)?

    @State private var scrollPosition: UUID?

    var body: some View {
        if posts.isEmpty {
            emptyStateView
        } else {
            carouselContent
        }
    }

    // MARK: - Carousel Content

    @ViewBuilder
    private var carouselContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            carouselStack
        }
        .scrollPosition(id: $scrollPosition)
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 200)
    }

    @ViewBuilder
    private var carouselStack: some View {
        LazyHStack(spacing: 16) {
            ForEach(posts) { post in
                carouselCard(for: post)
            }
        }
        .padding(.horizontal, 16)
        .scrollTargetLayout()
    }

    @ViewBuilder
    private func carouselCard(for post: Post) -> some View {
        CarouselPostCardView(
            post: post,
            isSelected: selectedPost?.id == post.id,
            onTap: {
                // パフォーマンス最適化: アニメーションを1箇所に統一（.animationモディファイアで制御）
                selectedPost = post
                scrollPosition = post.id
                onPostTapped?(post)
            },
            onLocationTap: {
                if let lat = post.latitude, let lng = post.longitude {
                    onLocationTapped?(CLLocationCoordinate2D(
                        latitude: lat,
                        longitude: lng
                    ))
                }
            }
        )
        .id(post.id)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "map.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("近くに投稿がありません")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("地図を移動して他のエリアを探してみましょう")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(height: 220)
    }
}

// MARK: - 投稿カードビュー（カルーセル用）

struct CarouselPostCardView: View {
    let post: Post
    let isSelected: Bool
    let onTap: () -> Void
    let onLocationTap: () -> Void

    @State private var showingFullImage = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // 画像セクション（もし画像があれば）- mediaUrlsは削除されたためコメントアウト
                // if let imageUrl = post.mediaUrls?.first {
                if false { // 画像表示は将来実装
                    CachedAsyncImage(url: URL(string: "")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(ProgressView())
                    }
                    .frame(height: 100)
                    .clipped()
                }

                // コンテンツセクション
                VStack(alignment: .leading, spacing: 8) {
                    // ユーザー情報
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            )

                        Text(post.userName ?? "Unknown")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Spacer()

                        // 緊急度バッジ
                        if post.isUrgent {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                Text("緊急")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                        }
                    }

                    // 投稿内容
                    Text(post.content)
                        .font(.subheadline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // 位置情報とカテゴリ
                    HStack(spacing: 12) {
                        Button(action: onLocationTap) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                Text(distanceText)
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 10))
                            Text(post.category.displayName)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)

                        Spacer()

                        Text(timeAgoText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // インタラクション情報
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                            Text("\(post.likeCount)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 10))
                            Text("\(post.commentCount)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)

                        Spacer()
                    }
                }
                .padding(12)
            }
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Computed Properties

    private var distanceText: String {
        // TODO: 実際の現在位置からの距離を計算
        // 仮の実装
        if let distance = post.distance {
            if distance < 1000 {
                return "\(Int(distance))m"
            } else {
                return String(format: "%.1fkm", distance / 1000)
            }
        }
        return "近く"
    }

    private var timeAgoText: String {
        return RelativeDateTimeFormatter.shared.localizedString(for: post.createdAt, relativeTo: Date())
    }
}

// MARK: - Supporting Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension EmergencyLevel {
    var carouselDisplayName: String {
        switch self {
        case .low:
            return "注意"
        case .medium:
            return "警告"
        case .high:
            return "緊急"
        }
    }
}

// MARK: - Preview

// #Preview {
//     ZStack {
//         Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)
//
//         VStack {
//             Spacer()
//
//             NearbyPostsCarouselView(
//                 posts: .constant([
//                     Post(
//                         id: UUID(),
//                         userId: UUID(),
//                         content: "近くのカフェで美味しいコーヒーを見つけました！",
//                         latitude: 35.6762,
//                         longitude: 139.6503,
//                         category: "social",
//                         likeCount: 12,
//                         commentCount: 3,
//                         createdAt: Date().addingTimeInterval(-3600)
//                     ),
//                     Post(
//                         id: UUID(),
//                         userId: UUID(),
//                         content: "駅前で火災発生。消防車が到着しています。",
//                         latitude: 35.6812,
//                         longitude: 139.7671,
//                         category: "emergency",
//                         emergencyLevel: .high,
//                         likeCount: 45,
//                         commentCount: 12,
//                         createdAt: Date().addingTimeInterval(-300)
//                     )
//                 ]),
//                 selectedPost: .constant(nil),
//                 onPostTapped: { _ in },
//                 onLocationTapped: { _ in }
//             )
//         }
//     }
// }
