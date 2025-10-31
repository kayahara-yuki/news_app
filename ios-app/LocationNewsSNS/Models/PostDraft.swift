//
//  PostDraft.swift
//  LocationNewsSNS
//
//  投稿下書きモデル
//

import Foundation

/// 投稿送信失敗時に保存される下書き
/// - Requirements: 11.4, 11.5
struct PostDraft: Codable, Identifiable {
    let id: UUID
    let content: String
    let audioFileURL: URL?
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let isStatusPost: Bool
    let failureReason: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        content: String,
        audioFileURL: URL? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        isStatusPost: Bool = false,
        failureReason: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.audioFileURL = audioFileURL
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.isStatusPost = isStatusPost
        self.failureReason = failureReason
        self.createdAt = createdAt
    }
}
