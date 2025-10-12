import Foundation
import Combine
import CoreLocation

// MARK: - Emergency UseCase Protocol

protocol EmergencyUseCaseProtocol {
    func fetchNearbyEmergencies(location: CLLocationCoordinate2D, radius: Double) async throws -> [EmergencyEvent]
    func fetchNearbyShelters(location: CLLocationCoordinate2D, radius: Double) async throws -> [Shelter]
    func createEmergencyPost(_ request: EmergencyPostRequest) async throws -> Post
    func reportSafety(location: CLLocationCoordinate2D, status: SafetyStatus, message: String?) async throws
    func subscribeToEmergencyAlerts(location: CLLocationCoordinate2D, radius: Double) async throws
    func unsubscribeFromEmergencyAlerts() async throws
    func getNearestShelter(from location: CLLocationCoordinate2D) async throws -> Shelter?
    func getEvacuationRoute(from source: CLLocationCoordinate2D, to shelterId: UUID) async throws -> EvacuationRoute
    func reportEmergency(_ request: EmergencyReportRequest) async throws -> EmergencyEvent
}

// MARK: - Emergency UseCase Implementation

class EmergencyUseCase: EmergencyUseCaseProtocol {
    private let emergencyService: any EmergencyServiceProtocol
    private let emergencyRepository: any EmergencyRepositoryProtocol
    
    init(emergencyService: any EmergencyServiceProtocol, emergencyRepository: any EmergencyRepositoryProtocol) {
        self.emergencyService = emergencyService
        self.emergencyRepository = emergencyRepository
    }
    
    func fetchNearbyEmergencies(location: CLLocationCoordinate2D, radius: Double) async throws -> [EmergencyEvent] {
        // バリデーション
        guard (-90...90).contains(location.latitude) else {
            throw EmergencyError.invalidLocation("緯度が無効です")
        }
        
        guard (-180...180).contains(location.longitude) else {
            throw EmergencyError.invalidLocation("経度が無効です")
        }
        
        guard radius > 0 && radius <= 100000 else { // 最大100km
            throw EmergencyError.invalidRadius
        }
        
        return try await emergencyRepository.fetchNearbyEmergencies(
            latitude: location.latitude,
            longitude: location.longitude,
            radius: radius
        )
    }
    
    func fetchNearbyShelters(location: CLLocationCoordinate2D, radius: Double) async throws -> [Shelter] {
        // バリデーション
        guard (-90...90).contains(location.latitude) else {
            throw EmergencyError.invalidLocation("緯度が無効です")
        }
        
        guard (-180...180).contains(location.longitude) else {
            throw EmergencyError.invalidLocation("経度が無効です")
        }
        
        guard radius > 0 && radius <= 100000 else {
            throw EmergencyError.invalidRadius
        }
        
        let allShelters = try await emergencyRepository.fetchNearbyShelters(
            latitude: location.latitude,
            longitude: location.longitude,
            radius: radius
        )
        
        // 運営中の避難所のみフィルター
        return allShelters.filter { $0.status == .open }
    }
    
    func createEmergencyPost(_ request: EmergencyPostRequest) async throws -> Post {
        // バリデーション
        guard !request.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmergencyError.emptyContent
        }
        
        guard request.content.count <= 2000 else {
            throw EmergencyError.contentTooLong
        }
        
        guard request.emergencyLevel != nil else {
            throw EmergencyError.missingEmergencyLevel
        }
        
        // 位置情報の検証
        if let latitude = request.latitude, let longitude = request.longitude {
            guard (-90...90).contains(latitude) && (-180...180).contains(longitude) else {
                throw EmergencyError.invalidLocation("位置情報が無効です")
            }
        }
        
        // 緊急投稿作成
        let createPostRequest = CreatePostRequest(
            content: request.content,
            latitude: request.latitude,
            longitude: request.longitude,
            locationName: request.address,
            visibility: .public, // 緊急投稿は常に公開
            allowComments: true,
            emergencyLevel: request.emergencyLevel,
            tags: nil,
            images: []
        )
        
        let post = try await emergencyRepository.createEmergencyPost(createPostRequest)
        
        // 緊急通知の送信
        try await sendEmergencyNotification(for: post)
        
