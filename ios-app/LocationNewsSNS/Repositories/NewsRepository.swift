import Foundation
import CoreLocation

// MARK: - News Repository Protocol

protocol NewsRepositoryProtocol {
    func fetchNewsByKeyword(_ keyword: String) async throws -> RSSFeed
}

// MARK: - News Repository Implementation

class NewsRepository: NewsRepositoryProtocol {
    private let baseURL = "https://news.google.com/rss"
    private let session: URLSession

    // キャッシュ層
    private var cachedFeeds: [String: (feed: RSSFeed, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 300 // 5分

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Fetch News by Keyword

    func fetchNewsByKeyword(_ keyword: String) async throws -> RSSFeed {
        // キャッシュチェック
        if let cached = cachedFeeds[keyword],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.feed
        }

        // URLエンコード
        guard let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NewsAPIError.invalidURL
        }

        let endpoint = "\(baseURL)/search?q=\(encodedKeyword)&hl=ja&gl=JP&ceid=JP:ja"

        guard let url = URL(string: endpoint) else {
            throw NewsAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.setValue("LocationNewsSNS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewsAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NewsAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        // XMLパース
        do {
            let parser = RSSParser(data: data)
            var feed = try parser.parse()

            // pubDateで降順ソート（最新順）
            feed.items.sort { item1, item2 in
                guard let date1 = item1.pubDate, let date2 = item2.pubDate else {
                    // pubDateがない場合は後ろに配置
                    return item1.pubDate != nil
                }
                return date1 > date2 // 降順（最新が先頭）
            }

            // キャッシュに保存
            cachedFeeds[keyword] = (feed, Date())

            return feed
        } catch {
            throw NewsAPIError.parsingError(error)
        }
    }
}

// MARK: - RSS Parser

class RSSParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser

    // パース結果
    private var feed: RSSFeed?
    private var items: [NewsStory] = []

    // Channel情報
    private var channelTitle: String = ""
    private var channelLink: String = ""
    private var channelLanguage: String?
    private var channelLastBuildDate: Date?

    // 現在パース中のItem
    private var currentItem: NewsStoryBuilder?

    // 現在の要素とテキスト
    private var currentElement: String = ""
    private var currentText: String = ""

    // <source>のurl属性
    private var currentSourceURL: String?

    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }

    func parse() throws -> RSSFeed {
        guard parser.parse() else {
            if let error = parser.parserError {
                throw error
            }
            throw NewsAPIError.parsingError(NSError(domain: "RSSParser", code: -1, userInfo: nil))
        }

        guard let feed = feed else {
            throw NewsAPIError.parsingError(NSError(domain: "RSSParser", code: -2, userInfo: nil))
        }

        return feed
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""

        if elementName == "item" {
            currentItem = NewsStoryBuilder()
        } else if elementName == "source" {
            currentSourceURL = attributeDict["url"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if currentItem != nil {
            // Item内の要素
            switch elementName {
            case "title":
                currentItem?.title = text
            case "link":
                currentItem?.link = text
            case "guid":
                currentItem?.id = text
            case "pubDate":
                currentItem?.pubDate = parseRFC822Date(text)
            case "description":
                currentItem?.description = text
            case "source":
                currentItem?.source = text
            case "item":
                // Itemの終了
                if let item = currentItem?.build() {
                    items.append(item)
                }
                currentItem = nil
            default:
                break
            }
        } else {
            // Channel情報
            switch elementName {
            case "title":
                channelTitle = text
            case "link":
                channelLink = text
            case "language":
                channelLanguage = text
            case "lastBuildDate":
                channelLastBuildDate = parseRFC822Date(text)
            case "channel":
                // Channelの終了 - フィードを作成
                feed = RSSFeed(
                    title: channelTitle,
                    link: channelLink,
                    language: channelLanguage,
                    lastBuildDate: channelLastBuildDate,
                    items: items
                )
            default:
                break
            }
        }

        currentElement = ""
        currentText = ""
    }

    // MARK: - Date Parsing

    private func parseRFC822Date(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: dateString)
    }
}

// MARK: - NewsStory Builder

private class NewsStoryBuilder {
    var id: String?
    var title: String?
    var link: String?
    var pubDate: Date?
    var description: String?
    var source: String?

    func build() -> NewsStory? {
        guard let id = id,
              let title = title,
              let link = link else {
            return nil
        }

        return NewsStory(
            id: id,
            title: title,
            link: link,
            pubDate: pubDate,
            description: description,
            source: source,
            coordinate: nil,
            distance: nil
        )
    }
}

// MARK: - News API Errors

enum NewsAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case parsingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .httpError(let statusCode):
            return "HTTPエラー: \(statusCode)"
        case .parsingError(let error):
            return "XMLパースエラー: \(error.localizedDescription)"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        }
    }
}
