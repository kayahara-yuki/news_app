import Foundation
import SwiftUI
import CoreLocation
import Combine
import Supabase

// MARK: - Protocols for Dependency Injection

protocol AuthServiceProtocol: ObservableObject {
    var currentUser: UserProfile? { get }
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    func signIn(email: String, password: String) async
    func signUp(email: String, password: String, username: String, displayName: String?) async
    func signOut() async
    func resetPassword(email: String) async
    func updateProfile(displayName: String?, bio: String?, location: String?) async
}

protocol PostServiceProtocol: ObservableObject {
    var nearbyPosts: [Post] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double) async
    func createPost(_ post: CreatePostRequest) async
    func deletePost(id: UUID) async
    func likePost(id: UUID) async
    func unlikePost(id: UUID) async
}

protocol LocationServiceProtocol: ObservableObject {
    var currentLocation: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var isLocationEnabled: Bool { get }

    func requestPermission()
    func getCurrentLocation() async throws -> CLLocation
    func startMonitoring()
    func stopMonitoring()
    func geocode(address: String) async throws -> CLLocationCoordinate2D
}

protocol EmergencyServiceProtocol: ObservableObject {
    var activeEmergencies: [EmergencyEvent] { get }
    var nearbyShelters: [Shelter] { get }
    
    func fetchNearbyEmergencies(location: CLLocationCoordinate2D) async
    func fetchNearbyShelters(location: CLLocationCoordinate2D) async
}

protocol NotificationServiceProtocol: ObservableObject {
    var hasPermission: Bool { get }
    
    func requestPermission() async
    func sendLocalNotification(title: String, body: String)
}

/// Clean Architecture準拠の依存性注入コンテナ
@MainActor
class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    // MARK: - Services (実装の詳細)
    private lazy var _authService: AuthService = AuthService()
    private lazy var _postService: PostService = PostService()
    private lazy var _locationService: LocationService = LocationService()
    private lazy var _locationPrivacyService: LocationPrivacyService = LocationPrivacyService()
    private lazy var _emergencyService: EmergencyService = EmergencyService()
    private lazy var _notificationService: NotificationService = NotificationService()
    private lazy var _pushNotificationService: PushNotificationService = PushNotificationService()
    private lazy var _notificationManager: NotificationManager = NotificationManager(pushNotificationService: _pushNotificationService, locationService: _locationService)
    private lazy var _emergencyNotificationService: EmergencyNotificationService = EmergencyNotificationService(pushNotificationService: _pushNotificationService, locationService: _locationService, realtimeService: _realtimeService)
    private lazy var _localStorageManager: LocalStorageManager = LocalStorageManager.shared
    private lazy var _locationTrackingService: LocationTrackingService = LocationTrackingService(locationService: _locationService, locationPrivacyService: _locationPrivacyService)
    private lazy var _realtimeService: RealtimeService = RealtimeService()
    private lazy var _realtimePostManager: RealtimePostManager = RealtimePostManager(realtimeService: _realtimeService, postRepository: _postRepository, locationService: _locationService)
    private lazy var _realtimeLocationManager: RealtimeLocationManager = RealtimeLocationManager(realtimeService: _realtimeService, locationService: _locationService, locationPrivacyService: _locationPrivacyService)
    private lazy var _mediaUploadService: MediaUploadService = MediaUploadService()
    private lazy var _imagePickerService: ImagePickerService = ImagePickerService()
    private lazy var _mediaProcessingService: MediaProcessingService = MediaProcessingService()
    private lazy var _commentService: CommentService = CommentService()
    private lazy var _socialService: SocialService = SocialService()

    // MARK: - Repository Protocols
    private lazy var _userRepository: UserRepositoryProtocol = UserRepository()
    private lazy var _postRepository: PostRepositoryProtocol = PostRepository()
    private lazy var _emergencyRepository: EmergencyRepositoryProtocol = EmergencyRepository()
    
    // MARK: - UseCase Protocols
    private lazy var _authUseCase: AuthUseCaseProtocol = AuthUseCase(authService: _authService, userRepository: _userRepository)
    private lazy var _postUseCase: PostUseCaseProtocol = PostUseCase(postService: _postService, postRepository: _postRepository)
    private lazy var _mapUseCase: MapUseCaseProtocol = MapUseCase(locationService: _locationService, postRepository: _postRepository)
    private lazy var _emergencyUseCase: EmergencyUseCaseProtocol = EmergencyUseCase(emergencyService: _emergencyService, emergencyRepository: _emergencyRepository)

    // MARK: - ViewModels
    private lazy var _nearbyPostsViewModel: NearbyPostsViewModel = NearbyPostsViewModel()
    
    private init() {
        setupDependencies()
    }
    
    
    private func setupDependencies() {
        // PostServiceの初期化は lazy varで自動処理される
        
        // サービス間の依存関係を設定
        _emergencyService.locationService = _locationService
        _emergencyService.notificationService = _notificationService
        
        // Clean Architecture: Use Cases が Services と Repositories に依存
        // ViewModels は Use Cases にのみ依存
    }
    
    // MARK: - Public Service Access (Protocol準拠)
    
    var authService: any AuthServiceProtocol { _authService }
    var postService: any PostServiceProtocol { _postService }
    var locationService: any LocationServiceProtocol { _locationService }
    var locationPrivacyService: LocationPrivacyService { _locationPrivacyService }
    var emergencyService: any EmergencyServiceProtocol { _emergencyService }
    var notificationService: any NotificationServiceProtocol { _notificationService }
    var pushNotificationService: PushNotificationService { _pushNotificationService }
    var notificationManager: NotificationManager { _notificationManager }
    var emergencyNotificationService: EmergencyNotificationService { _emergencyNotificationService }
    var localStorageManager: LocalStorageManager { _localStorageManager }
    var locationTrackingService: LocationTrackingService { _locationTrackingService }
    var realtimeService: RealtimeService { _realtimeService }
    var realtimePostManager: RealtimePostManager { _realtimePostManager }
    var realtimeLocationManager: RealtimeLocationManager { _realtimeLocationManager }
    var mediaUploadService: MediaUploadService { _mediaUploadService }
    var imagePickerService: ImagePickerService { _imagePickerService }
    var mediaProcessingService: MediaProcessingService { _mediaProcessingService }
    var commentService: CommentService { _commentService }
    var socialService: SocialService { _socialService }

    // MARK: - Repository Access
    
    var userRepository: any UserRepositoryProtocol { _userRepository }
    var postRepository: any PostRepositoryProtocol { _postRepository }
    var emergencyRepository: any EmergencyRepositoryProtocol { _emergencyRepository }
    
    // MARK: - UseCase Access

    var authUseCase: any AuthUseCaseProtocol { _authUseCase }
    var postUseCase: any PostUseCaseProtocol { _postUseCase }
    var mapUseCase: any MapUseCaseProtocol { _mapUseCase }
    var emergencyUseCase: any EmergencyUseCaseProtocol { _emergencyUseCase }

    // MARK: - ViewModel Access

    var nearbyPostsViewModel: NearbyPostsViewModel { _nearbyPostsViewModel }
}

