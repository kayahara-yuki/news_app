import SwiftUI
import MapKit
import Combine

/// 投稿作成画面のViewModel
///
/// 責務:
/// - 投稿作成の状態管理
/// - ステータス投稿と通常投稿の判定ロジック
/// - 投稿作成処理のオーケストレーション
@MainActor
class PostCreationViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var postContent: String = ""
    @Published var selectedLocation: CLLocationCoordinate2D?
    @Published var locationName: String = ""
    @Published var visibility: PostVisibility = .public
    @Published var allowComments: Bool = true
    @Published var emergencyLevel: EmergencyLevel?
    @Published var tags: Set<String> = []
    @Published var urlInput: String = ""
    @Published var urlMetadata: URLMetadata?

    // 音声録音関連
    @Published var recordedAudioURL: URL?

    // ステータス投稿関連
    @Published var selectedStatus: StatusType?

    // UI状態
    @Published var isUploading: Bool = false
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""

    // MARK: - Dependencies

    private let postService: PostService
    private let authService: AuthService
    private let locationService: LocationService

    // MARK: - Constants

    private let maxContentLength = 1000

    // MARK: - Initializer

    init(
        postService: PostService,
        authService: AuthService,
        locationService: LocationService
    ) {
        self.postService = postService
        self.authService = authService
        self.locationService = locationService
    }

    // Convenience initializer for production use
    convenience init() {
        // この初期化子は実際のアプリで使用される想定
        // テスト時はDI可能なinitを使用
        fatalError("Use dependency injection initializer for testing")
    }

    // MARK: - Public Methods

    /// ステータス投稿として作成すべきかを判定
    ///
    /// 判定ロジック:
    /// 1. ステータスが選択されている
    /// 2. 投稿内容がステータステキストと完全一致
    /// 3. 音声ファイルが録音されていない
    ///
    /// - Returns: ステータス投稿として作成する場合true
    func shouldCreateAsStatusPost() -> Bool {
        // ステータスが選択されていない場合、通常投稿
        guard let status = selectedStatus else {
            return false
        }

        // 投稿内容が空の場合、通常投稿
        guard !postContent.isEmpty else {
            return false
        }

        // 音声が録音されている場合、通常投稿（自動削除対象外）
        if recordedAudioURL != nil {
            return false
        }

        // 投稿内容がステータステキストと完全一致する場合のみステータス投稿
        let trimmedContent = postContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusText = status.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedContent == statusText
    }

    /// 投稿を作成
    ///
    /// ステータス投稿か通常投稿かを判定し、適切なServiceメソッドを呼び出す
    func createPost() async throws {
        print("[PostCreationViewModel] 🚀 createPost started")
        print("[PostCreationViewModel] 📝 postContent: \"\(postContent)\"")
        print("[PostCreationViewModel] 🎤 recordedAudioURL: \(recordedAudioURL?.absoluteString ?? "nil")")
        print("[PostCreationViewModel] 📍 selectedLocation: \(selectedLocation != nil ? "lat=\(selectedLocation!.latitude), lng=\(selectedLocation!.longitude)" : "nil")")
        print("[PostCreationViewModel] 📍 locationName: \"\(locationName)\"")

        guard !postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[PostCreationViewModel] ❌ Empty content error")
            throw PostCreationError.emptyContent
        }

        guard let userID = authService.currentUser?.id else {
            print("[PostCreationViewModel] ❌ User not authenticated")
            throw PostCreationError.userNotAuthenticated
        }

        guard let location = selectedLocation else {
            print("[PostCreationViewModel] ❌ Location not available")
            throw PostCreationError.locationNotAvailable
        }

        print("[PostCreationViewModel] ✅ Validation passed. userID=\(userID.uuidString)")
        isUploading = true

        do {
            // 音声付き投稿の場合
            if let audioURL = recordedAudioURL {
                print("[PostCreationViewModel] 📤 Creating post with audio...")
                // 音声付き投稿は常に通常投稿として扱う
                try await postService.createPostWithAudio(
                    content: postContent,
                    audioFileURL: audioURL,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    address: locationName,
                    userID: userID
                )

                print("[PostCreationViewModel] ✅ Post with audio created. isStatusPost: false")

            } else if shouldCreateAsStatusPost(), let status = selectedStatus {
                print("[PostCreationViewModel] 📤 Creating status post...")
                // ステータス投稿として作成
                try await postService.createStatusPost(
                    status: status,
                    location: location
                )

                print("[PostCreationViewModel] ✅ Status post created. isStatusPost: true, expiresAt: +3h")

            } else {
                print("[PostCreationViewModel] 📤 Creating normal post...")
                // 通常の投稿（音声なし、ステータスなし、またはステータス+追加テキスト）
                let request = CreatePostRequest(
                    content: postContent,
                    url: urlInput.isEmpty ? nil : urlInput,
                    urlMetadata: urlMetadata,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    locationName: locationName,
                    visibility: visibility,
                    allowComments: allowComments,
                    emergencyLevel: emergencyLevel,
                    tags: Array(tags),
                    images: []
                )

                print("[PostCreationViewModel] 📤 Request: lat=\(request.latitude ?? 0), lng=\(request.longitude ?? 0), address=\"\(request.locationName ?? "")\"")
                try await postService.createPost(request)

                print("[PostCreationViewModel] ✅ Normal post created. isStatusPost: false")
            }

            isUploading = false
            print("[PostCreationViewModel] ✅ createPost completed successfully")

        } catch {
            isUploading = false
            print("[PostCreationViewModel] ❌ createPost failed: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Errors

enum PostCreationError: LocalizedError {
    case emptyContent
    case userNotAuthenticated
    case locationNotAvailable

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "投稿内容を入力してください"
        case .userNotAuthenticated:
            return "ログインしてください"
        case .locationNotAvailable:
            return "位置情報を取得できません"
        }
    }
}
