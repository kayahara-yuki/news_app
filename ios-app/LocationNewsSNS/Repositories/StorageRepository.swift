//
//  StorageRepository.swift
//  LocationNewsSNS
//
//  Created for Supabase Storage integration
//

import Foundation
import Supabase

// MARK: - Storage Repository Protocol

protocol StorageRepositoryProtocol {
    func upload(bucket: String, path: String, data: Data) async throws -> URL
    func delete(bucket: String, path: String) async throws
    func getPublicURL(bucket: String, path: String) async throws -> URL
}

// MARK: - Storage Repository Implementation

/// Supabase Storageとの連携を管理するRepository
class StorageRepository: StorageRepositoryProtocol {

    private let supabase = SupabaseConfig.shared.client

    /// アップロードタイムアウト（秒）
    private let uploadTimeout: TimeInterval = 30.0

    // MARK: - Upload

    /// ファイルをSupabase Storageにアップロード
    /// - Parameters:
    ///   - bucket: バケット名（例: "audio"）
    ///   - path: ファイルパス（例: "audio/{user_id}/{timestamp}.m4a"）
    ///   - data: アップロードするデータ
    /// - Returns: アップロードされたファイルのPublic URL
    func upload(bucket: String, path: String, data: Data) async throws -> URL {
        print("[StorageRepository] 🚀 upload started")
        print("[StorageRepository] 🗂️ bucket: \(bucket)")
        print("[StorageRepository] 📂 path: \(path)")
        print("[StorageRepository] 📦 data size: \(data.count) bytes (\(Double(data.count) / 1024.0 / 1024.0) MB)")

        // 🔍 認証状態の診断
        await diagnoseAuthenticationState()

        // バリデーション
        guard !bucket.isEmpty else {
            print("[StorageRepository] ❌ Validation failed: bucket is empty")
            throw StorageError.invalidBucket
        }

        guard !path.isEmpty else {
            print("[StorageRepository] ❌ Validation failed: path is empty")
            throw StorageError.invalidPath
        }

        guard !data.isEmpty else {
            print("[StorageRepository] ❌ Validation failed: data is empty")
            throw StorageError.emptyData
        }

        print("[StorageRepository] ✅ Validation passed")

        do {
            // Supabase Storageにアップロード
            let contentType = detectContentType(from: path)
            print("[StorageRepository] 📄 Content-Type: \(contentType)")

            let fileOptions = FileOptions(
                cacheControl: "3600", // 1時間キャッシュ
                contentType: contentType,
                upsert: false // 既存ファイルの上書きを防ぐ
            )
            print("[StorageRepository] ⚙️ FileOptions configured: cacheControl=3600, upsert=false")

            // タイムアウト付きアップロード
            print("[StorageRepository] 📤 Starting Supabase Storage upload (timeout: \(uploadTimeout)s)...")
            try await withTimeout(seconds: uploadTimeout) {
                try await self.supabase.storage
                    .from(bucket)
                    .upload(
                        path: path,
                        file: data,
                        options: fileOptions
                    )
            }

            print("[StorageRepository] ✅ Supabase upload successful: \(path)")

            // Public URLを取得
            print("[StorageRepository] 🔗 Retrieving public URL...")
            let publicURL = try await getPublicURL(bucket: bucket, path: path)
            print("[StorageRepository] ✅ Upload complete. Public URL: \(publicURL.absoluteString)")
            return publicURL

        } catch let error as StorageError {
            print("[StorageRepository] ❌ StorageError: \(error.localizedDescription ?? "Unknown")")
            throw error
        } catch {
            print("[StorageRepository] ❌ Upload failed: \(error.localizedDescription)")
            print("[StorageRepository] Error type: \(type(of: error))")
            print("[StorageRepository] Error details: \(error)")
            throw StorageError.uploadFailed(error.localizedDescription)
        }
    }

    // MARK: - Delete

