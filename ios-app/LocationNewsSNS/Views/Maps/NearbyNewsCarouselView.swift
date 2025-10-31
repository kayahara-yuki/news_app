import SwiftUI
import MapKit

// MARK: - String Extension for HTML Stripping

extension String {
    /// HTMLタグを除去してプレーンテキストを返す
    func stripHTML() -> String {
        // 簡易的なHTMLタグ除去
        let result = self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        // HTML特殊文字をデコード
        return result
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

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

// MARK: - 近くのニュースカルーセルビュー

struct NearbyNewsCarouselView: View {
    @Binding var news: [NewsStory]
    @Binding var selectedNews: NewsStory?
    @ObservedObject var newsService: NewsService

    let onNewsTapped: ((NewsStory) -> Void)?
    let onLocationTapped: ((CLLocationCoordinate2D) -> Void)?

    @State private var scrollPosition: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー: 近くのニュース
            headerView

            if news.isEmpty {
                emptyStateView
            } else {
                carouselContent
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 6) {
            Image(systemName: "newspaper.fill")
                .font(.system(size: 14))
                .foregroundColor(.blue)

            Text("近くのニュース")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Carousel Content

    @ViewBuilder
    private var carouselContent: some View {
        if #available(iOS 17.0, *) {
            ScrollView(.horizontal, showsIndicators: false) {
                carouselStack
            }
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .frame(height: 200)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    carouselStack
                }
                .frame(height: 200)
                .onChange(of: scrollPosition) { newValue in
                    if let id = newValue {
                        withAnimation {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var carouselStack: some View {
        LazyHStack(spacing: 16) {
            ForEach(news) { newsStory in
                carouselCard(for: newsStory)
            }

            // ローディングインジケータ
            if newsService.isLoadingMore {
                loadingIndicator
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("読み込み中...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .frame(width: 280, height: 165)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.95))
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func carouselCard(for newsStory: NewsStory) -> some View {
        CarouselNewsCardView(
            newsStory: newsStory,
            isSelected: selectedNews?.id == newsStory.id
        )
        .id(newsStory.id)
        .onTapGesture {
            selectedNews = newsStory
            scrollPosition = newsStory.id
            onNewsTapped?(newsStory)

            // カード選択時にマップをニュースの位置に移動
            if let coordinate = newsStory.coordinate {
                onLocationTapped?(coordinate)
            }
        }
        .onAppear {
            // 最後から2番目のカードが表示されたら次のページを読み込む
            if isNearEndOfList(newsStory: newsStory) {
                newsService.loadNextPage()
            }
        }
    }

    // MARK: - Helper Methods

    /// 最後から2番目のカードかどうかを判定
    private func isNearEndOfList(newsStory: NewsStory) -> Bool {
        guard let index = news.firstIndex(where: { $0.id == newsStory.id }) else {
            return false
        }
        return index >= news.count - 2
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "newspaper.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("近くにニュースがありません")
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

// MARK: - ニュースカードビュー（カルーセル用）

struct CarouselNewsCardView: View {
    let newsStory: NewsStory
    let isSelected: Bool

    var body: some View {
        // コンテンツセクション
        VStack(alignment: .leading, spacing: 10) {
            // ソース名とバッジ
            HStack(spacing: 8) {
                    if let source = newsStory.source {
                        HStack(spacing: 4) {
                            Image(systemName: "newspaper.fill")
                                .font(.system(size: 10))
                            Text(source)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }
                        .foregroundColor(.blue)
                    }

                    Spacer()

                    // 公開日時
                    if let pubDate = newsStory.pubDate {
                        Text(RelativeDateTimeFormatter.shared.localizedString(for: pubDate, relativeTo: Date()))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // ニュースタイトル
                Text(newsStory.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(height: 54, alignment: .top)

                // 説明
                if let description = newsStory.description, !description.isEmpty {
                    Text(description.stripHTML())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(height: 28, alignment: .top)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 280, height: 165)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview

#if DEBUG
struct NearbyNewsCarouselView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()

                NearbyNewsCarouselView(
                    news: .constant([
                        NewsStory(
                            id: "CBMi123",
                            title: "札幌で初雪観測 平年より5日早く - HTB北海道テレビ",
                            link: "https://news.google.com/rss/articles/...",
                            pubDate: Date().addingTimeInterval(-3600),
                            description: "札幌管区気象台は24日、札幌で初雪を観測したと発表した。平年より5日早い観測となった。",
                            source: "HTB北海道テレビ",
                            coordinate: CLLocationCoordinate2D(latitude: 43.0642, longitude: 141.3469),
                            distance: 0
                        ),
                        NewsStory(
                            id: "CBMi456",
                            title: "札幌市の公園にヒグマ2頭、緊急銃猟で駆除 - 読売新聞",
                            link: "https://news.google.com/rss/articles/...",
                            pubDate: Date().addingTimeInterval(-7200),
                            description: "札幌市南区の公園にヒグマ2頭が出没し、緊急銃猟で駆除された。",
                            source: "読売新聞",
                            coordinate: CLLocationCoordinate2D(latitude: 43.0642, longitude: 141.3469),
                            distance: 0
                        )
                    ]),
                    selectedNews: .constant(nil),
                    newsService: NewsService.preview(),
                    onNewsTapped: { _ in },
                    onLocationTapped: { _ in }
                )
            }
        }
    }
}
#endif
