import XCTest
import MapKit
@testable import LocationNewsSNS

/// PostCreationViewModelのテスト
///
/// タスク5.2「通常投稿とステータス投稿の判定ロジック」のテスト
/// - ステータス選択のみ→ステータス投稿(自動削除あり)
/// - テキスト編集でステータス以外の内容追加→通常投稿(自動削除なし)
/// - 投稿作成時のisStatusPost判定ロジック
@MainActor
final class PostCreationViewModelTests: XCTestCase {

    var viewModel: PostCreationViewModel!
    var mockPostService: MockPostService!
    var mockAuthService: MockAuthService!
    var mockLocationService: MockLocationService!

    override func setUp() {
        super.setUp()
        mockPostService = MockPostService()
        mockAuthService = MockAuthService()
        mockLocationService = MockLocationService()

        viewModel = PostCreationViewModel(
            postService: mockPostService,
            authService: mockAuthService,
            locationService: mockLocationService
        )
    }

    override func tearDown() {
        viewModel = nil
        mockPostService = nil
        mockAuthService = nil
        mockLocationService = nil
        super.tearDown()
    }

    // MARK: - Test Cases for Task 5.2

    /// Requirement 8.5: ステータス選択のみ→ステータス投稿(自動削除あり)
    func testStatusOnlyCreatesStatusPost() async throws {
        // Given: ステータスのみが選択されている
        viewModel.selectedStatus = .cafe
        viewModel.postContent = StatusType.cafe.rawValue // "☕ カフェなう"
        viewModel.recordedAudioURL = nil // 音声なし

        // 位置情報を設定
        let location = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        viewModel.selectedLocation = location

        // When: shouldCreateAsStatusPost()を呼び出す
        let shouldBeStatusPost = viewModel.shouldCreateAsStatusPost()

        // Then: ステータス投稿として判定される
        XCTAssertTrue(shouldBeStatusPost, "ステータスのみ選択された場合、ステータス投稿として判定されるべき")
    }

    /// Requirement 8.5: テキスト編集でステータス以外の内容追加→通常投稿(自動削除なし)
    func testStatusWithManualTextCreatesNormalPost() async throws {
        // Given: ステータスが選択され、その後テキストが手動編集されている
        viewModel.selectedStatus = .cafe
        viewModel.postContent = "☕ カフェなう 今日は寒いです" // ステータステキスト + 追加テキスト
        viewModel.recordedAudioURL = nil // 音声なし

        // When: shouldCreateAsStatusPost()を呼び出す
        let shouldBeStatusPost = viewModel.shouldCreateAsStatusPost()

        // Then: 通常投稿として判定される
        XCTAssertFalse(shouldBeStatusPost, "ステータステキスト以外の内容が追加された場合、通常投稿として判定されるべき")
    }

    /// 音声が録音されている場合、ステータス選択があっても通常投稿として扱う
    func testStatusWithAudioCreatesNormalPost() async throws {
        // Given: ステータスが選択され、音声も録音されている
        viewModel.selectedStatus = .cafe
        viewModel.postContent = StatusType.cafe.rawValue // "☕ カフェなう"
        viewModel.recordedAudioURL = URL(fileURLWithPath: "/tmp/test_audio.m4a")

        // When: shouldCreateAsStatusPost()を呼び出す
        let shouldBeStatusPost = viewModel.shouldCreateAsStatusPost()

        // Then: 通常投稿として判定される（音声付きは自動削除対象外）
        XCTAssertFalse(shouldBeStatusPost, "音声が録音されている場合、ステータス投稿ではなく通常投稿として判定されるべき")
    }

    /// ステータス未選択の場合、通常投稿として扱う
    func testNoStatusCreatesNormalPost() async throws {
        // Given: ステータスが選択されていない
        viewModel.selectedStatus = nil
        viewModel.postContent = "今日はいい天気です"
        viewModel.recordedAudioURL = nil

        // When: shouldCreateAsStatusPost()を呼び出す
        let shouldBeStatusPost = viewModel.shouldCreateAsStatusPost()

        // Then: 通常投稿として判定される
        XCTAssertFalse(shouldBeStatusPost, "ステータスが選択されていない場合、通常投稿として判定されるべき")
    }

    /// 投稿内容が空の場合、ステータス投稿として扱わない
    func testEmptyContentCreatesNormalPost() async throws {
        // Given: 投稿内容が空
        viewModel.selectedStatus = .cafe
        viewModel.postContent = ""
        viewModel.recordedAudioURL = nil

        // When: shouldCreateAsStatusPost()を呼び出す
        let shouldBeStatusPost = viewModel.shouldCreateAsStatusPost()

        // Then: 通常投稿として判定される
        XCTAssertFalse(shouldBeStatusPost, "投稿内容が空の場合、ステータス投稿として判定されるべきではない")
    }

