import Foundation
import CoreLocation
import Combine

// MARK: - リアルタイム位置追跡サービス

@MainActor
class LocationTrackingService: ObservableObject {
    @Published var isTracking = false
    @Published var trackingMode: TrackingMode = .standard
    @Published var currentPath: [CLLocationCoordinate2D] = []
    @Published var totalDistance: Double = 0
    @Published var averageSpeed: Double = 0
    @Published var trackingDuration: TimeInterval = 0
    
    private let locationService: LocationService
    private let locationPrivacyService: LocationPrivacyService
    private let localStorageManager = LocalStorageManager.shared
    
    private var trackingStartTime: Date?
    private var lastLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()
    private var trackingTimer: Timer?
    
    init(locationService: LocationService, locationPrivacyService: LocationPrivacyService) {
        self.locationService = locationService
        self.locationPrivacyService = locationPrivacyService
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // 位置情報の更新を監視
        locationService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Tracking Control
    
    /// 位置追跡を開始
    func startTracking(mode: TrackingMode = .standard) {
        guard !isTracking else { return }
        
        isTracking = true
        trackingMode = mode
        trackingStartTime = Date()
        currentPath.removeAll()
        totalDistance = 0
        averageSpeed = 0
        
        // 追跡モードに応じて位置情報の更新設定を調整
        configureLocationUpdates(for: mode)
        
        // タイマーを開始
        startTrackingTimer()
        
        locationService.startMonitoring()
    }
    
    /// 位置追跡を停止
    func stopTracking() {
        guard isTracking else { return }
        
        isTracking = false
        locationService.stopMonitoring()
        stopTrackingTimer()
        
        // 追跡データを保存
        saveTrackingData()
    }
    
    /// 位置追跡を一時停止
    func pauseTracking() {
        guard isTracking else { return }
        
        locationService.stopMonitoring()
        stopTrackingTimer()
    }
    
    /// 位置追跡を再開
    func resumeTracking() {
        guard isTracking else { return }
        
        locationService.startMonitoring()
        startTrackingTimer()
    }
    
    // MARK: - Location Updates
    
    private func handleLocationUpdate(_ location: CLLocation) {
        guard isTracking else { return }
        
        // プライバシー設定に基づいて位置を調整
        let adjustedCoordinate = locationPrivacyService.processLocation(location.coordinate)
        
        // パスに追加
        currentPath.append(adjustedCoordinate)
        
        // 距離と速度を計算
        if let lastLoc = lastLocation {
            let distance = location.distance(from: lastLoc)
            totalDistance += distance
            
            // 平均速度を更新
            if let startTime = trackingStartTime {
                let duration = Date().timeIntervalSince(startTime)
                averageSpeed = totalDistance / duration
            }
        }
        
        lastLocation = location
        
        // 自動保存（バックグラウンド対応）
        if currentPath.count % 10 == 0 {
            saveTrackingDataInBackground()
        }
    }
    
    // MARK: - Configuration
    
    private func configureLocationUpdates(for mode: TrackingMode) {
        // TODO: LocationServiceProtocol に locationManager プロパティを追加する必要がある
        guard let concreteLocationService = locationService as? LocationService else {
            print("Warning: Cannot configure location updates - locationService is not a concrete LocationService")
            return
        }

        let locManager: CLLocationManager = concreteLocationService.value(forKey: "locationManager") as! CLLocationManager

        switch mode {
        case .standard:
            locManager.desiredAccuracy = kCLLocationAccuracyBest
            locManager.distanceFilter = 10.0
        case .powerSaving:
            locManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locManager.distanceFilter = 100.0
        case .highPrecision:
            locManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locManager.distanceFilter = 5.0
        case .emergency:
            locManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locManager.distanceFilter = 1.0
        }
    }
    
    // MARK: - Timer Management
    
    private func startTrackingTimer() {
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTrackingDuration()
        }
    }
    
    private func stopTrackingTimer() {
        trackingTimer?.invalidate()
        trackingTimer = nil
    }
    