// MARK: - Additional Services

@MainActor
class EmergencyService: ObservableObject, EmergencyServiceProtocol {
    @Published var activeEmergencies: [EmergencyEvent] = []
    @Published var nearbyShelters: [Shelter] = []
    
    var locationService: LocationService?
    var notificationService: NotificationService?
    
    init() {
        // 初期化処理
    }
    
    func fetchNearbyEmergencies(location: CLLocationCoordinate2D) async {
        // 緊急事態取得の実装（後で追加）
    }
    
    func fetchNearbyShelters(location: CLLocationCoordinate2D) async {
        // 避難所取得の実装（後で追加）
    }
}

@MainActor
class NotificationService: ObservableObject, NotificationServiceProtocol {
    @Published var hasPermission = false
    
    func requestPermission() async {
        // プッシュ通知の許可要求実装
    }
    
    func sendLocalNotification(title: String, body: String) {
        // ローカル通知の送信実装
    }
}

// MARK: - SwiftUI Environment Keys

struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - ViewModifier for Dependency Injection

struct DependencyInjection: ViewModifier {
    let container: DependencyContainer
    
    func body(content: Content) -> some View {
        content
            .environmentObject(container.authService as! AuthService)
            .environmentObject(container.postService as! PostService)
            .environmentObject(container.locationService as! LocationService)
            .environmentObject(container.locationPrivacyService)
            .environmentObject(container.emergencyService as! EmergencyService)
            .environmentObject(container.notificationService as! NotificationService)
            .environmentObject(container.pushNotificationService)
            .environmentObject(container.notificationManager)
            .environmentObject(container.emergencyNotificationService)
            .environmentObject(container.localStorageManager)
            .environmentObject(container.locationTrackingService)
            .environmentObject(container.mediaUploadService)
            .environmentObject(container.imagePickerService)
            .environmentObject(container.mediaProcessingService)
            .environmentObject(container.commentService)
            .environmentObject(container.socialService)
            .environment(\.dependencies, container)
    }
}

// MARK: - Clean Architecture ViewModifier

struct CleanArchitectureInjection: ViewModifier {
    let container: DependencyContainer
    
    func body(content: Content) -> some View {
        content
            .environment(\.dependencies, container)
            .environment(\.authUseCase, container.authUseCase)
            .environment(\.postUseCase, container.postUseCase)
            .environment(\.mapUseCase, container.mapUseCase)
            .environment(\.emergencyUseCase, container.emergencyUseCase)
    }
}

extension View {
    func withDependencies(_ container: DependencyContainer = .shared) -> some View {
        modifier(DependencyInjection(container: container))
    }
    
    func withCleanArchitecture(_ container: DependencyContainer = .shared) -> some View {
        modifier(CleanArchitectureInjection(container: container))
    }
}

// MARK: - Environment Keys for UseCases

struct AuthUseCaseKey: EnvironmentKey {
    static let defaultValue: any AuthUseCaseProtocol = DependencyContainer.shared.authUseCase
}

struct PostUseCaseKey: EnvironmentKey {
    static let defaultValue: any PostUseCaseProtocol = DependencyContainer.shared.postUseCase
}

struct MapUseCaseKey: EnvironmentKey {
    static let defaultValue: any MapUseCaseProtocol = DependencyContainer.shared.mapUseCase
}

struct EmergencyUseCaseKey: EnvironmentKey {
    static let defaultValue: any EmergencyUseCaseProtocol = DependencyContainer.shared.emergencyUseCase
}

extension EnvironmentValues {
    var authUseCase: any AuthUseCaseProtocol {
        get { self[AuthUseCaseKey.self] }
        set { self[AuthUseCaseKey.self] = newValue }
    }
    
    var postUseCase: any PostUseCaseProtocol {
        get { self[PostUseCaseKey.self] }
        set { self[PostUseCaseKey.self] = newValue }
    }
    
    var mapUseCase: any MapUseCaseProtocol {
        get { self[MapUseCaseKey.self] }
        set { self[MapUseCaseKey.self] = newValue }
    }
    
    var emergencyUseCase: any EmergencyUseCaseProtocol {
        get { self[EmergencyUseCaseKey.self] }
        set { self[EmergencyUseCaseKey.self] = newValue }
    }
}