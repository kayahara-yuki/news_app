import Foundation
import Supabase
import CoreLocation

// MARK: - Emergency Repository Protocol

protocol EmergencyRepositoryProtocol {
    func fetchNearbyEmergencies(latitude: Double, longitude: Double, radius: Double) async throws -> [EmergencyEvent]
    func fetchNearbyShelters(latitude: Double, longitude: Double, radius: Double) async throws -> [Shelter]
    func getEmergencyEvent(id: UUID) async throws -> EmergencyEvent
    func getShelter(id: UUID) async throws -> Shelter
    func createEmergencyEvent(_ request: EmergencyReportRequest) async throws -> EmergencyEvent
    func createEmergencyPost(_ request: CreatePostRequest) async throws -> Post
    func updateEmergencyEvent(_ event: EmergencyEvent) async throws -> EmergencyEvent
    func updateShelterStatus(id: UUID, status: ShelterStatus, occupancy: Int?) async throws
    func reportSafety(_ report: SafetyReport) async throws
    func subscribeToEmergencyAlerts(_ subscription: EmergencyAlertSubscription) async throws
    func unsubscribeFromEmergencyAlerts() async throws
    func getEvacuationRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> EvacuationRoute
    func getEmergencyContacts(location: CLLocationCoordinate2D) async throws -> [EmergencyContact]
}

// MARK: - Emergency Repository Implementation

class EmergencyRepository: EmergencyRepositoryProtocol {
    private let supabase = SupabaseConfig.shared.client
    
    func fetchNearbyEmergencies(latitude: Double, longitude: Double, radius: Double) async throws -> [EmergencyEvent] {
        // TODO: RPC関数を実装する必要がある
        // 一旦、通常のクエリでフィルタリング
        let response: [EmergencyEventResponse] = try await supabase
            .from("emergency_events")
            .select()
            .eq("status", value: "active")
            .order("created_at", ascending: false)
            .execute()
            .value

        return try response.map { try $0.toEmergencyEvent() }
    }
    
    func fetchNearbyShelters(latitude: Double, longitude: Double, radius: Double) async throws -> [Shelter] {
        // TODO: RPC関数を実装する必要がある
        // 一旦、通常のクエリでフィルタリング
        let response: [ShelterResponse] = try await supabase
            .from("shelters")
            .select()
            .order("name", ascending: true)
            .execute()
            .value

        return try response.map { try $0.toShelter() }
    }
    
    func getEmergencyEvent(id: UUID) async throws -> EmergencyEvent {
        let response: EmergencyEventResponse = try await supabase
            .from("emergency_events")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
        return try response.toEmergencyEvent()
    }
    
    func getShelter(id: UUID) async throws -> Shelter {
        let response: ShelterResponse = try await supabase
            .from("shelters")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
        return try response.toShelter()
    }
    
    func createEmergencyEvent(_ request: EmergencyReportRequest) async throws -> EmergencyEvent {
        let eventRequest = EmergencyEventRequest(from: request)
        
        let response: EmergencyEventResponse = try await supabase
            .from("emergency_events")
            .insert(eventRequest)
            .select()
            .single()
            .execute()
            .value
        
        return try response.toEmergencyEvent()
    }
    
    func createEmergencyPost(_ request: CreatePostRequest) async throws -> Post {
        // 緊急投稿をpostsテーブルに作成
        let postRepository = PostRepository()
        return try await postRepository.createPost(request)
    }
    
    func updateEmergencyEvent(_ event: EmergencyEvent) async throws -> EmergencyEvent {
        let eventRequest = EmergencyEventRequest(from: event)
        
        let response: EmergencyEventResponse = try await supabase
            .from("emergency_events")
            .update(eventRequest)
            .eq("id", value: event.id)
            .select()
            .single()
            .execute()
            .value
        
        return try response.toEmergencyEvent()
    }
    
    func updateShelterStatus(id: UUID, status: ShelterStatus, occupancy: Int?) async throws {
        struct ShelterUpdate: Encodable {
            let status: String
            let currentOccupancy: Int?

            enum CodingKeys: String, CodingKey {
                case status
                case currentOccupancy = "current_occupancy"
            }
        }

        let updateData = ShelterUpdate(status: status.rawValue, currentOccupancy: occupancy)

        try await supabase
            .from("shelters")
            .update(updateData)
            .eq("id", value: id)
            .execute()
    }
    
