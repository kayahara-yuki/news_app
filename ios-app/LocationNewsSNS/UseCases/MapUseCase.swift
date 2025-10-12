import Foundation
import Combine
import CoreLocation
import MapKit

// MARK: - Map UseCase Protocol

protocol MapUseCaseProtocol {
    func getCurrentLocation() async throws -> CLLocation
    func searchNearbyPosts(around location: CLLocationCoordinate2D, radius: Double) async throws -> [PostAnnotation]
    func searchLocation(query: String) async throws -> [MKMapItem]
    func getDirections(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> MKRoute
    func reverseGeocode(location: CLLocation) async throws -> String
    func clusterPosts(_ posts: [Post], in region: MKCoordinateRegion) async -> [PostCluster]
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance
    func isLocationInJapan(_ coordinate: CLLocationCoordinate2D) -> Bool
}

// MARK: - Map UseCase Implementation

class MapUseCase: MapUseCaseProtocol {
    private let locationService: any LocationServiceProtocol
    private let postRepository: any PostRepositoryProtocol
    private let geocoder = CLGeocoder()
    
    init(locationService: any LocationServiceProtocol, postRepository: any PostRepositoryProtocol) {
        self.locationService = locationService
        self.postRepository = postRepository
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        guard locationService.isLocationEnabled else {
            throw MapError.locationDisabled
        }
        
        guard locationService.authorizationStatus == .authorizedWhenInUse || 
              locationService.authorizationStatus == .authorizedAlways else {
            throw MapError.locationPermissionDenied
        }
        
        return try await locationService.getCurrentLocation()
    }
    
    func searchNearbyPosts(around location: CLLocationCoordinate2D, radius: Double) async throws -> [PostAnnotation] {
        // バリデーション
        guard (-90...90).contains(location.latitude) else {
            throw MapError.invalidCoordinate("緯度が無効です")
        }
        
        guard (-180...180).contains(location.longitude) else {
            throw MapError.invalidCoordinate("経度が無効です")
        }
        
        guard radius > 0 && radius <= 50000 else {
            throw MapError.invalidRadius
        }
        
        // 近隣投稿を取得
        let posts = try await postRepository.fetchNearbyPosts(
            latitude: location.latitude,
            longitude: location.longitude,
            radius: radius
        )
        
        // PostAnnotationに変換
        return posts.compactMap { post in
            return PostAnnotation(post: post)
        }
    }
    
