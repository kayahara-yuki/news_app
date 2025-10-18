import SwiftUI
import MapKit

// MARK: - 位置選択画面

struct LocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationService: LocationService

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var showingSearchResults = false
    @State private var isSearching = false
    @State private var tempSelectedLocation: CLLocationCoordinate2D?
    @State private var tempLocationName = ""
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // 検索バー
                    searchSection

                    // マップ（動的な高さ）
                    mapSection(geometry: geometry)

                    // 選択中の位置情報
                    if let location = tempSelectedLocation {
                        selectedLocationSection(location)
                    }

                    // アクションボタン
                    actionButtonsSection
                }
            }
            .navigationTitle("位置を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        handleCurrentLocationButtonTap()
                    } label: {
                        Label("現在地", systemImage: "location.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSearchResults) {
                searchResultsSheet
            }
        }
        .task {
            setupInitialLocation()
        }
    }
    
    // MARK: - Search Section

    @ViewBuilder
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("場所を検索...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .accessibilityLabel("場所の検索")
                .accessibilityHint("場所の名前や住所を入力してください")
                .onSubmit {
                    performSearch()
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    showingSearchResults = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("検索をクリア")
            }

            // 検索ボタン
            Button(action: {
                performSearch()
            }) {
                Text("検索")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(searchText.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(8)
            }
            .disabled(searchText.isEmpty)
            .accessibilityLabel("検索を実行")
        }
        .padding()
        .background(Color(.systemGray6))
    }

    @ViewBuilder
    private var searchResultsSheet: some View {
        NavigationView {
            List {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("結果が見つかりませんでした")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(searchResults, id: \.self) { item in
                        SearchResultRow(item: item) {
                            selectSearchResult(item)
                        }
                    }
                }
            }
            .navigationTitle("検索結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        showingSearchResults = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Map Section

    @ViewBuilder
    private func mapSection(geometry: GeometryProxy) -> some View {
        let searchBarHeight: CGFloat = 56
        let selectedLocationHeight: CGFloat = tempSelectedLocation != nil ? 180 : 0
        let actionButtonHeight: CGFloat = 80
        let mapHeight = geometry.size.height - searchBarHeight - selectedLocationHeight - actionButtonHeight

        ZStack(alignment: .bottom) {
            ZStack {
                // マップ
                Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true, annotationItems: annotations) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        DraggableMapPin(
                            onDragChanged: { _ in },
                            onDragEnded: { location in
                                handlePinDrop(at: location)
                            }
                        )
                    }
                }
                .accessibilityLabel("地図")
                .accessibilityHint("マップを動かして位置を調整し、中央の十字マークで正確な位置を指定できます")

                // 中央の十字マーカー（ピンが配置されていない時のみ表示）
                if tempSelectedLocation == nil {
                    MapCenterCrosshair()
                }
            }

            // マップ中央にピンを配置するボタン
            if tempSelectedLocation == nil {
                VStack {
                    Spacer()
                    Button {
                        selectMapCenter()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                            Text("この位置を選択")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                    }
                    .accessibilityLabel("中央の位置を選択")
                    .accessibilityHint("マップ中央の十字マークの位置をピンで選択します")
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(height: max(mapHeight, 300))
    }
    
    // MARK: - Selected Location Section

    @ViewBuilder
    private func selectedLocationSection(_ location: CLLocationCoordinate2D) -> some View {
        VStack(spacing: 12) {
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("選択中の位置")
                        .font(.headline)

                    Spacer()

                    Button {
                        clearSelection()
                    } label: {
                        Label("削除", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("選択をクリア")
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tempLocationName.isEmpty ? "位置情報を取得中..." : tempLocationName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("\(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // カスタム名前入力
                TextField("場所の名前を入力（オプション）", text: $tempLocationName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("場所の名前")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Action Buttons Section

    @ViewBuilder
    private var actionButtonsSection: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                Button {
                    confirmLocationSelection()
                } label: {
                    Text("この位置を使用")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(tempSelectedLocation == nil)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Computed Properties

    private var annotations: [LocationAnnotation] {
        var items: [LocationAnnotation] = []

        if let location = tempSelectedLocation {
            items.append(LocationAnnotation(coordinate: location))
        }

        return items
    }

    // MARK: - Methods

    private func setupInitialLocation() {
        if let selected = selectedLocation {
            region.center = selected
            tempSelectedLocation = selected
            tempLocationName = locationName
        } else if let currentLocation = locationService.currentLocation {
            region.center = currentLocation.coordinate
        }
    }

    private func handleCurrentLocationButtonTap() {
        // 位置情報の許可状態をチェック
        switch locationService.authorizationStatus {
        case .notDetermined:
            locationService.requestPermission()
        case .denied, .restricted:
            // TODO: 設定画面への誘導アラートを表示
            break
        case .authorizedWhenInUse, .authorizedAlways:
            useCurrentLocation()
        @unknown default:
            break
        }
    }

    private func useCurrentLocation() {
        guard let currentLocation = locationService.currentLocation else {
            return
        }

        let coordinate = currentLocation.coordinate

        tempSelectedLocation = coordinate
        region.center = coordinate

        // ハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // 現在地の住所を取得
        Task {
            do {
                let address = try await locationService.reverseGeocode(location: currentLocation)
                await MainActor.run {
                    tempLocationName = address.city ?? address.prefecture ?? "現在地"
                }
            } catch {
                await MainActor.run {
                    tempLocationName = "現在地"
                }
            }
        }
    }

    private func selectMapCenter() {
        tempSelectedLocation = region.center

        // ハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        updateLocationName(for: region.center)
    }

    private func handlePinDrop(at coordinate: CLLocationCoordinate2D) {
        tempSelectedLocation = coordinate

        // ハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        updateLocationName(for: coordinate)
    }

    private func clearSelection() {
        tempSelectedLocation = nil
        tempLocationName = ""

        // ハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        searchLocations(query: searchText)
        showingSearchResults = true
    }

    private func searchLocations(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false

                if let response = response {
                    searchResults = response.mapItems
                } else {
                    searchResults = []
                }
            }
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        tempSelectedLocation = coordinate
        region.center = coordinate
        tempLocationName = item.name ?? item.placemark.name ?? ""

        // ハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        searchText = ""
        showingSearchResults = false
        searchResults = []
    }

    private func updateLocationName(for coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        Task {
            do {
                let address = try await locationService.reverseGeocode(location: location)
                await MainActor.run {
                    if tempLocationName.isEmpty {
                        tempLocationName = address.city ?? address.prefecture ?? "選択した位置"
                    }
                }
            } catch {
                await MainActor.run {
                    if tempLocationName.isEmpty {
                        tempLocationName = "選択した位置"
                    }
                }
            }
        }
    }

    private func confirmLocationSelection() {
        guard let location = tempSelectedLocation else { return }

        selectedLocation = location
        locationName = tempLocationName.isEmpty ? "選択した位置" : tempLocationName

        // ハプティックフィードバック
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)

        dismiss()
    }
}

// MARK: - Supporting Types

struct LocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let item: MKMapItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name ?? "")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let address = formatAddress(item.placemark) {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if let category = item.pointOfInterestCategory?.rawValue {
                        Text(category)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatAddress(_ placemark: CLPlacemark) -> String? {
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

// MARK: - Map Center Crosshair

struct MapCenterCrosshair: View {
    var body: some View {
        ZStack {
            // 外側の円
            Circle()
                .strokeBorder(Color.blue, lineWidth: 2)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )

            // 十字の線
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 2, height: 12)
                Spacer()
                    .frame(height: 16)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 2, height: 12)
            }

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 2)
                Spacer()
                    .frame(width: 16)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 2)
            }

            // 中心点
            Circle()
                .fill(Color.blue)
                .frame(width: 4, height: 4)
        }
        .shadow(color: .white.opacity(0.8), radius: 2, x: 0, y: 0)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Draggable Map Pin

struct DraggableMapPin: View {
    var onDragChanged: (CGPoint) -> Void
    var onDragEnded: (CLLocationCoordinate2D) -> Void

    @State private var isDragging = false
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 44))
            .foregroundStyle(.red, .white)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .scaleEffect(isDragging ? 1.2 : 1.0)
            .offset(y: isDragging ? -10 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
            .accessibilityLabel("位置ピン")
            .accessibilityHint("ドラッグして位置を調整できます")
    }
}

// MARK: - 簡易位置選択

struct SimpleLocationPicker: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String

    @State private var showingPicker = false

    var body: some View {
        Button(action: { showingPicker = true }) {
            HStack {
                Image(systemName: selectedLocation != nil ? "mappin.circle.fill" : "mappin.circle")
                    .foregroundColor(selectedLocation != nil ? .green : .blue)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedLocation != nil ? "位置が設定されています" : "位置を設定")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if !locationName.isEmpty {
                        Text(locationName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .imageScale(.small)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingPicker) {
            LocationPickerView(
                selectedLocation: $selectedLocation,
                locationName: $locationName
            )
        }
    }
}