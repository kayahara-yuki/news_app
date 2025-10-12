import Foundation
import CoreLocation

// MARK: - Emergency関連のデータモデル

/// 緊急事態イベント
struct EmergencyEvent: Identifiable, Codable {
    let id: UUID
    let eventType: EmergencyEventType
    let title: String
    let description: String
    let severity: EmergencySeverity
    let affectedArea: [CLLocationCoordinate2D]
    let status: EmergencyStatus
    let officialSource: String?
    let externalID: String?
    let startedAt: Date
    let endedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum EmergencyEventType: String, CaseIterable, Codable {
    case earthquake = "earthquake"
    case tsunami = "tsunami"
    case flood = "flood"
    case fire = "fire"
    case typhoon = "typhoon"
    case landslide = "landslide"
    case volcanic = "volcanic"
    case accident = "accident"
    case security = "security"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .earthquake: return "地震"
        case .tsunami: return "津波"
        case .flood: return "洪水"
        case .fire: return "火災"
        case .typhoon: return "台風"
        case .landslide: return "土砂災害"
        case .volcanic: return "火山"
        case .accident: return "事故"
        case .security: return "治安"
        case .other: return "その他"
        }
    }
}

enum EmergencySeverity: String, CaseIterable, Codable {
    case info = "info"
    case warning = "warning"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .info: return "情報"
        case .warning: return "警告"
        case .critical: return "緊急"
        }
    }
}

enum EmergencyStatus: String, CaseIterable, Codable {
    case active = "active"
    case resolved = "resolved"
    case monitoring = "monitoring"
    
    var displayName: String {
        switch self {
        case .active: return "発生中"
        case .resolved: return "解決済み"
        case .monitoring: return "監視中"
        }
    }
}

enum EmergencyLevel: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

/// 避難所情報
struct Shelter: Identifiable, Codable {
    let id: UUID
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let capacity: Int?
    let currentOccupancy: Int
    let facilities: ShelterFacilities
    let contactPhone: String?
    let status: ShelterStatus
    let managedBy: String?
    let createdAt: Date
    let updatedAt: Date
    
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
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var occupancyRate: Double {
        guard let capacity = capacity, capacity > 0 else { return 0 }
        return Double(currentOccupancy) / Double(capacity)
    }
}

enum ShelterStatus: String, CaseIterable, Codable {
    case open = "open"
    case full = "full"
    case closed = "closed"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .open: return "開設"
        case .full: return "満員"
        case .closed: return "閉鎖"
        case .unknown: return "不明"
        }
    }
}

struct ShelterFacilities: Codable {
    let hasWater: Bool
    let hasElectricity: Bool
    let hasInternet: Bool
    let hasFood: Bool
    let hasMedical: Bool
    let hasPets: Bool
    let wheelchairAccessible: Bool
    let languages: [String]
    
    enum CodingKeys: String, CodingKey {
        case hasWater = "has_water"
        case hasElectricity = "has_electricity"
        case hasInternet = "has_internet"
        case hasFood = "has_food"
        case hasMedical = "has_medical"
        case hasPets = "has_pets"
        case wheelchairAccessible = "wheelchair_accessible"
        case languages
    }
    
    static let `default` = ShelterFacilities(
        hasWater: true,
        hasElectricity: true,
        hasInternet: false,
        hasFood: false,
        hasMedical: false,
        hasPets: false,
        wheelchairAccessible: true,
        languages: ["ja"]
    )
}

// MARK: - CLLocationCoordinate2D Codable Extension

extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
}