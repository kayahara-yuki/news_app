import SwiftUI
import MapKit
import Combine

// MARK: - MapKit統合ビュー

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var posts: [Post]
    @Binding var selectedPost: Post?
    
    let showUserLocation: Bool
    let showEmergencies: Bool
    let showShelters: Bool
    let onPostSelected: ((Post) -> Void)?
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        // MARK: - Annotation Views
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            if let postAnnotation = annotation as? PostAnnotation {
                let identifier = "PostAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                
                if let markerView = view as? MKMarkerAnnotationView {
                    markerView.glyphImage = UIImage(systemName: "newspaper.fill")
                    markerView.markerTintColor = postAnnotation.post.isUrgent ? .red : .blue
                    markerView.titleVisibility = .adaptive
                }
                
                view.canShowCallout = true
                view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
                
                return view
            }
            
            if let shelterAnnotation = annotation as? ShelterAnnotation {
                let identifier = "ShelterAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                
                if let markerView = view as? MKMarkerAnnotationView {
                    markerView.glyphImage = UIImage(systemName: "house.fill")
                    markerView.markerTintColor = .green
                    markerView.titleVisibility = .adaptive
                }
                
                view.canShowCallout = true
                
                return view
            }
            
            return nil
        }
        
        // MARK: - User Interaction
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let postAnnotation = view.annotation as? PostAnnotation {
                parent.selectedPost = postAnnotation.post
                parent.onPostSelected?(postAnnotation.post)
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }

        // MARK: - Overlay Rendering

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circleOverlay = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circleOverlay)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: - Clustering
        
        func mapView(_ mapView: MKMapView, clusterAnnotationForMemberAnnotations memberAnnotations: [MKAnnotation]) -> MKClusterAnnotation {
            let cluster = MKClusterAnnotation(memberAnnotations: memberAnnotations)
            cluster.title = "\(memberAnnotations.count) 件の投稿"
            cluster.subtitle = "タップして詳細を表示"
            return cluster
        }
    }
    
    // MARK: - UIViewRepresentable
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showUserLocation
        mapView.userTrackingMode = .none
        mapView.mapType = .standard

        // iOS 17+ の新機能活用
        if #available(iOS 17.0, *) {
            mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        }

        // 地図の基本設定
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsTraffic = false
        mapView.showsBuildings = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        if #available(iOS 17.0, *) {
            mapView.showsUserTrackingButton = showUserLocation
        }

        // 新規投稿作成の通知を監視
        NotificationCenter.default.addObserver(
            forName: .newPostCreated,
            object: nil,
            queue: .main
        ) { [weak mapView] notification in
            if let post = notification.userInfo?["post"] as? Post,
               let annotation = PostAnnotation(post: post) {
                mapView?.addAnnotation(annotation)
            }
        }

        return mapView
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        // 通知の監視を解除
        NotificationCenter.default.removeObserver(mapView, name: .newPostCreated, object: nil)
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // リージョンの更新
        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }

        // 5km圏内の円を表示
        update5kmCircle(mapView: mapView)

        // アノテーションの更新
        updateAnnotations(mapView: mapView)
    }
    
    // MARK: - Private Methods

    private func update5kmCircle(mapView: MKMapView) {
        // 既存の円オーバーレイを削除
        mapView.overlays.forEach { overlay in
            if overlay is MKCircle {
                mapView.removeOverlay(overlay)
            }
        }

        // マップの中心座標に5km圏内の円を追加
        let circle = MKCircle(center: region.center, radius: 5000) // 5km = 5000m
        mapView.addOverlay(circle)
    }

    private func updateAnnotations(mapView: MKMapView) {
        // パフォーマンス最適化: 差分更新を実装
        // 全削除・全追加ではなく、変更があった部分のみ更新

        // 既存の投稿アノテーションを取得（ユーザー位置以外）
        let existingPostAnnotations = mapView.annotations.compactMap { $0 as? PostAnnotation }
        let existingPostIDs = Set(existingPostAnnotations.map { $0.post.id })

        // 新しい投稿アノテーションを生成（位置情報が有効な投稿のみ）
        let newPostAnnotations = posts.compactMap { PostAnnotation(post: $0) }
        let newPostIDs = Set(newPostAnnotations.map { $0.post.id })

        // 削除すべきアノテーション（既存にあるが新規にない）
        let annotationsToRemove = existingPostAnnotations.filter { !newPostIDs.contains($0.post.id) }
        if !annotationsToRemove.isEmpty {
            mapView.removeAnnotations(annotationsToRemove)
        }

        // 追加すべきアノテーション（新規にあるが既存にない）
        let annotationsToAdd = newPostAnnotations.filter { !existingPostIDs.contains($0.post.id) }
        if !annotationsToAdd.isEmpty {
            mapView.addAnnotations(annotationsToAdd)
        }

        // Note: 既に存在するアノテーションは再利用されるため、更新不要
        // MapKitが自動的にアノテーションビューを再利用します

        // 緊急事態のアノテーションを追加
        if showEmergencies {
            // TODO: 緊急事態のアノテーション追加
        }

        // 避難所のアノテーションを追加
        if showShelters {
            // TODO: 避難所のアノテーション追加
        }
    }
}

// MARK: - Post Annotation
// Note: PostAnnotationは Models/MapAnnotations.swift で定義されています

// MARK: - Map Container View