    func reportSafety(_ report: SafetyReport) async throws {
        let safetyRequest = SafetyReportRequest(from: report)
        
        try await supabase
            .from("safety_reports")
            .insert(safetyRequest)
            .execute()
    }
    
    func subscribeToEmergencyAlerts(_ subscription: EmergencyAlertSubscription) async throws {
        // TODO: 現在のユーザーIDを取得
        let userID = UUID() // 仮のID
        
        let subscriptionRequest = EmergencyAlertSubscriptionRequest(
            userID: userID,
            latitude: subscription.location.latitude,
            longitude: subscription.location.longitude,
            radius: subscription.radius,
            subscribedAt: subscription.subscribedAt
        )
        
        try await supabase
            .from("emergency_alert_subscriptions")
            .insert(subscriptionRequest)
            .execute()
    }
    
    func unsubscribeFromEmergencyAlerts() async throws {
        // TODO: 現在のユーザーIDを取得
        let userID = UUID() // 仮のID
        
        try await supabase
            .from("emergency_alert_subscriptions")
            .delete()
            .eq("user_id", value: userID)
            .execute()
    }
    
    func getEvacuationRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> EvacuationRoute {
        // MapKitまたは外部ルーティングサービスを使用
        // ここではダミーデータを返す
        return EvacuationRoute(
            source: source,
            destination: destination,
            waypoints: [],
            distance: calculateDistance(from: source, to: destination),
            estimatedTime: 1800, // 30分
            instructions: [
                "北に向かって500m直進",
                "右折して大通りへ",
                "避難所まで1km直進"
            ]
        )
    }
    
    func getEmergencyContacts(location: CLLocationCoordinate2D) async throws -> [EmergencyContact] {
        // TODO: RPC関数を実装する必要がある
        // 一旦、通常のクエリで取得
        let response: [EmergencyContactResponse] = try await supabase
            .from("emergency_contacts")
            .select()
            .execute()
            .value
        
        return try response.map { try $0.toEmergencyContact() }
    }
    
    // MARK: - Private Methods
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
}

// MARK: - Data Transfer Objects

struct EmergencyEventRequest: Codable {
    let id: UUID?
    let eventType: String
    let title: String
    let description: String
    let severity: String
    let affectedArea: String? // PostGIS POLYGON
    let status: String
    let officialSource: String?
    let externalID: String?
    let startedAt: Date
    let endedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventType = "event_type"
        case title
        case description
        case severity
        case affectedArea = "affected_area"
        case status
        case officialSource = "official_source"
        case externalID = "external_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
    
    init(from request: EmergencyReportRequest) {
        self.id = nil
        self.eventType = request.eventType.rawValue
        self.title = request.title
        self.description = request.description
        self.severity = request.severity.rawValue
        
        // 影響エリアをPostGIS POLYGONフォーマットに変換
        if let area = request.affectedArea, !area.isEmpty {
            let points = area.map { "\($0.longitude) \($0.latitude)" }.joined(separator: ", ")
            self.affectedArea = "POLYGON((\(points)))"
        } else {
            self.affectedArea = nil
        }
        
        self.status = "active"
        self.officialSource = request.source
        self.externalID = nil
        self.startedAt = Date()
        self.endedAt = nil
    }
    
    init(from event: EmergencyEvent) {
        self.id = event.id
        self.eventType = event.eventType.rawValue
        self.title = event.title
        self.description = event.description
        self.severity = event.severity.rawValue
        self.affectedArea = nil // TODO: Convert from coordinates
        self.status = event.status.rawValue
        self.officialSource = event.officialSource
        self.externalID = event.externalID
        self.startedAt = event.startedAt
        self.endedAt = event.endedAt
    }
}

struct EmergencyEventResponse: Codable {
    let id: UUID
    let eventType: String
    let title: String
    let description: String
    let severity: String
    let affectedAreaCoordinates: [[Double]]? // PostGISから変換された座標
    let status: String
    let officialSource: String?
    let externalID: String?
    let startedAt: String
    let endedAt: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventType = "event_type"
        case title
        case description
        case severity
        case affectedAreaCoordinates = "affected_area_coordinates"
        case status
        case officialSource = "official_source"
        case externalID = "external_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    func toEmergencyEvent() throws -> EmergencyEvent {
        let dateFormatter = ISO8601DateFormatter()
        
