import Foundation
import CoreLocation
import Combine

/// 位置情報データ
struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date
    let source: LocationSource
    
    enum LocationSource: String, Codable {
        case gps = "gps"
        case network = "network"
        case manual = "manual"
    }
}

/// 位置情報サービス
@MainActor
class LocationService: NSObject, ObservableObject, LocationServiceProtocol {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled: Bool = false
    @Published var errorMessage: String?
    
    @Published var currentLocationData: LocationData?
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationCompletion: ((Result<CLLocation, Error>) -> Void)?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - セットアップ
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // 10m移動したら更新

        // バックグラウンド位置情報の設定（必要に応じて）
        // locationManager.allowsBackgroundLocationUpdates = true

        // 認証ステータスはデリゲートメソッド (locationManagerDidChangeAuthorization) で更新される
        isLocationEnabled = CLLocationManager.locationServicesEnabled()
    }
    
    // MARK: - 位置情報の許可要求
    
    /// 位置情報の使用許可を要求
    func requestPermission() {
        requestLocationPermission()
    }
    
    private func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // 設定アプリを開くよう促す
            errorMessage = "位置情報の使用が許可されていません。設定アプリで許可してください。"
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            break
        }
    }
    
    /// 常時位置情報の許可を要求（災害時など）
    func requestAlwaysLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - 位置情報の取得
    
    /// 監視開始
    func startMonitoring() {
        startLocationUpdates()
    }
    
    /// 監視停止
    func stopMonitoring() {
        stopLocationUpdates()
    }
    
    /// 現在位置の取得を開始
    func startLocationUpdates() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "位置情報サービスが無効です"
            return
        }
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    /// 位置情報の取得を停止
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    /// 一回だけ現在位置を取得
    func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            getCurrentLocationInternal { result in
                continuation.resume(with: result)
            }
        }
    }
    
    private func getCurrentLocationInternal(completion: @escaping (Result<CLLocation, Error>) -> Void) {
        self.locationCompletion = completion
        getCurrentLocationSync()
    }
    
    private func getCurrentLocationSync() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "位置情報サービスが無効です"
            return
        }
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        locationManager.requestLocation()
    }
    
    // MARK: - ジオコーディング
    
    /// 座標から住所を取得
    func reverseGeocode(location: CLLocation) async throws -> AddressComponents {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        guard let placemark = placemarks.first else {
            throw LocationError.noResults
        }
        
        return AddressComponents(
            country: placemark.country ?? "",
            prefecture: placemark.administrativeArea ?? "",
            city: placemark.locality ?? "",
            ward: placemark.subLocality,
            district: placemark.subThoroughfare,
            street: placemark.thoroughfare,
            building: placemark.name
        )
    }
    
    /// 住所から座標を取得
    func geocode(address: String) async throws -> CLLocationCoordinate2D {
        let placemarks = try await geocoder.geocodeAddressString(address)
        
        guard let placemark = placemarks.first,
              let location = placemark.location else {
            throw LocationError.noResults
        }
        
        return location.coordinate
    }
    
    // MARK: - 距離計算
    
    /// 2点間の距離を計算
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    /// 現在地からの距離を計算
    func distanceFromCurrentLocation(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let currentLocation = currentLocation else { return nil }
        return distance(from: currentLocation.coordinate, to: coordinate)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        currentLocationData = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: location.timestamp,
            source: .gps
        )
        
        errorMessage = nil
        
        // 非同期コールバックの処理
        if let completion = locationCompletion {
            completion(.success(location))
            locationCompletion = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置情報取得エラー: \(error)")
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                errorMessage = "位置情報の使用が拒否されました"
            case .locationUnknown:
                errorMessage = "位置情報を取得できませんでした"
            case .network:
                errorMessage = "ネットワークエラーにより位置情報を取得できませんでした"
            default:
                errorMessage = "位置情報の取得に失敗しました: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "位置情報の取得に失敗しました: \(error.localizedDescription)"
        }
        
        // 非同期コールバックのエラー処理
        if let completion = locationCompletion {
            completion(.failure(error))
            locationCompletion = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            stopLocationUpdates()
            errorMessage = "位置情報の使用が許可されていません"
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Supporting Types

/// 住所コンポーネント
struct AddressComponents: Codable {
    let country: String
    let prefecture: String
    let city: String
    let ward: String?
    let district: String?
    let street: String?
    let building: String?
}

/// 位置情報エラー
enum LocationError: Error, LocalizedError {
    case noResults
    case permissionDenied
    case serviceDisabled
    
    var errorDescription: String? {
        switch self {
        case .noResults:
            return "検索結果が見つかりませんでした"
        case .permissionDenied:
            return "位置情報の使用が許可されていません"
        case .serviceDisabled:
            return "位置情報サービスが無効です"
        }
    }
}