struct MapContainerView: View {
    @StateObject private var viewModel = MapViewModel()
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var emergencyService: EmergencyService

    @State private var showingPostDetail = false
    @State private var selectedPost: Post?
    @State private var showingFilters = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        ZStack {
            MapView(
                region: $region,
                posts: $viewModel.nearbyPosts,
                selectedPost: $selectedPost,
                showUserLocation: true,
                showEmergencies: viewModel.showEmergencies,
                showShelters: viewModel.showShelters,
                onPostSelected: { post in
                    selectedPost = post
                    showingPostDetail = true
                }
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                // 検索バー
                HStack {
                    SearchBar(text: $viewModel.searchText)
                        .padding(.horizontal)

                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: "slider.horizontal.3")
                            .padding(10)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                }
                .padding(.top, 50)

                Spacer()

                // 現在地ボタン
                HStack {
                    Spacer()

                    Button(action: centerOnUserLocation) {
                        Image(systemName: "location.fill")
                            .padding(12)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                }
            }

            // 近くの投稿カルーセル（最上位レイヤー、画面下部に固定）
            Group {
                if !viewModel.nearbyPosts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(viewModel.nearbyPosts) { post in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(post.content)
                                        .font(.subheadline)
                                        .lineLimit(2)

                                    if let userName = post.userName {
                                        Text(userName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .frame(width: 280)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(radius: 4)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedPost?.id == post.id ? Color.blue : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedPost = post
                                    showingPostDetail = true

                                    if let lat = post.latitude, let lng = post.longitude {
                                        withAnimation {
                                            region = MKCoordinateRegion(
                                                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                            )
                                        }
                                    }
                                }
                                .id(post.id)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 200)
                    .background(Color.white.opacity(0.9))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .sheet(isPresented: $showingPostDetail) {
            if let post = selectedPost {
                // TODO: PostDetailViewを実装
                Text("投稿詳細: \(post.content)")
            }
        }
        .sheet(isPresented: $showingFilters) {
            MapFilterView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.startMonitoring()
            centerOnUserLocation()
        }
    }

    private func centerOnUserLocation() {
        guard let location = locationService.currentLocation else { return }
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("場所を検索", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(8)
        .background(.regularMaterial)
        .cornerRadius(10)
    }
}

// MARK: - Map Filter View

struct MapFilterView: View {
    @ObservedObject var viewModel: MapViewModel
    @SwiftUI.Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("表示設定") {
                    Toggle("緊急情報を表示", isOn: $viewModel.showEmergencies)
                    Toggle("避難所を表示", isOn: $viewModel.showShelters)
                    Toggle("公式情報のみ表示", isOn: $viewModel.showOfficialOnly)
                }
                
                Section("範囲設定") {
                    Picker("表示範囲", selection: $viewModel.radiusFilter) {
                        Text("500m").tag(0.5)
                        Text("1km").tag(1.0)
                        Text("3km").tag(3.0)
                        Text("5km").tag(5.0)
                        Text("10km").tag(10.0)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("時間設定") {
                    Picker("投稿時間", selection: $viewModel.timeFilter) {
                        Text("1時間以内").tag(TimeFilter.oneHour)
                        Text("今日").tag(TimeFilter.today)
                        Text("1週間以内").tag(TimeFilter.week)
                        Text("全て").tag(TimeFilter.all)
                    }
                }
            }
            .navigationTitle("地図フィルター")
            .navigationBarItems(trailing: Button("完了") { dismiss() })
        }
    }
}

// MARK: - Map View Model

@MainActor
class MapViewModel: ObservableObject {
    @Published var nearbyPosts: [Post] = []
    @Published var emergencyEvents: [EmergencyEvent] = []
    @Published var shelters: [Shelter] = []
    @Published var searchText = ""
    @Published var showEmergencies = true
    @Published var showShelters = false
    @Published var showOfficialOnly = false
    @Published var radiusFilter: Double = 3.0
    @Published var timeFilter: TimeFilter = .today
    
    private let dependencies = DependencyContainer.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Search text changes
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] searchText in
                if !searchText.isEmpty {
                    Task {
                        await self?.searchLocation(searchText)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Filter changes
        Publishers.CombineLatest3($showOfficialOnly, $radiusFilter, $timeFilter)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }
    
    func startMonitoring() {
        dependencies.locationService.startMonitoring()
        
        Task {
            await fetchNearbyData()
        }
    }
    
    private func fetchNearbyData() async {
        guard let location = dependencies.locationService.currentLocation else { return }
        
        await dependencies.postService.fetchNearbyPosts(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radius: radiusFilter * 1000 // km to meters
        )
        
        nearbyPosts = dependencies.postService.nearbyPosts
        
        if showEmergencies {
            await dependencies.emergencyService.fetchNearbyEmergencies(location: location.coordinate)
            emergencyEvents = dependencies.emergencyService.activeEmergencies
        }
        
        if showShelters {
            await dependencies.emergencyService.fetchNearbyShelters(location: location.coordinate)
            shelters = dependencies.emergencyService.nearbyShelters
        }
    }
    
    private func searchLocation(_ query: String) async {
        do {
            let coordinate = try await dependencies.locationService.geocode(address: query)
            // TODO: Update map region to searched location
        } catch {
            print("Geocoding error: \(error)")
        }
    }
    
    private func applyFilters() {
        // TODO: Apply filters to posts
    }
}

enum TimeFilter {
    case oneHour
    case today
    case week
    case all
}