        guard let startedDate = dateFormatter.date(from: startedAt),
              let createdDate = dateFormatter.date(from: createdAt),
              let updatedDate = dateFormatter.date(from: updatedAt) else {
            throw RepositoryError.invalidDateFormat
        }
        
        let endedDate = endedAt.flatMap { dateFormatter.date(from: $0) }
        
        // 影響エリアの座標を変換
        var affectedArea: [CLLocationCoordinate2D] = []
        if let coordinates = affectedAreaCoordinates {
            affectedArea = coordinates.compactMap { coord in
                guard coord.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
            }
        }
        
        return EmergencyEvent(
            id: id,
            eventType: EmergencyEventType(rawValue: eventType) ?? .other,
            title: title,
            description: description,
            severity: EmergencySeverity(rawValue: severity) ?? .info,
            affectedArea: affectedArea,
            status: EmergencyStatus(rawValue: status) ?? .active,
            officialSource: officialSource,
            externalID: externalID,
            startedAt: startedDate,
            endedAt: endedDate,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}

struct ShelterResponse: Codable {
    let id: UUID
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let capacity: Int?
    let currentOccupancy: Int
    let facilities: String?
    let contactPhone: String?
    let status: String
    let managedBy: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case latitude
        case longitude
        case capacity
        case currentOccupancy = "current_occupancy"
        case facilities
        case contactPhone = "contact_phone"
        case status
        case managedBy = "managed_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    func toShelter() throws -> Shelter {
        let dateFormatter = ISO8601DateFormatter()
        
        guard let createdDate = dateFormatter.date(from: createdAt),
              let updatedDate = dateFormatter.date(from: updatedAt) else {
            throw RepositoryError.invalidDateFormat
        }
        
        // 設備情報をデコード
        var shelterFacilities = ShelterFacilities.default
        if let facilitiesString = facilities,
           let data = facilitiesString.data(using: .utf8) {
            do {
                shelterFacilities = try JSONDecoder().decode(ShelterFacilities.self, from: data)
            } catch {
            }
        }
        
        return Shelter(
            id: id,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            capacity: capacity,
            currentOccupancy: currentOccupancy,
            facilities: shelterFacilities,
            contactPhone: contactPhone,
            status: ShelterStatus(rawValue: status) ?? .unknown,
            managedBy: managedBy,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}

struct SafetyReportRequest: Codable {
    let userID: UUID?
    let latitude: Double
    let longitude: Double
    let status: String
    let message: String?
    let reportedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case latitude
        case longitude
        case status
        case message
        case reportedAt = "reported_at"
    }
    
    init(from report: SafetyReport) {
        self.userID = nil // TODO: 現在のユーザーIDを設定
        self.latitude = report.location.latitude
        self.longitude = report.location.longitude
        self.status = report.status.rawValue
        self.message = report.message
        self.reportedAt = report.timestamp
    }
}

struct EmergencyAlertSubscriptionRequest: Codable {
    let userID: UUID
    let latitude: Double
    let longitude: Double
    let radius: Double
    let subscribedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case latitude
        case longitude
        case radius
        case subscribedAt = "subscribed_at"
    }
}

struct EmergencyContactResponse: Codable {
    let id: UUID
    let name: String
    let phoneNumber: String
    let email: String?
    let type: String
    let area: String
    let isAvailable24h: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case phoneNumber = "phone_number"
        case email
        case type
        case area
        case isAvailable24h = "is_available_24h"
    }
    
    func toEmergencyContact() throws -> EmergencyContact {
        return EmergencyContact(
            id: id,
            name: name,
            phoneNumber: phoneNumber,
            email: email,
            type: EmergencyContactType(rawValue: type) ?? .other,
            area: area,
            isAvailable24h: isAvailable24h
        )
    }
}

// MARK: - Emergency Contact Model

struct EmergencyContact: Identifiable, Codable {
    let id: UUID
    let name: String
    let phoneNumber: String
    let email: String?
    let type: EmergencyContactType
    let area: String
    let isAvailable24h: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case phoneNumber = "phone_number"
        case email
        case type
        case area
        case isAvailable24h = "is_available_24h"
    }
}

enum EmergencyContactType: String, CaseIterable, Codable {
    case police = "police"
    case fire = "fire"
    case medical = "medical"
    case municipal = "municipal"
    case utility = "utility"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .police: return "警察"
        case .fire: return "消防"
        case .medical: return "医療"
        case .municipal: return "自治体"
        case .utility: return "インフラ"
        case .other: return "その他"
        }
    }
}

