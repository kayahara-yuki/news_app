//
//  URLMetadata.swift
//  LocationNewsSNS
//
//  Created by AI Assistant on 10/13/25.
//

import Foundation
import CoreLocation

/// URLから取得したメタデータ
struct URLMetadata: Codable, Equatable {
    /// ページタイトル
    let title: String?

    /// ページの説明文
    let description: String?

    /// サムネイル画像URL
    let imageURL: String?

    /// サイト名
    let siteName: String?

    /// 記事の公開日
    let publishedAt: Date?

    /// 著者名
    let author: String?

    /// 記事から抽出した位置情報
    let extractedLocation: ExtractedLocation?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case imageURL = "image"
        case siteName = "site_name"
        case publishedAt = "published_at"
        case author
        case extractedLocation = "extracted_location"
    }
}

/// URLから抽出した位置情報
struct ExtractedLocation: Codable, Equatable {
    /// 座標（緯度・経度）
    let coordinate: Coordinate?

    /// 住所テキスト
    let address: String?

    /// 抽出の信頼度 (0.0 ~ 1.0)
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case coordinate = "coordinates"
        case address
        case confidence
    }

    /// CLLocationCoordinate2Dへの変換
    var clCoordinate: CLLocationCoordinate2D? {
        guard let coordinate = coordinate else { return nil }
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}

/// 座標（緯度・経度）
struct Coordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from decoder: Decoder) throws {
        // 配列形式 [longitude, latitude] または辞書形式に対応
        let container = try decoder.singleValueContainer()

        if let array = try? container.decode([Double].self), array.count >= 2 {
            // GeoJSON形式: [longitude, latitude]
            self.longitude = array[0]
            self.latitude = array[1]
        } else if let dict = try? container.decode([String: Double].self) {
            // 辞書形式
            self.latitude = dict["latitude"] ?? 0
            self.longitude = dict["longitude"] ?? 0
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid coordinate format"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // GeoJSON形式で出力
        try container.encode([longitude, latitude])
    }
}

// MARK: - URLMetadata Preview Extensions
extension URLMetadata {
    /// プレビュー表示用のテキスト
    var previewText: String {
        if let title = title, !title.isEmpty {
            return title
        }
        if let description = description, !description.isEmpty {
            return description
        }
        return siteName ?? "リンク"
    }

    /// メタデータが有効かどうか
    var isValid: Bool {
        return title != nil || description != nil || imageURL != nil
    }
}

// MARK: - Sample Data for Preview
#if DEBUG
extension URLMetadata {
    static let sampleNews = URLMetadata(
        title: "東京都心で震度4の地震　交通機関に影響",
        description: "13日午前10時、東京都心で震度4の地震が発生しました。震源地は東京湾で、深さは約40km。マグニチュードは5.2と推定されています。",
        imageURL: "https://example.com/earthquake.jpg",
        siteName: "ニュースサイト",
        publishedAt: Date(),
        author: "報道部",
        extractedLocation: ExtractedLocation(
            coordinate: Coordinate(latitude: 35.6812, longitude: 139.7671),
            address: "東京都千代田区",
            confidence: 0.85
        )
    )

    static let sampleWithoutLocation = URLMetadata(
        title: "新しい技術トレンド2025",
        description: "2025年に注目すべき技術トレンドをまとめました。",
        imageURL: "https://example.com/tech.jpg",
        siteName: "テックブログ",
        publishedAt: Date(),
        author: nil,
        extractedLocation: nil
    )
}
#endif