    /// ファイルをSupabase Storageから削除
    /// - Parameters:
    ///   - bucket: バケット名
    ///   - path: ファイルパス
    func delete(bucket: String, path: String) async throws {
        print("[StorageRepository] Delete started: bucket=\(bucket), path=\(path)")

        guard !bucket.isEmpty else {
            throw StorageError.invalidBucket
        }

        guard !path.isEmpty else {
            throw StorageError.invalidPath
        }

        do {
            try await supabase.storage
                .from(bucket)
                .remove(paths: [path])

            print("[StorageRepository] Delete successful: \(path)")

        } catch {
            print("[StorageRepository] Delete failed: \(error.localizedDescription)")
            throw StorageError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Public URL

    /// ファイルのPublic URLを取得
    /// - Parameters:
    ///   - bucket: バケット名
    ///   - path: ファイルパス
    /// - Returns: Public URL
    func getPublicURL(bucket: String, path: String) async throws -> URL {
        guard !bucket.isEmpty else {
            throw StorageError.invalidBucket
        }

        guard !path.isEmpty else {
            throw StorageError.invalidPath
        }

        do {
            let urlString = try supabase.storage
                .from(bucket)
                .getPublicURL(path: path)
                .absoluteString

            guard let url = URL(string: urlString) else {
                throw StorageError.invalidURL
            }

            // HTTPSであることを確認
            guard url.scheme == "https" else {
                throw StorageError.insecureURL
            }

            print("[StorageRepository] Public URL retrieved: \(url.absoluteString)")
            return url

        } catch let error as StorageError {
            throw error
        } catch {
            print("[StorageRepository] Failed to get public URL: \(error.localizedDescription)")
            throw StorageError.urlGenerationFailed(error.localizedDescription)
        }
    }

    // MARK: - Helper Functions

    /// ファイルパスからContent-Typeを検出
    /// - Parameter path: ファイルパス
    /// - Returns: Content-Type文字列
    private func detectContentType(from path: String) -> String {
        let pathExtension = (path as NSString).pathExtension.lowercased()

        switch pathExtension {
        case "m4a":
            return "audio/mp4"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "aac":
            return "audio/aac"
        default:
            return "application/octet-stream"
        }
    }

    /// タイムアウト付き非同期処理
    /// - Parameters:
    ///   - seconds: タイムアウト時間（秒）
    ///   - operation: 実行する非同期処理
    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // 実際の処理
            group.addTask {
                try await operation()
            }

            // タイムアウト監視
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw StorageError.timeout
            }

            // 最初に完了した方を返す
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Authentication Diagnosis

    /// 認証状態を診断してログ出力
    private func diagnoseAuthenticationState() async {
        print("[StorageRepository] ============================================================")
        print("[StorageRepository] 🔍 AUTHENTICATION DIAGNOSIS")
        print("[StorageRepository] ============================================================")

        do {
            // Supabaseセッション取得
            let session = try await supabase.auth.session

            print("[StorageRepository] ✅ Supabase Session: ACTIVE")
            print("[StorageRepository] 👤 User ID (auth.uid): \(session.user.id)")
            print("[StorageRepository] 📧 Email: \(session.user.email ?? "N/A")")
            print("[StorageRepository] 🔑 Access Token: \(session.accessToken.prefix(50))...")
            print("[StorageRepository] ⏰ Token Expires At: \(session.expiresAt ?? 0)")

            // トークンの有効期限チェック
            let now = Date().timeIntervalSince1970
            let expiresAt = session.expiresAt ?? 0
            let timeRemaining = expiresAt - now

            if timeRemaining > 0 {
                print("[StorageRepository] ⏳ Token Valid For: \(Int(timeRemaining / 60)) minutes")
            } else {
                print("[StorageRepository] ⚠️ WARNING: Token may be expired!")
            }

        } catch {
            print("[StorageRepository] ❌ Supabase Session: NOT FOUND")
            print("[StorageRepository] ❌ Error: \(error.localizedDescription)")
            print("[StorageRepository] ⚠️ This is why RLS policy fails!")
            print("[StorageRepository] ⚠️ User must sign in to upload files")
        }

        print("[StorageRepository] ============================================================")
    }
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case invalidBucket
    case invalidPath
    case emptyData
    case uploadFailed(String)
    case deleteFailed(String)
    case invalidURL
    case insecureURL
    case urlGenerationFailed(String)
    case timeout
    case networkError(String)
    case storageQuotaExceeded  // Requirement 11.6: ストレージ容量制限エラー

    var errorDescription: String? {
        switch self {
        case .invalidBucket:
            return "無効なバケット名です"
        case .invalidPath:
            return "無効なファイルパスです"
        case .emptyData:
            return "アップロードするデータが空です"
        case .uploadFailed(let message):
            return "アップロードに失敗しました: \(message)"
        case .deleteFailed(let message):
            return "削除に失敗しました: \(message)"
        case .invalidURL:
            return "無効なURLが生成されました"
        case .insecureURL:
            return "HTTPSでないURLは使用できません"
        case .urlGenerationFailed(let message):
            return "URL生成に失敗しました: \(message)"
        case .timeout:
            return "タイムアウトしました"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .storageQuotaExceeded:
            // Requirement 11.6: エラーメッセージ「ストレージ容量が不足しています。古い投稿を削除してください」
            return "ストレージ容量が不足しています。古い投稿を削除してください"
        }
    }
}