    /// isStatusPostフラグの判定ロジックの包括的テスト
    func testIsStatusPostDeterminationLogic() async throws {
        // Case 1: ステータスのみ選択 → ステータス投稿
        viewModel.selectedStatus = .lunch
        viewModel.postContent = StatusType.lunch.rawValue // "🍴 ランチ中"
        viewModel.recordedAudioURL = nil
        XCTAssertTrue(viewModel.shouldCreateAsStatusPost())

        // Case 2: ステータス + 追加テキスト → 通常投稿
        viewModel.selectedStatus = .lunch
        viewModel.postContent = "🍴 ランチ中 美味しいラーメン"
        viewModel.recordedAudioURL = nil
        XCTAssertFalse(viewModel.shouldCreateAsStatusPost())

        // Case 3: ステータス + 音声 → 通常投稿
        viewModel.selectedStatus = .cafe
        viewModel.postContent = StatusType.cafe.rawValue
        viewModel.recordedAudioURL = URL(fileURLWithPath: "/tmp/audio.m4a")
        XCTAssertFalse(viewModel.shouldCreateAsStatusPost())

        // Case 4: ステータス未選択 → 通常投稿
        viewModel.selectedStatus = nil
        viewModel.postContent = "普通の投稿です"
        viewModel.recordedAudioURL = nil
        XCTAssertFalse(viewModel.shouldCreateAsStatusPost())

        // Case 5: 空の投稿内容 → 通常投稿
        viewModel.selectedStatus = .cafe
        viewModel.postContent = ""
        viewModel.recordedAudioURL = nil
        XCTAssertFalse(viewModel.shouldCreateAsStatusPost())
    }

    /// createPost()メソッドがステータス投稿判定に基づいて適切なServiceメソッドを呼び出す
    func testCreatePostCallsCorrectServiceMethod() async throws {
        // Given: 位置情報とユーザーIDが設定されている
        let location = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        viewModel.selectedLocation = location
        mockAuthService.currentUser = UserProfile(
            id: UUID(),
            username: "testuser",
            email: "test@example.com",
            displayName: nil,
            avatarURL: nil,
            bio: nil,
            website: nil,
            location: nil,
            createdAt: Date(),
            role: "user"
        )

        // Case 1: ステータス投稿の場合、createStatusPost()が呼ばれる
        viewModel.selectedStatus = .cafe
        viewModel.postContent = StatusType.cafe.rawValue
        viewModel.recordedAudioURL = nil

        try await viewModel.createPost()

        XCTAssertTrue(mockPostService.createStatusPostCalled, "ステータス投稿の場合、createStatusPost()が呼ばれるべき")
        XCTAssertFalse(mockPostService.createPostWithAudioCalled, "ステータス投稿の場合、createPostWithAudio()は呼ばれないべき")

        // リセット
        mockPostService.createStatusPostCalled = false
        mockPostService.createPostWithAudioCalled = false

        // Case 2: 音声付き投稿の場合、createPostWithAudio()が呼ばれる
        viewModel.selectedStatus = .cafe
        viewModel.postContent = StatusType.cafe.rawValue
        viewModel.recordedAudioURL = URL(fileURLWithPath: "/tmp/audio.m4a")

        try await viewModel.createPost()

        XCTAssertTrue(mockPostService.createPostWithAudioCalled, "音声付き投稿の場合、createPostWithAudio()が呼ばれるべき")
        XCTAssertFalse(mockPostService.createStatusPostCalled, "音声付き投稿の場合、createStatusPost()は呼ばれないべき")
    }
}

// MARK: - Mock Services (PostCreationViewTests.swiftから移動)

class MockPostService: PostService {
    var createPostWithAudioCalled = false
    var createStatusPostCalled = false
    var lastCreatedPost: Post?

    override init() {
        super.init()
    }

    override func createPostWithAudio(
        content: String,
        audioFileURL: URL,
        latitude: Double,
        longitude: Double,
        address: String,
        userID: UUID
    ) async throws -> Post {
        createPostWithAudioCalled = true

        // モック投稿を返す
        let mockPost = Post(
            id: UUID(),
            user: UserProfile(id: userID, username: "testuser", email: "test@example.com", displayName: nil, avatarURL: nil, bio: nil, website: nil, location: nil, createdAt: Date(), role: "user"),
            content: content,
            url: nil,
            latitude: latitude,
            longitude: longitude,
            address: address,
            category: .other,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            audioURL: audioFileURL.absoluteString,
            isStatusPost: false,
            expiresAt: nil
        )

        lastCreatedPost = mockPost
        return mockPost
    }

    override func createStatusPost(status: StatusType, location: CLLocationCoordinate2D) async throws -> Post {
        createStatusPostCalled = true

        // モック投稿を返す
        let mockPost = Post(
            id: UUID(),
            user: UserProfile(id: UUID(), username: "testuser", email: "test@example.com", displayName: nil, avatarURL: nil, bio: nil, website: nil, location: nil, createdAt: Date(), role: "user"),
            content: status.rawValue,
            url: nil,
            latitude: location.latitude,
            longitude: location.longitude,
            address: "テスト地点",
            category: .other,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            audioURL: nil,
            isStatusPost: true,
            expiresAt: Date().addingTimeInterval(3 * 3600)
        )

        lastCreatedPost = mockPost
        return mockPost
    }
}

class MockAuthService: AuthService {
    var mockCurrentUser: UserProfile?

    override var currentUser: UserProfile? {
        get {
            return mockCurrentUser
        }
        set {
            mockCurrentUser = newValue
        }
    }
}

class MockLocationService: LocationService {
    var mockCurrentLocation: CLLocation?

    override var currentLocation: CLLocation? {
        get {
            return mockCurrentLocation ?? CLLocation(latitude: 35.6812, longitude: 139.7671)
        }
        set {
            mockCurrentLocation = newValue
        }
    }
}
