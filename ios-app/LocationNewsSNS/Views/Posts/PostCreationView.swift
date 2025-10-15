import SwiftUI
import PhotosUI
import MapKit

// MARK: - 投稿作成画面

struct PostCreationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mediaUploadService: MediaUploadService
    
    @State private var postContent = ""
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var visibility: PostVisibility = .public
    @State private var allowComments = true
    @State private var emergencyLevel: EmergencyLevel?
    @State private var tags: Set<String> = []
    @State private var newTag = ""
    @State private var urlInput = ""
    @State private var urlMetadata: URLMetadata?
    @State private var isLoadingMetadata = false

    @StateObject private var urlMetadataService = URLMetadataService()

    @State private var showingLocationPicker = false
    @State private var showingEmergencyAlert = false
    @State private var isUploading = false
    @State private var showingPreview = false
    @State private var isDraftSaving = false
    
    private let maxContentLength = 1000
    private let maxImages = 10
    private let maxTags = 10
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // ユーザー情報
                    userInfoSection
                    
                    // 投稿内容入力
                    contentInputSection

                    // URL入力セクション
                    urlInputSection

                    // メディア選択・プレビュー
                    mediaSection
                    
                    // 位置情報設定
                    locationSection
                    
                    // タグ入力
                    tagsSection
                    
                    // 緊急度設定
                    emergencySection
                    
                    // 公開設定
                    privacySection
                }
                .padding()
            }
            .navigationTitle("新規投稿")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    dismiss()
                },
                trailing: HStack(spacing: 12) {
                    Button("下書き保存") {
                        saveDraft()
                    }
                    .disabled(postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("投稿") {
                        if emergencyLevel != nil {
                            showingEmergencyAlert = true
                        } else {
                            createPost()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canPost)
                }
            )
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(
                    selectedLocation: $selectedLocation,
                    locationName: $locationName
                )
            }
            .sheet(isPresented: $showingPreview) {
                PostPreviewView(
                    content: postContent,
                    images: selectedImages,
                    location: selectedLocation,
                    locationName: locationName,
                    tags: Array(tags),
                    emergencyLevel: emergencyLevel,
                    visibility: visibility,
                    allowComments: allowComments
                )
            }
            .alert("緊急投稿の確認", isPresented: $showingEmergencyAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("投稿", role: .destructive) {
                    createPost()
                }
            } message: {
                Text("緊急度が設定されています。この投稿を緊急情報として共有しますか？")
            }
            .disabled(isUploading || isDraftSaving)
            .overlay {
                if isUploading {
                    uploadingOverlay
                }
            }
        }
        .task {
            setupInitialLocation()
        }
    }
    
    // MARK: - User Info Section
    
    @ViewBuilder
    private var userInfoSection: some View {
        HStack(alignment: .top, spacing: 12) {
            // ユーザーアバター
            if let avatarURL = authService.currentUser?.avatarURL {
                CachedAsyncImage(url: URL(string: avatarURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(authService.currentUser?.displayName ?? authService.currentUser?.username ?? "")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let location = selectedLocation, !locationName.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(locationName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Content Input Section
    
    @ViewBuilder
    private var contentInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if postContent.isEmpty {
                    Text("今何が起こっていますか？")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $postContent)
                    .frame(minHeight: 100)
                    .onChange(of: postContent) { _, newValue in
                        if newValue.count > maxContentLength {
                            postContent = String(newValue.prefix(maxContentLength))
                        }
                    }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            HStack {
                Spacer()
                Text("\(postContent.count)/\(maxContentLength)")
                    .font(.caption)
                    .foregroundColor(postContent.count > maxContentLength * 9 / 10 ? .red : .secondary)
            }
        }
    }
    
    // MARK: - URL Input Section

    @ViewBuilder
    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ニュースリンク")
                    .font(.headline)

                Spacer()

                if isLoadingMetadata {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            // URL入力フィールド
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)

                TextField("URLを入力（例: https://example.com/news）", text: $urlInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .onChange(of: urlInput) { _, newValue in
                        if !newValue.isEmpty && urlInput.contains("http") {
                            fetchURLMetadata(newValue)
                        } else if newValue.isEmpty {
                            urlMetadata = nil
                        }
                    }

                if !urlInput.isEmpty {
                    Button(action: {
                        urlInput = ""
                        urlMetadata = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // URLメタデータプレビュー
            if let metadata = urlMetadata {
                URLMetadataPreviewCard(metadata: metadata)
            }
        }
    }

    // MARK: - Media Section
    
    @ViewBuilder
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("メディア")
                    .font(.headline)
                
                Spacer()
                
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: maxImages,
                    matching: .images
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                        Text("写真を選択")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .disabled(selectedImages.count >= maxImages)
            }
            
            if !selectedImages.isEmpty {
                MediaAttachmentView(
                    images: $selectedImages,
                    onRemove: { index in
                        selectedImages.remove(at: index)
                    }
                )
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            loadSelectedPhotos(newItems)
        }
    }
    
    // MARK: - Location Section
    
    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("位置情報")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingLocationPicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.badge.plus")
                        Text(selectedLocation != nil ? "位置を変更" : "位置を追加")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if let location = selectedLocation {
                LocationPreviewCard(
                    coordinate: location,
                    locationName: locationName,
                    onRemove: {
                        selectedLocation = nil
                        locationName = ""
                    }
                )
            }
        }
    }
    
    // MARK: - Tags Section
    
    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("タグ")
                    .font(.headline)
                
                Spacer()
                
                Text("\(tags.count)/\(maxTags)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // タグ入力
            HStack {
                TextField("タグを入力（例: 交通情報）", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addTag()
                    }
                
                Button("追加") {
                    addTag()
                }
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tags.count >= maxTags)
            }
            
            // タグ表示
            if !tags.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(Array(tags), id: \.self) { tag in
                        TagChip(text: tag) {
                            tags.remove(tag)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Emergency Section
    
    @ViewBuilder
    private var emergencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("緊急度")
                .font(.headline)
            
            Picker("緊急度", selection: $emergencyLevel) {
                Text("なし").tag(EmergencyLevel?.none)
                ForEach(EmergencyLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level as EmergencyLevel?)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if emergencyLevel != nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("緊急投稿は優先的に表示され、より多くのユーザーに届きます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Privacy Section
    
    @ViewBuilder
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("公開設定")
                .font(.headline)
            
            VStack(spacing: 8) {
                // 公開範囲
                Picker("公開範囲", selection: $visibility) {
                    ForEach(PostVisibility.allCases, id: \.self) { visibility in
                        HStack {
                            Image(systemName: visibility.iconName)
                            Text(visibility.displayName)
                        }
                        .tag(visibility)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                // コメント許可
                Toggle("コメントを許可", isOn: $allowComments)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Uploading Overlay
    
    @ViewBuilder
    private var uploadingOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(isDraftSaving ? "下書きを保存中..." : "投稿中...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Computed Properties
    
    private var canPost: Bool {
        !postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        postContent.count <= maxContentLength &&
        !isUploading &&
        !isDraftSaving
    }
    
    // MARK: - Methods
    
    private func setupInitialLocation() {
        Task {
            if let currentLocation = locationService.currentLocation {
                selectedLocation = currentLocation.coordinate
                do {
                    let address = try await locationService.reverseGeocode(location: currentLocation)
                    locationName = address.city + (address.ward ?? "") + (address.district ?? "")
                } catch {
                    locationName = "現在地"
                }
            }
        }
    }
    
    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            var images: [UIImage] = []
            
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            
            await MainActor.run {
                selectedImages = images
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty, tags.count < maxTags, !tags.contains(trimmedTag) else { return }
        
        tags.insert(trimmedTag)
        newTag = ""
    }
    
    private func createPost() {
        guard canPost else { return }
        
        isUploading = true
        
        Task {
            do {
                let request = CreatePostRequest(
                    content: postContent,
                    url: urlInput.isEmpty ? nil : urlInput,
                    urlMetadata: urlMetadata,
                    latitude: selectedLocation?.latitude,
                    longitude: selectedLocation?.longitude,
                    locationName: locationName,
                    visibility: visibility,
                    allowComments: allowComments,
                    emergencyLevel: emergencyLevel,
                    tags: Array(tags),
                    images: selectedImages
                )
                
                await postService.createPost(request)

                await MainActor.run {
                    isUploading = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isUploading = false
                }
                print("投稿作成エラー: \(error)")
            }
        }
    }
    
    private func saveDraft() {
        guard !postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isDraftSaving = true

        Task {
            // TODO: 下書き保存機能の実装
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒待機（デモ用）

            await MainActor.run {
                isDraftSaving = false
                dismiss()
            }
        }
    }

    private func fetchURLMetadata(_ urlString: String) {
        // デバウンス処理（0.5秒待機してから取得）
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard urlInput == urlString else { return }

            await MainActor.run {
                isLoadingMetadata = true
            }

            do {
                let metadata = try await urlMetadataService.fetchMetadata(from: urlString)

                await MainActor.run {
                    self.urlMetadata = metadata
                    self.isLoadingMetadata = false

                    // 位置情報が抽出された場合は自動設定
                    if let extractedLocation = metadata?.extractedLocation,
                       let coordinate = extractedLocation.clCoordinate,
                       extractedLocation.confidence > 0.5 {
                        self.selectedLocation = coordinate
                        self.locationName = extractedLocation.address ?? ""
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingMetadata = false
                }
                print("メタデータ取得エラー: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct TagChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(text)")
                .font(.caption)
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue)
        .cornerRadius(12)
    }
}

struct LocationPreviewCard: View {
    let coordinate: CLLocationCoordinate2D
    let locationName: String
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(locationName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(coordinate.latitude, specifier: "%.4f"), \(coordinate.longitude, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct URLMetadataPreviewCard: View {
    let metadata: URLMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // サムネイル画像
            if let imageURLString = metadata.imageURL,
               let imageURL = URL(string: imageURLString) {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 150)
                        .overlay {
                            ProgressView()
                        }
                }
                .cornerRadius(8)
            }

            // タイトルと説明
            VStack(alignment: .leading, spacing: 4) {
                if let title = metadata.title {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                }

                if let description = metadata.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    if let siteName = metadata.siteName {
                        Label(siteName, systemImage: "globe")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let extractedLocation = metadata.extractedLocation,
                       let address = extractedLocation.address {
                        Label(address, systemImage: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// // #Preview {
//     NavigationStack {
//         PostCreationView()
//             .environmentObject(PostService())
//             .environmentObject(AuthService())
//             .environmentObject(LocationService())
//             .environmentObject(MediaUploadService())
//     }
// }