    private func updateTrackingDuration() {
        guard let startTime = trackingStartTime else { return }
        trackingDuration = Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Data Persistence
    
    private func saveTrackingData() {
        guard !currentPath.isEmpty else { return }
        
        let trackingData = TrackingData(
            id: UUID(),
            startTime: trackingStartTime ?? Date(),
            endTime: Date(),
            path: currentPath.map { TrackingData.CoordinatePoint(coordinate: $0) },
            totalDistance: totalDistance,
            averageSpeed: averageSpeed,
            mode: trackingMode
        )
        
        // Core Dataに保存
        Task {
            await saveTrackingDataToStorage(trackingData)
        }
    }
    
    private func saveTrackingDataInBackground() {
        // バックグラウンドでの自動保存
        let currentData = TrackingData(
            id: UUID(),
            startTime: trackingStartTime ?? Date(),
            endTime: Date(),
            path: currentPath.map { TrackingData.CoordinatePoint(coordinate: $0) },
            totalDistance: totalDistance,
            averageSpeed: averageSpeed,
            mode: trackingMode
        )
        
        // 一時的に保存
        Task {
            await saveTempTrackingData(currentData)
        }
    }
    
    private func saveTrackingDataToStorage(_ data: TrackingData) async {
        // TODO: Core Dataへの保存実装
        print("Saving tracking data: \(data.id)")
    }
    
    private func saveTempTrackingData(_ data: TrackingData) async {
        // TODO: 一時データの保存実装
        print("Saving temp tracking data: \(data.id)")
    }
    
    // MARK: - Emergency Features
    
    /// 緊急追跡モードを開始
    func startEmergencyTracking() {
        // 緊急モードで追跡を開始
        startTracking(mode: .emergency)
        
        // プライバシー設定を一時的に変更
        locationPrivacyService.activateEmergencyMode()
        
        // リアルタイム位置共有を開始
        startRealtimeLocationSharing()
    }
    
    private func startRealtimeLocationSharing() {
        // TODO: リアルタイム位置共有の実装
        print("Starting realtime location sharing for emergency")
    }
    
    // MARK: - Path Analysis
    
    /// 経路の簡略化（Douglas-Peucker algorithm）
    func simplifyPath(_ path: [CLLocationCoordinate2D], tolerance: Double = 5.0) -> [CLLocationCoordinate2D] {
        guard path.count > 2 else { return path }
        
        // Douglas-Peuckerアルゴリズムの実装
        var simplified: [CLLocationCoordinate2D] = []
        simplified.append(path.first!)
        
        // 簡略化ロジック（実装省略）
        // ...
        
        simplified.append(path.last!)
        
        return simplified
    }
    
    /// 経路のスムージング
    func smoothPath(_ path: [CLLocationCoordinate2D], windowSize: Int = 3) -> [CLLocationCoordinate2D] {
        guard path.count > windowSize else { return path }
        
        var smoothed: [CLLocationCoordinate2D] = []
        
        for i in 0..<path.count {
            let start = max(0, i - windowSize / 2)
            let end = min(path.count - 1, i + windowSize / 2)
            
            var avgLat = 0.0
            var avgLng = 0.0
            var count = 0
            
            for j in start...end {
                avgLat += path[j].latitude
                avgLng += path[j].longitude
                count += 1
            }
            
            smoothed.append(CLLocationCoordinate2D(
                latitude: avgLat / Double(count),
                longitude: avgLng / Double(count)
            ))
        }
        
        return smoothed
    }
}

// MARK: - Supporting Types

/// 追跡モード
enum TrackingMode: String, CaseIterable, Codable {
    case standard = "standard"
    case powerSaving = "power_saving"
    case highPrecision = "high_precision"
    case emergency = "emergency"
    
    var displayName: String {
        switch self {
        case .standard: return "標準"
        case .powerSaving: return "省電力"
        case .highPrecision: return "高精度"
        case .emergency: return "緊急"
        }
    }
    
    var description: String {
        switch self {
        case .standard: return "標準的な精度で追跡"
        case .powerSaving: return "バッテリー消費を抑えて追跡"
        case .highPrecision: return "最高精度で追跡"
        case .emergency: return "緊急時の高頻度追跡"
        }
    }
}

/// 追跡データ
struct TrackingData: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let path: [CoordinatePoint]
    let totalDistance: Double
    let averageSpeed: Double
    let mode: TrackingMode

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    // CLLocationCoordinate2Dをラップする構造体
    struct CoordinatePoint: Codable {
        let latitude: Double
        let longitude: Double

        init(coordinate: CLLocationCoordinate2D) {
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
        }

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedDistance: String {
        if totalDistance < 1000 {
            return String(format: "%.0fm", totalDistance)
        } else {
            return String(format: "%.2fkm", totalDistance / 1000)
        }
    }
    
    var formattedSpeed: String {
        let speedKmh = averageSpeed * 3.6
        return String(format: "%.1fkm/h", speedKmh)
    }
}