    func searchLocation(query: String) async throws -> [MKMapItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MapError.emptySearchQuery
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503), // 東京駅
            latitudinalMeters: 100000,
            longitudinalMeters: 100000
        )
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        return response.mapItems
    }
    
    func getDirections(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> MKRoute {
        let sourcePlacemark = MKPlacemark(coordinate: source)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .walking // デフォルトは徒歩
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw MapError.routeNotFound
        }
        
        return route
    }
    
    func reverseGeocode(location: CLLocation) async throws -> String {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        guard let placemark = placemarks.first else {
            throw MapError.geocodingFailed
        }
        
        // 日本語の住所フォーマット
        var addressComponents: [String] = []
        
        if let country = placemark.country {
            addressComponents.append(country)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        
        if let subLocality = placemark.subLocality {
            addressComponents.append(subLocality)
        }
        
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        
        if let subThoroughfare = placemark.subThoroughfare {
            addressComponents.append(subThoroughfare)
        }
        
        return addressComponents.joined(separator: " ")
    }
    
    func clusterPosts(_ posts: [Post], in region: MKCoordinateRegion) async -> [PostCluster] {
        // クラスタリングアルゴリズムの実装
        // 地図のズームレベルに応じてクラスタリングの精度を調整
        
        let zoomLevel = calculateZoomLevel(from: region)
        let clusterRadius = calculateClusterRadius(zoomLevel: zoomLevel)
        
        var clusters: [PostCluster] = []
        var processedPosts: Set<UUID> = []
        
        for post in posts {
            guard !processedPosts.contains(post.id),
                  let latitude = post.latitude,
                  let longitude = post.longitude else {
                continue
            }
            
            let postCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            var clusterPosts: [Post] = [post]
            processedPosts.insert(post.id)
            
            // 近隣の投稿を探してクラスター化
            for otherPost in posts {
                guard !processedPosts.contains(otherPost.id),
                      let otherLatitude = otherPost.latitude,
                      let otherLongitude = otherPost.longitude else {
                    continue
                }
                
                let otherCoordinate = CLLocationCoordinate2D(latitude: otherLatitude, longitude: otherLongitude)
                let distance = calculateDistance(from: postCoordinate, to: otherCoordinate)
                
                if distance <= clusterRadius {
                    clusterPosts.append(otherPost)
                    processedPosts.insert(otherPost.id)
                }
            }
            
            // クラスターまたは単一投稿として追加
            if clusterPosts.count > 1 {
                clusters.append(PostCluster(posts: clusterPosts, coordinate: postCoordinate))
            } else {
                clusters.append(PostCluster(posts: clusterPosts, coordinate: postCoordinate))
            }
        }
        
        return clusters
    }
    
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    func isLocationInJapan(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 日本の大まかな座標範囲
        let japanBounds = (
            north: 45.5,
            south: 24.0,
            east: 146.0,
            west: 123.0
        )
        
        return coordinate.latitude >= japanBounds.south &&
               coordinate.latitude <= japanBounds.north &&
               coordinate.longitude >= japanBounds.west &&
               coordinate.longitude <= japanBounds.east
    }
    
    // MARK: - Private Methods
    
    private func calculateZoomLevel(from region: MKCoordinateRegion) -> Double {
        // 地図のズームレベルを計算
        let longitudeDelta = region.span.longitudeDelta
        return log2(360.0 / longitudeDelta)
    }
    
    private func calculateClusterRadius(zoomLevel: Double) -> CLLocationDistance {
        // ズームレベルに応じたクラスターの半径を計算
        switch zoomLevel {
        case 0..<8:
            return 10000 // 10km
        case 8..<10:
            return 5000  // 5km
        case 10..<12:
            return 1000  // 1km
        case 12..<14:
            return 500   // 500m
        default:
            return 100   // 100m
        }
    }
}

// MARK: - Post Annotation
// Note: PostAnnotationは Models/MapAnnotations.swift で定義されています (class版)

// MARK: - Post Cluster

struct PostCluster: Identifiable {
    let id = UUID()
    let posts: [Post]
    let coordinate: CLLocationCoordinate2D
    
    var title: String {
        if posts.count == 1 {
            return posts.first?.content.prefix(50).description ?? ""
        } else {
            return "\(posts.count)件の投稿"
        }
    }
    
    var subtitle: String {
        if posts.count == 1 {
            return posts.first?.category.displayName ?? ""
        } else {
            let categories = Set(posts.map { $0.category })
            return categories.map { $0.displayName }.joined(separator: ", ")
        }
    }
    
    var isCluster: Bool {
        return posts.count > 1
    }
}

// MARK: - Map Errors

enum MapError: Error, LocalizedError {
    case locationDisabled
    case locationPermissionDenied
    case invalidCoordinate(String)
    case invalidRadius
    case emptySearchQuery
    case routeNotFound
    case geocodingFailed
    case networkError(String)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .locationDisabled:
            return "位置情報が無効です。設定で有効にしてください。"
        case .locationPermissionDenied:
            return "位置情報の使用が許可されていません。設定で許可してください。"
        case .invalidCoordinate(let message):
            return message
        case .invalidRadius:
            return "検索範囲が無効です（1m〜50km）"
        case .emptySearchQuery:
            return "検索キーワードを入力してください"
        case .routeNotFound:
            return "ルートが見つかりません"
        case .geocodingFailed:
            return "住所の取得に失敗しました"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .unknownError:
            return "不明なエラーが発生しました"
        }
    }
}