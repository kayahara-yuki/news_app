//
//  URLMetadataService.swift
//  LocationNewsSNS
//
//  Created by AI Assistant on 10/13/25.
//

import Foundation
import CoreLocation
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// URLからメタデータを取得するサービス
@MainActor
class URLMetadataService: ObservableObject {
    // MARK: - Properties

    @Published var isLoading = false
    @Published var error: URLMetadataError?

    /// メタデータのキャッシュ (URL -> URLMetadata)
    private var cache: [URL: URLMetadata] = [:]

    /// キャッシュの有効期限（秒）
    private let cacheExpirationSeconds: TimeInterval = 3600 // 1時間

    // MARK: - Public Methods

    /// URLからメタデータを取得
    /// - Parameter urlString: 取得対象のURL文字列
    /// - Returns: URLMetadata または nil
    func fetchMetadata(from urlString: String) async throws -> URLMetadata? {
        guard let url = URL(string: urlString), url.scheme != nil else {
            throw URLMetadataError.invalidURL
        }

        // キャッシュチェック
        if let cached = cache[url] {
            return cached
        }

        isLoading = true
        error = nil

        defer {
            isLoading = false
        }

        do {
            let metadata = try await fetchOpenGraphData(from: url)
            cache[url] = metadata
            return metadata
        } catch {
            self.error = error as? URLMetadataError ?? .fetchFailed(error)
            throw error
        }
    }

    /// キャッシュをクリア
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private Methods

    /// Open GraphデータをHTMLから抽出
    private func fetchOpenGraphData(from url: URL) async throws -> URLMetadata {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLMetadataError.invalidResponse
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLMetadataError.decodingFailed
        }

        return parseOpenGraphTags(from: html, sourceURL: url)
    }

    /// HTMLからOpen Graphタグをパース
    private func parseOpenGraphTags(from html: String, sourceURL: URL) -> URLMetadata {
        var title: String?
        var description: String?
        var imageURL: String?
        var siteName: String?
        var author: String?
        var publishedAt: Date?

        // Open Graphタグの抽出
        title = extractMetaContent(from: html, property: "og:title")
            ?? extractMetaContent(from: html, name: "title")

        description = extractMetaContent(from: html, property: "og:description")
            ?? extractMetaContent(from: html, name: "description")

        imageURL = extractMetaContent(from: html, property: "og:image")
            ?? extractMetaContent(from: html, name: "image")

        siteName = extractMetaContent(from: html, property: "og:site_name")

        author = extractMetaContent(from: html, name: "author")

        // 公開日時の抽出
        if let publishedTime = extractMetaContent(from: html, property: "article:published_time") {
            publishedAt = ISO8601DateFormatter().date(from: publishedTime)
        }

        // 位置情報の抽出（記事本文から地名を検出）
        let extractedLocation = extractLocationFromText(html)

        return URLMetadata(
            title: title,
            description: description,
            imageURL: imageURL,
            siteName: siteName,
            publishedAt: publishedAt,
            author: author,
            extractedLocation: extractedLocation
        )
    }

    /// metaタグのcontent属性を抽出 (property指定)
    private func extractMetaContent(from html: String, property: String) -> String? {
        let pattern = "<meta\\s+property=\"\(property)\"\\s+content=\"([^\"]+)\""
        return extractWithRegex(from: html, pattern: pattern)
    }

    /// metaタグのcontent属性を抽出 (name指定)
    private func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = "<meta\\s+name=\"\(name)\"\\s+content=\"([^\"]+)\""
        return extractWithRegex(from: html, pattern: pattern)
    }

    /// 正規表現で文字列を抽出
    private func extractWithRegex(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1 else {
            return nil
        }

        let contentRange = match.range(at: 1)
        guard let swiftRange = Range(contentRange, in: text) else {
            return nil
        }

        return String(text[swiftRange])
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    /// テキストから位置情報を抽出（簡易実装）
    private func extractLocationFromText(_ text: String) -> ExtractedLocation? {
        // 日本の主要都市リスト
        let majorCities = [
            ("東京", Coordinate(latitude: 35.6812, longitude: 139.7671)),
            ("大阪", Coordinate(latitude: 34.6937, longitude: 135.5023)),
            ("名古屋", Coordinate(latitude: 35.1815, longitude: 136.9066)),
            ("札幌", Coordinate(latitude: 43.0642, longitude: 141.3469)),
            ("福岡", Coordinate(latitude: 33.5904, longitude: 130.4017)),
            ("京都", Coordinate(latitude: 35.0116, longitude: 135.7681)),
            ("神戸", Coordinate(latitude: 34.6901, longitude: 135.1955)),
            ("横浜", Coordinate(latitude: 35.4437, longitude: 139.6380)),
            ("仙台", Coordinate(latitude: 38.2682, longitude: 140.8694)),
            ("広島", Coordinate(latitude: 34.3853, longitude: 132.4553))
        ]

        // テキストから都市名を検索
        for (cityName, coordinate) in majorCities {
            if text.contains(cityName) {
                return ExtractedLocation(
                    coordinate: coordinate,
                    address: "\(cityName)都" + "市",
                    confidence: 0.6 // 簡易抽出のため信頼度は低め
                )
            }
        }

        return nil
    }
}

// MARK: - Error Types

enum URLMetadataError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case fetchFailed(Error)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .invalidResponse:
            return "サーバーからの応答が無効です"
        case .fetchFailed(let error):
            return "メタデータの取得に失敗しました: \(error.localizedDescription)"
        case .decodingFailed:
            return "データの解析に失敗しました"
        }
    }
}

// MARK: - Preview Helper
#if DEBUG
extension URLMetadataService {
    static let preview: URLMetadataService = {
        let service = URLMetadataService()
        return service
    }()
}
#endif