        return post
    }
    
    func reportSafety(location: CLLocationCoordinate2D, status: SafetyStatus, message: String?) async throws {
        // バリデーション
        guard (-90...90).contains(location.latitude) && (-180...180).contains(location.longitude) else {
            throw EmergencyError.invalidLocation("位置情報が無効です")
        }
        
        if let message = message {
            guard message.count <= 500 else {
                throw EmergencyError.messageTooLong
            }
        }
        
        let safetyReport = SafetyReport(
            location: location,
            status: status,
            message: message,
            timestamp: Date()
        )
        
        try await emergencyRepository.reportSafety(safetyReport)
    }
    
    func subscribeToEmergencyAlerts(location: CLLocationCoordinate2D, radius: Double) async throws {
        guard radius > 0 && radius <= 100000 else {
            throw EmergencyError.invalidRadius
        }
        
        let subscription = EmergencyAlertSubscription(
            location: location,
            radius: radius,
            subscribedAt: Date()
        )
        
        try await emergencyRepository.subscribeToEmergencyAlerts(subscription)
    }
    
    func unsubscribeFromEmergencyAlerts() async throws {
        try await emergencyRepository.unsubscribeFromEmergencyAlerts()
    }
    
    func getNearestShelter(from location: CLLocationCoordinate2D) async throws -> Shelter? {
        let nearbyShelters = try await fetchNearbyShelters(
            location: location,
            radius: 50000 // 50km範囲で検索
        )
        
        guard !nearbyShelters.isEmpty else {
            return nil
        }
        
        // 距離でソート
        let sheltersWithDistance = nearbyShelters.map { shelter in
            let shelterLocation = CLLocation(latitude: shelter.latitude, longitude: shelter.longitude)
            let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let distance = userLocation.distance(from: shelterLocation)
            return (shelter: shelter, distance: distance)
        }
        
        let sortedShelters = sheltersWithDistance.sorted { $0.distance < $1.distance }
        return sortedShelters.first?.shelter
    }
    
    func getEvacuationRoute(from source: CLLocationCoordinate2D, to shelterId: UUID) async throws -> EvacuationRoute {
        let shelter = try await emergencyRepository.getShelter(id: shelterId)
        
        let destination = CLLocationCoordinate2D(
            latitude: shelter.latitude,
            longitude: shelter.longitude
        )
        
        return try await emergencyRepository.getEvacuationRoute(
            from: source,
            to: destination
        )
    }
    
    func reportEmergency(_ request: EmergencyReportRequest) async throws -> EmergencyEvent {
        // バリデーション
        guard !request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmergencyError.emptyTitle
        }
        
        guard !request.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmergencyError.emptyDescription
        }
        
        guard request.title.count <= 200 else {
            throw EmergencyError.titleTooLong
        }
        
        guard request.description.count <= 2000 else {
            throw EmergencyError.descriptionTooLong
        }
        
        // 緊急事態レポートを作成
        let emergencyEvent = try await emergencyRepository.createEmergencyEvent(request)
        
        // 緊急通知の送信
        try await sendEmergencyEventNotification(for: emergencyEvent)
        
        return emergencyEvent
    }
    
    // MARK: - Private Methods
    
    private func sendEmergencyNotification(for post: Post) async throws {
        // 近隣ユーザーへの緊急通知
        print("緊急投稿の通知送信: \(post.id)")
        // TODO: 実際の通知実装
    }
    
    private func sendEmergencyEventNotification(for event: EmergencyEvent) async throws {
        // 緊急事態の通知送信
        print("緊急事態の通知送信: \(event.id)")
        // TODO: 実際の通知実装
    }
}

// MARK: - Data Models

struct EmergencyPostRequest {
    let content: String
    let url: String?
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let category: PostCategory
    let emergencyLevel: EmergencyLevel?
    let mediaURLs: [String]
}

struct EmergencyReportRequest {
    let title: String
    let description: String
    let eventType: EmergencyEventType
    let severity: EmergencySeverity
    let location: CLLocationCoordinate2D
    let affectedArea: [CLLocationCoordinate2D]?
    let source: String?
}

struct SafetyReport {
    let location: CLLocationCoordinate2D
    let status: SafetyStatus
    let message: String?
    let timestamp: Date
}

struct EmergencyAlertSubscription {
    let location: CLLocationCoordinate2D
    let radius: Double
    let subscribedAt: Date
}

struct EvacuationRoute {
    let source: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let waypoints: [CLLocationCoordinate2D]
    let distance: Double
    let estimatedTime: TimeInterval
    let instructions: [String]
}

enum SafetyStatus: String, CaseIterable {
    case safe = "safe"
    case injured = "injured"
    case needHelp = "need_help"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .safe: return "安全"
        case .injured: return "負傷"
        case .needHelp: return "救助要請"
        case .unknown: return "不明"
        }
    }
}

// MARK: - Emergency Errors

enum EmergencyError: Error, LocalizedError {
    case invalidLocation(String)
    case invalidRadius
    case emptyContent
    case contentTooLong
    case emptyTitle
    case titleTooLong
    case emptyDescription
    case descriptionTooLong
    case messageTooLong
    case missingEmergencyLevel
    case shelterNotFound
    case routeNotFound
    case notificationFailed
    case subscriptionFailed
    case networkError(String)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidLocation(let message):
            return message
        case .invalidRadius:
            return "検索範囲が無効です（1m〜100km）"
        case .emptyContent:
            return "投稿内容を入力してください"
        case .contentTooLong:
            return "投稿内容は2000文字以内で入力してください"
        case .emptyTitle:
            return "タイトルを入力してください"
        case .titleTooLong:
            return "タイトルは200文字以内で入力してください"
        case .emptyDescription:
            return "説明を入力してください"
        case .descriptionTooLong:
            return "説明は2000文字以内で入力してください"
        case .messageTooLong:
            return "メッセージは500文字以内で入力してください"
        case .missingEmergencyLevel:
            return "緊急度を選択してください"
        case .shelterNotFound:
            return "避難所が見つかりません"
        case .routeNotFound:
            return "避難経路が見つかりません"
        case .notificationFailed:
            return "通知の送信に失敗しました"
        case .subscriptionFailed:
            return "緊急通知の登録に失敗しました"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .unknownError:
            return "不明なエラーが発生しました"
        }
    }
}