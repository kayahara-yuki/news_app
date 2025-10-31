import Foundation
import Supabase
import CoreLocation
import Combine

/// 投稿管理サービス
@MainActor
class PostService: ObservableObject, PostServiceProtocol {
    @Published var posts: [Post] = []
    @Published var nearbyPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let postRepository: PostRepositoryProtocol
    private let audioService: AudioService
    private var realtimePostManager: RealtimePostManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants

    /// ステータス投稿の自動削除時間（秒）
    /// - Note: ステータス投稿は投稿から3時間後に自動削除される
    private static let statusPostExpirationDuration: TimeInterval = 3 * 60 * 60 // 3時間

    init(postRepository: PostRepositoryProtocol = PostRepository(),
         audioService: AudioService? = nil) {
        self.postRepository = postRepository
        self.audioService = audioService ?? AudioService()
        setupRealtimeSubscription()

        // 保存された下書きを読み込み
        loadDraftsFromDisk()
    }

    deinit {
        cancellables.removeAll()
        // Main Actor分離されたメソッドを非同期で呼び出し
        if let manager = realtimePostManager {
            Task { @MainActor in
                manager.stopMonitoring()
            }
        }
    }
    
    // MARK: - リアルタイム更新
    
    private func setupRealtimeSubscription() {
        // リアルタイム機能の初期化
        let dependencies = DependencyContainer.shared
        
        realtimePostManager = RealtimePostManager(
            realtimeService: RealtimeService(),
            postRepository: PostRepository(),
            locationService: dependencies.locationService
        )
        
        // リアルタイム投稿の変更を監視
        realtimePostManager?.$realtimePosts
            .sink { [weak self] posts in
                self?.handleRealtimePostUpdate(posts)
            }
            .store(in: &cancellables)
        
        // 新しい投稿の通知を監視
        NotificationCenter.default.publisher(for: .newPostReceived)
            .sink { [weak self] notification in
                if let post = notification.userInfo?["post"] as? Post {
                    self?.handleNewPost(post)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleRealtimePostUpdate(_ posts: [Post]) {
        // リアルタイム投稿をマージ
        nearbyPosts = posts
    }
    
    private func handleNewPost(_ post: Post) {
        // 新しい投稿をリストの先頭に追加
        nearbyPosts.insert(post, at: 0)

        // Map上にピンを表示するための通知を送信
        if post.canShowOnMap {
            NotificationCenter.default.post(
                name: .newPostCreated,
                object: nil,
                userInfo: ["post": post]
            )
        }
    }
    
    // MARK: - 投稿の取得
    
    /// 近隣の投稿を取得
    func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double) async {
        print("🚀 [PostService] fetchNearbyPosts開始")
        print("📍 [PostService] パラメータ: lat=\(latitude), lng=\(longitude), radius=\(radius)m")

        isLoading = true
        defer { isLoading = false }

        do {
            print("📡 [PostService] Repository呼び出し中...")
            let posts = try await postRepository.fetchNearbyPosts(
                latitude: latitude,
                longitude: longitude,
                radius: radius
            )

            print("📥 [PostService] Repository応答: \(posts.count)件")

            if posts.isEmpty {
                print("⚠️ [PostService] 警告: Repositoryから0件の投稿が返されました")
            } else {
                print("✅ [PostService] 最初の投稿: id=\(posts[0].id), user=\(posts[0].user.username)")
            }

            await MainActor.run {
                self.nearbyPosts = posts
                self.errorMessage = nil
                print("✅ [PostService] nearbyPosts更新完了: \(self.nearbyPosts.count)件")
            }

            // リアルタイム監視を開始
            realtimePostManager?.startMonitoringNearbyPosts(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                radius: radius
            )

        } catch {
            print("❌ [PostService] エラー発生: \(error)")
            print("❌ [PostService] エラー詳細: \(error.localizedDescription)")
            AppLogger.error("投稿取得エラー: \(error)")
            await MainActor.run {
                self.errorMessage = "投稿の取得に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    /// 投稿を作成
    func createPost(_ request: CreatePostRequest) async {
        print("[PostService] 🚀 createPost started")
        print("[PostService] 📝 content: \"\(request.content)\"")
        print("[PostService] 📍 location: lat=\(request.latitude ?? 0), lng=\(request.longitude ?? 0)")
        print("[PostService] 📍 locationName: \"\(request.locationName ?? "")\"")
        print("[PostService] 🔒 visibility: \(request.visibility.rawValue)")
        print("[PostService] ⚡️ isStatusPost: \(request.isStatusPost ?? false)")

        isLoading = true
        defer { isLoading = false }

        do {
            print("[PostService] 📤 Calling postRepository.createPost...")
            let newPost = try await postRepository.createPost(request)
            print("[PostService] ✅ Repository returned post: id=\(newPost.id)")
            print("[PostService] ✅ Post data: content=\"\(newPost.content.prefix(30))...\", lat=\(newPost.latitude ?? 0), lng=\(newPost.longitude ?? 0)")
            print("[PostService] ✅ canShowOnMap: \(newPost.canShowOnMap)")

            await MainActor.run {
                // ローカルリストに追加
                self.nearbyPosts.insert(newPost, at: 0)
                self.errorMessage = nil
                print("[PostService] ✅ Post added to nearbyPosts. Total count: \(self.nearbyPosts.count)")

                // Map上にピンを表示するための通知を送信
                if newPost.canShowOnMap {
                    print("[PostService] 📬 Sending newPostCreated notification...")
                    NotificationCenter.default.post(
                        name: .newPostCreated,
                        object: nil,
                        userInfo: ["post": newPost]
                    )
                    print("[PostService] ✅ Notification sent")
                } else {
                    print("[PostService] ⚠️ Post cannot be shown on map (canShowOnMap=false)")
                }
            }

        } catch {
            print("[PostService] ❌ createPost failed: \(error.localizedDescription)")
            print("[PostService] ❌ Error details: \(error)")

            await MainActor.run {
                self.errorMessage = "投稿の作成に失敗しました: \(error.localizedDescription)"

                // 下書きを保存
                self.saveDraft(
                    content: request.content,
                    latitude: request.latitude,
                    longitude: request.longitude,
                    address: request.locationName,
                    isStatusPost: request.isStatusPost ?? false,
                    failureReason: error.localizedDescription
                )
                print("[PostService] 💾 Draft saved due to error")
            }
        }
    }
    
    /// 投稿にいいねする
    func likePost(id: UUID) async {
        do {
            try await postRepository.likePost(id: id)

            await MainActor.run {
                // ローカルリストのいいね数を更新
                updateLocalPostLikeCount(postID: id, increment: true)
                self.errorMessage = nil
            }

            // いいね後、サーバーから最新データを取得して同期
            await refreshPost(id: id)

        } catch {
            await MainActor.run {
                self.errorMessage = "いいねに失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    /// 投稿のいいねを取り消す
    func unlikePost(id: UUID) async {
        do {
            try await postRepository.unlikePost(id: id)

            await MainActor.run {
                // ローカルリストのいいね数を更新
                updateLocalPostLikeCount(postID: id, increment: false)
                self.errorMessage = nil
            }

            // いいね解除後、サーバーから最新データを取得して同期
            await refreshPost(id: id)

        } catch {
            await MainActor.run {
                self.errorMessage = "いいねの取り消しに失敗しました: \(error.localizedDescription)"
            }
        }
    }

    /// 投稿のいいね状態をチェック
    func checkLikeStatus(postID: UUID, userID: UUID) async -> Bool {
        do {
            return try await postRepository.hasUserLikedPost(id: postID, userID: userID)
        } catch {
            return false
        }
    }

    /// 投稿を取得
    func getPost(id: UUID) async -> Post? {
        do {
            let post = try await postRepository.getPost(id: id)
            return post
        } catch {
            await MainActor.run {
                self.errorMessage = "投稿の取得に失敗しました: \(error.localizedDescription)"
            }
            return nil
        }
    }

    /// 投稿を削除
    /// - Parameter id: 削除する投稿のID
    /// - Note: 音声ファイル付き投稿の場合、音声ファイルも自動的に削除されます
    /// - Requirements: 6.3, 6.5, 10.3
    func deletePost(id: UUID) async {
        // 削除前に投稿を取得して音声URLを確認
        let postToDelete = nearbyPosts.first { $0.id == id } ?? posts.first { $0.id == id }

        do {
            // 1. Supabaseから投稿を削除（関連データも削除される）
            try await postRepository.deletePost(id: id)

            // 2. 音声ファイルが存在する場合は削除
            if let audioURLString = postToDelete?.audioURL,
               let audioURL = URL(string: audioURLString),
               let userID = postToDelete?.user.id {
                do {
                    try await audioService.deleteAudio(audioURL: audioURL, userID: userID)
                    print("[PostService] Audio file deleted successfully for post \(id)")
                } catch {
                    // 音声ファイル削除に失敗しても投稿削除は成功とする
                    print("[PostService] Warning: Failed to delete audio file: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                // 3. ローカルリストから削除
                self.nearbyPosts.removeAll { $0.id == id }
                self.posts.removeAll { $0.id == id }
                self.errorMessage = nil
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "投稿の削除に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Methods

    /// サーバーから投稿の最新データを取得してローカル配列を更新
    private func refreshPost(id: UUID) async {
        do {
            let updatedPost = try await postRepository.getPost(id: id)

            await MainActor.run {
                // nearbyPosts配列を更新
                if let index = nearbyPosts.firstIndex(where: { $0.id == id }) {
                    nearbyPosts[index] = updatedPost
                }

                // posts配列を更新
                if let index = posts.firstIndex(where: { $0.id == id }) {
                    posts[index] = updatedPost
                }
            }
        } catch {
            // エラーは無視（UI更新は行わない）
        }
    }

    // パフォーマンス最適化: 重複コードを削減し、効率的な更新を実現
    private func updateLocalPostLikeCount(postID: UUID, increment: Bool) {
        // ヘルパー関数: Post配列内の特定IDの投稿のいいね数を更新
        func updatePostInArray(_ array: inout [Post], postID: UUID, increment: Bool) -> Bool {
            guard let index = array.firstIndex(where: { $0.id == postID }) else {
                return false
            }

            let updatedPost = array[index]
            let newLikeCount = increment ? updatedPost.likeCount + 1 : max(0, updatedPost.likeCount - 1)

            // Postは値型なので、新しいインスタンスを作成
            array[index] = Post(
                id: updatedPost.id,
                user: updatedPost.user,
                content: updatedPost.content,
                url: updatedPost.url,
                latitude: updatedPost.latitude,
                longitude: updatedPost.longitude,
                address: updatedPost.address,
                category: updatedPost.category,
                visibility: updatedPost.visibility,
                isUrgent: updatedPost.isUrgent,
                isVerified: updatedPost.isVerified,
                likeCount: newLikeCount,
                commentCount: updatedPost.commentCount,
                shareCount: updatedPost.shareCount,
                createdAt: updatedPost.createdAt,
                updatedAt: updatedPost.updatedAt,
                audioURL: updatedPost.audioURL,
                isStatusPost: updatedPost.isStatusPost,
                expiresAt: updatedPost.expiresAt
            )
            return true
        }

        // nearbyPostsとpostsを更新
        updatePostInArray(&nearbyPosts, postID: postID, increment: increment)
        updatePostInArray(&posts, postID: postID, increment: increment)
    }

    // MARK: - Status Post Creation

    /// ステータス投稿を作成
    /// - Parameters:
    ///   - status: ステータスタイプ
    ///   - location: 位置情報
    /// - Throws: 投稿作成エラー
    /// - Requirements: 5.1, 5.2, 6.1
    func createStatusPost(
        status: StatusType,
        location: CLLocationCoordinate2D
    ) async throws {
        print("[PostService] 🚀 createStatusPost started")
        print("[PostService] 📝 status: \(status.rawValue)")
        print("[PostService] 📍 location: lat=\(location.latitude), lng=\(location.longitude)")

        isLoading = true
        defer { isLoading = false }

        do {
            // 自動削除時刻を計算（投稿時刻 + 3時間）
            let expiresAt = Date().addingTimeInterval(Self.statusPostExpirationDuration)
            print("[PostService] ⏰ expiresAt: \(expiresAt)")

            // ステータス投稿リクエストを作成
            let request = CreatePostRequest(
                content: status.rawValue,
                latitude: location.latitude,
                longitude: location.longitude,
                isStatusPost: true,
                expiresAt: expiresAt
            )

            print("[PostService] 📤 Calling postRepository.createPost...")
            let newPost = try await postRepository.createPost(request)
            print("[PostService] ✅ Repository returned post: id=\(newPost.id)")
            print("[PostService] ✅ Post data: isStatusPost=\(newPost.isStatusPost), expiresAt=\(newPost.expiresAt?.description ?? "nil")")
            print("[PostService] ✅ canShowOnMap: \(newPost.canShowOnMap)")

            await MainActor.run {
                // ローカルリストに追加
                self.nearbyPosts.insert(newPost, at: 0)
                self.errorMessage = nil
                print("[PostService] ✅ Status post added to nearbyPosts. Total count: \(self.nearbyPosts.count)")

                // Map上にピンを表示するための通知を送信
                if newPost.canShowOnMap {
                    print("[PostService] 📬 Sending newPostCreated notification...")
                    NotificationCenter.default.post(
                        name: .newPostCreated,
                        object: nil,
                        userInfo: ["post": newPost]
                    )
                    print("[PostService] ✅ Notification sent")
                } else {
                    print("[PostService] ⚠️ Status post cannot be shown on map (canShowOnMap=false)")
                }
            }

            print("[PostService] ✅ createStatusPost completed successfully")

        } catch {
            print("[PostService] ❌ createStatusPost failed: \(error.localizedDescription)")
            print("[PostService] ❌ Error details: \(error)")

            await MainActor.run {
                self.errorMessage = "ステータス投稿の作成に失敗しました: \(error.localizedDescription)"
            }

            throw error
        }
    }

    // MARK: - Audio Post Creation

    /// 音声ファイル付き投稿を作成
    /// - Parameters:
    ///   - content: 投稿内容
    ///   - audioFileURL: ローカル音声ファイルのURL
    ///   - latitude: 緯度
    ///   - longitude: 経度
    ///   - address: 住所（オプション）
    ///   - userID: ユーザーID
    func createPostWithAudio(
        content: String,
        audioFileURL: URL,
        latitude: Double,
        longitude: Double,
        address: String?,
        userID: UUID
    ) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            print("[PostService] Audio post creation started. Content: \(content)")

            // 1. 音声ファイルをアップロード
            print("[PostService] Uploading audio file...")
            let audioURL = try await audioService.uploadAudio(
                fileURL: audioFileURL,
                userID: userID
            )
            print("[PostService] Audio uploaded: \(audioURL.absoluteString)")

            // 2. 音声付き投稿を作成
            // 音声付き投稿は通常投稿として扱う（isStatusPost = false）
            // ステータステキストがcontentに含まれていても、音声があれば自動削除されない
            let request = CreatePostRequest(
                content: content,
                url: nil,  // url欄はニュースリンク用に保持
                latitude: latitude,
                longitude: longitude,
                locationName: address,
                isStatusPost: false,  // 音声付きは通常投稿
                expiresAt: nil         // 自動削除なし
            )

            print("[PostService] Creating post with audio. isStatusPost=false")
            let newPost = try await postRepository.createPostWithAudio(request, audioURL: audioURL.absoluteString)

            await MainActor.run {
                // ローカルリストに追加
                self.nearbyPosts.insert(newPost, at: 0)
                self.errorMessage = nil

                // Map上にピンを表示するための通知を送信
                if newPost.canShowOnMap {
                    NotificationCenter.default.post(
                        name: .newPostCreated,
                        object: nil,
                        userInfo: ["post": newPost]
                    )
                }
            }

            // 3. アップロード成功後、ローカルファイルを削除
            try? FileManager.default.removeItem(at: audioFileURL)
            print("[PostService] Audio post created successfully. PostID: \(newPost.id)")

        } catch {
            print("[PostService] Audio post creation failed: \(error.localizedDescription)")

            // エラー時は下書きを保存し、ローカルファイルを保持（リトライ可能）
            await MainActor.run {
                self.errorMessage = "音声投稿の作成に失敗しました: \(error.localizedDescription)"

                // 下書きを保存
                self.saveDraft(
                    content: content,
                    audioFileURL: audioFileURL,
                    latitude: latitude,
                    longitude: longitude,
                    address: address,
                    isStatusPost: false,
                    failureReason: error.localizedDescription
                )
            }

            throw error
        }
    }


    // MARK: - Draft Management

    /// 保存された下書き一覧
    @Published var savedDrafts: [PostDraft] = []

    /// 下書きを保存
    /// - Parameters:
    ///   - content: 投稿内容
    ///   - audioFileURL: 音声ファイルURL（オプション）
    ///   - latitude: 緯度（オプション）
    ///   - longitude: 経度（オプション）
    ///   - address: 住所（オプション）
    ///   - isStatusPost: ステータス投稿かどうか
    ///   - failureReason: 失敗理由
    /// - Requirements: 11.4, 11.5
    private func saveDraft(
        content: String,
        audioFileURL: URL? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        isStatusPost: Bool = false,
        failureReason: String?
    ) {
        let draft = PostDraft(
            content: content,
            audioFileURL: audioFileURL,
            latitude: latitude,
            longitude: longitude,
            address: address,
            isStatusPost: isStatusPost,
            failureReason: failureReason
        )

        savedDrafts.append(draft)
        saveDraftsToDisk()

        print("[PostService] Draft saved: \(draft.id)")
    }

    /// 保存された下書きを取得
    /// - Returns: 下書き一覧
    func getSavedDrafts() async -> [PostDraft] {
        return savedDrafts
    }

    /// 下書きを再送信
    /// - Parameter draft: 再送信する下書き
    /// - Throws: 送信エラー
    /// - Requirements: 11.5
    func retrySendingDraft(_ draft: PostDraft) async throws {
        print("[PostService] Retrying draft: \(draft.id)")

        // 音声ファイル付きの下書きの場合
        if let audioFileURL = draft.audioFileURL,
           let latitude = draft.latitude,
           let longitude = draft.longitude {

            // UserIDを取得（仮実装: 実際にはAuthServiceから取得）
            let userID = UUID() // TODO: 実際のユーザーIDを取得

            try await createPostWithAudio(
                content: draft.content,
                audioFileURL: audioFileURL,
                latitude: latitude,
                longitude: longitude,
                address: draft.address,
                userID: userID
            )
        } else {
            // 通常投稿の場合
            let request = CreatePostRequest(
                content: draft.content,
                latitude: draft.latitude,
                longitude: draft.longitude,
                locationName: draft.address,
                isStatusPost: draft.isStatusPost
            )

            await createPost(request)
        }

        // 送信成功後、下書きを削除
        await deleteDraft(draft)
    }

    /// 下書きを削除
    /// - Parameter draft: 削除する下書き
    func deleteDraft(_ draft: PostDraft) async {
        savedDrafts.removeAll { $0.id == draft.id }
        saveDraftsToDisk()

        // 音声ファイルがある場合は削除
        if let audioFileURL = draft.audioFileURL {
            try? FileManager.default.removeItem(at: audioFileURL)
            print("[PostService] Deleted draft audio file: \(audioFileURL.lastPathComponent)")
        }

        print("[PostService] Draft deleted: \(draft.id)")
    }

    // MARK: - Draft Persistence

    /// 下書きをディスクに保存
    private func saveDraftsToDisk() {
        guard let data = try? JSONEncoder().encode(savedDrafts) else {
            print("[PostService] Failed to encode drafts")
            return
        }

        let fileURL = getDraftsFileURL()
        do {
            try data.write(to: fileURL)
            print("[PostService] Drafts saved to disk: \(savedDrafts.count) items")
        } catch {
            print("[PostService] Failed to save drafts to disk: \(error)")
        }
    }

    /// ディスクから下書きを読み込み
    private func loadDraftsFromDisk() {
        let fileURL = getDraftsFileURL()

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[PostService] No drafts file found")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            savedDrafts = try JSONDecoder().decode([PostDraft].self, from: data)
            print("[PostService] Drafts loaded from disk: \(savedDrafts.count) items")
        } catch {
            print("[PostService] Failed to load drafts from disk: \(error)")
        }
    }

    /// 下書き保存ファイルのURLを取得
    private func getDraftsFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        return documentsDirectory.appendingPathComponent("post_drafts.json")
    }
}