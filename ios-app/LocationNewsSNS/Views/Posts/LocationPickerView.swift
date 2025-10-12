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
    @State private var showingSearch = false
    @State private var isSearching = false
    @State private var draggedLocation: CLLocationCoordinate2D?
    @State private var tempLocationName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 検索バー
                searchSection
                
                // マップ
                mapSection
                
                // 選択中の位置情報
                if let location = draggedLocation ?? selectedLocation {
                    selectedLocationSection(location)
                }
                
                // アクションボタン
                actionButtonsSection
            }
            .navigationTitle("位置を選択")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") { dismiss() },
                trailing: Button("現在地") { useCurrentLocation() }
                    .disabled(locationService.currentLocation == nil)
            )
        }
        .onAppear {
            setupInitialLocation()
        }
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty {
                searchLocations(query: newValue)
            } else {
                searchResults = []
            }
        }
    }
    
    // MARK: - Search Section
    
    @ViewBuilder
    private var searchSection: some View {
        VStack(spacing: 0) {
            // 検索フィールド
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("場所を検索...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onTapGesture {
                        showingSearch = true
                    }
                
                if !searchText.isEmpty {
                    Button(action: { 
                        searchText = ""
                        showingSearch = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // 検索結果
            if showingSearch && !searchResults.isEmpty {
                searchResultsSection
            }
        }
    }
    
    @ViewBuilder
    private var searchResultsSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults, id: \.self) { item in
                    SearchResultRow(item: item) {
                        selectSearchResult(item)
                    }
                    .background(Color(.systemBackground))
                    
                    Divider()
                }
            }
        }
        .frame(maxHeight: 200)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - Map Section
    
    @ViewBuilder
    private var mapSection: some View {
        ZStack {
            Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true, annotationItems: annotations) { annotation in
                MapPin(coordinate: annotation.coordinate, tint: .red)
            }
            .onTapGesture { location in
                handleMapTap(at: location)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let mapPoint = convertScreenPointToCoordinate(value.location)
                        draggedLocation = mapPoint
                    }
                    .onEnded { _ in
                        if let location = draggedLocation {
                            updateSelectedLocation(location)
                        }
                        draggedLocation = nil
                    }
            )
            
            // 中央の十字マーク
            Image(systemName: "plus")
                .font(.title2)
                .foregroundColor(.red)
                .background(Color.white.opacity(0.8))
                .clipShape(Circle())
                .allowsHitTesting(false)
        }
        .frame(height: 300)
    }
    
    // MARK: - Selected Location Section
    
    @ViewBuilder
    private func selectedLocationSection(_ location: CLLocationCoordinate2D) -> some View {
        VStack(spacing: 12) {
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("選択中の位置")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
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
                    .textFieldStyle(RoundedBorderTextFieldStyle())
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
        HStack(spacing: 16) {
            Button("リセット") {
                selectedLocation = nil
                locationName = ""
                tempLocationName = ""
                searchText = ""
                showingSearch = false
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.red)
            
            Button("確定") {
                confirmLocationSelection()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .disabled(draggedLocation == nil && selectedLocation == nil)
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var annotations: [LocationAnnotation] {
        var items: [LocationAnnotation] = []
        
        if let location = draggedLocation ?? selectedLocation {
            items.append(LocationAnnotation(coordinate: location))
        }
        
        return items
    }
    
    // MARK: - Methods
    
    private func setupInitialLocation() {
        if let currentLocation = locationService.currentLocation {
            region.center = currentLocation.coordinate
        } else if let selected = selectedLocation {
            region.center = selected
            tempLocationName = locationName
        }
    }
    
    private func useCurrentLocation() {
        guard let currentLocation = locationService.currentLocation else { return }
        
        let coordinate = currentLocation.coordinate
        selectedLocation = coordinate
        region.center = coordinate
        
        // 現在地の住所を取得
        Task {
            do {
                let address = try await locationService.reverseGeocode(location: currentLocation)
                await MainActor.run {
                    tempLocationName = address.city ?? address.prefecture ?? "現在地"
                }
            } catch {
                print("Reverse geocode error: \(error)")
            }
        }
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
        selectedLocation = coordinate
        region.center = coordinate
        tempLocationName = item.name ?? item.placemark.name ?? ""
        
        searchText = ""
        showingSearch = false
        searchResults = []
    }
    
    private func handleMapTap(at screenPoint: CGPoint) {
        let coordinate = convertScreenPointToCoordinate(screenPoint)
        updateSelectedLocation(coordinate)
    }
    
    private func convertScreenPointToCoordinate(_ point: CGPoint) -> CLLocationCoordinate2D {
        // 簡易的な変換（実際の実装では正確な変換が必要）
        let latitudeDelta = region.span.latitudeDelta * Double(point.y / 300 - 0.5)
        let longitudeDelta = region.span.longitudeDelta * Double(point.x / UIScreen.main.bounds.width - 0.5)
        
        return CLLocationCoordinate2D(
            latitude: region.center.latitude + latitudeDelta,
            longitude: region.center.longitude + longitudeDelta
        )
    }
    
    private func updateSelectedLocation(_ coordinate: CLLocationCoordinate2D) {
        selectedLocation = coordinate
        
        // 逆ジオコーディングで住所を取得
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        Task {
            do {
                let address = try await locationService.reverseGeocode(location: location)
                await MainActor.run {
                    tempLocationName = address.city ?? address.prefecture ?? "選択した位置"
                }
            } catch {
                print("Reverse geocode error: \(error)")
            }
        }
    }
    
    private func confirmLocationSelection() {
        if let location = draggedLocation ?? selectedLocation {
            selectedLocation = location
            locationName = tempLocationName
            dismiss()
        }
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

// MARK: - 簡易位置選択

struct SimpleLocationPicker: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    
    @State private var showingPicker = false
    
    var body: some View {
        Button(action: { showingPicker = true }) {
            HStack {
                Image(systemName: selectedLocation != nil ? "location.fill" : "location.badge.plus")
                    .foregroundColor(selectedLocation != nil ? .green : .blue)
                
                VStack(alignment: .leading) {
                    Text(selectedLocation != nil ? "位置が設定されています" : "位置を設定")
                        .font(.subheadline)
                    
                    if !locationName.isEmpty {
                        Text(locationName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
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

// // #Preview {
//     @Previewable @State var location: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
//     @Previewable @State var name: String = "東京駅"
// 
//     LocationPickerView(
//         selectedLocation: $location,
//         locationName: $name
//     )
//     .environmentObject(LocationService())
// }