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

    // X風UI用の展開状態
    @State private var showURLInput = false
    @State private var showTagsInput = false
    @State private var showVisibilityPicker = false
    @State private var showEmergencyPicker = false
    @State private var showAttachmentsSheet = false
    
    private let maxContentLength = 1000
    private let maxImages = 4
    private let maxTags = 10

    // 人気タグ
    private let popularTags = ["交通情報", "天気", "イベント", "グルメ", "ニュース", "地域情報", "防災", "お知らせ"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // メイン投稿エリア
                ScrollView {
                    VStack(spacing: 16) {
                        // 投稿テキスト入力
                        TextEditor(text: $postContent)
                            .frame(minHeight: 200)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .onChange(of: postContent) { newValue in
                                if newValue.count > maxContentLength {
                                    postContent = String(newValue.prefix(maxContentLength))
                                }
                            }
                            .overlay(alignment: .topLeading) {
                                if postContent.isEmpty {
                                    Text("今何が起こっていますか？")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 16)
                                        .allowsHitTesting(false)
                                }
                            }

                        // 添付ファイルインジケーター
                        if hasAnyAttachments {
                            CompactAttachmentIndicator(count: attachmentCount) {
                                showAttachmentsSheet = true
                            }
                            .padding(.top, 8)
                        }

                        Spacer(minLength: 100)
                    }
                }

                Divider()

                // 下部ツールバー
                bottomToolbar

                Divider()

                // 文字数カウンターと投稿ボタン
                HStack {
                    Text("\(postContent.count)/\(maxContentLength)")
                        .font(.caption)
                        .foregroundColor(postContent.count > maxContentLength * 9 / 10 ? .red : .secondary)

                    Spacer()

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
                .padding()
            }
            .navigationTitle("新規投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("投稿") {
                        if emergencyLevel != nil {
                            showingEmergencyAlert = true
                        } else {
                            createPost()
                        }
                    }
                    .disabled(!canPost)
                }
            }
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
            .sheet(isPresented: $showAttachmentsSheet) {
                AttachmentsPreviewSheet(
                    selectedImages: $selectedImages,
                    urlInput: $urlInput,
                    urlMetadata: $urlMetadata,
                    selectedLocation: $selectedLocation,
                    locationName: $locationName,
                    tags: $tags,
                    emergencyLevel: $emergencyLevel,
                    onRemoveImage: { index in
                        selectedImages.remove(at: index)
                    },
                    onShowLocationPicker: {
                        showAttachmentsSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingLocationPicker = true
                        }
                    },
                    onShowTagsInput: {
                        showAttachmentsSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showTagsInput = true
                        }
                    },
                    onShowEmergencyPicker: {
                        showAttachmentsSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showEmergencyPicker = true
                        }
                    }
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
    
    // MARK: - Bottom Toolbar

    @ViewBuilder
    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            // 写真追加
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: maxImages,
                matching: .images
            ) {
                Image(systemName: selectedImages.isEmpty ? "photo" : "photo.fill")
                    .foregroundColor(selectedImages.isEmpty ? .blue : .green)
                    .imageScale(.large)
            }
            .disabled(selectedImages.count >= maxImages)
            .onChange(of: selectedPhotos) { newItems in
                loadSelectedPhotos(newItems)
            }

            // リンク追加
            Button(action: {
                showURLInput.toggle()
            }) {
                Image(systemName: (!urlInput.isEmpty || urlMetadata != nil) ? "link.circle.fill" : "link")
                    .foregroundColor((!urlInput.isEmpty || urlMetadata != nil) ? .green : .blue)
                    .imageScale(.large)
            }

            // 位置情報
            Button(action: {
                showingLocationPicker = true
            }) {
                Image(systemName: selectedLocation != nil ? "mappin.circle.fill" : "mappin.circle")
                    .foregroundColor(selectedLocation != nil ? .green : .blue)
                    .imageScale(.large)
            }
            .accessibilityLabel("位置情報")
            .accessibilityHint(selectedLocation != nil ? "位置が設定されています。タップして変更できます" : "位置を設定")

            // タグ
            Button(action: {
                showTagsInput.toggle()
            }) {
                Image(systemName: tags.isEmpty ? "number" : "number.circle.fill")
                    .foregroundColor(tags.isEmpty ? .blue : .green)
                    .imageScale(.large)
            }

            // 緊急度
            Button(action: {
                showEmergencyPicker.toggle()
            }) {
                Image(systemName: emergencyLevel != nil ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                    .foregroundColor(emergencyLevel != nil ? .orange : .blue)
                    .imageScale(.large)
            }

            Spacer()

            // 公開範囲
            Menu {
                Picker("公開範囲", selection: $visibility) {
                    ForEach(PostVisibility.allCases, id: \.self) { visibility in
                        Label(visibility.displayName, systemImage: visibility.iconName)
                            .tag(visibility)
                    }
                }
            } label: {
                Image(systemName: visibility.iconName)
                    .foregroundColor(.blue)
                    .imageScale(.large)
            }
        }
        .padding()
        .sheet(isPresented: $showURLInput) {
            urlInputSheet
        }
        .sheet(isPresented: $showTagsInput) {
            tagsInputSheet
        }
        .sheet(isPresented: $showEmergencyPicker) {
            emergencyPickerSheet
        }
    }


    // MARK: - Sheets

    @ViewBuilder
    private var urlInputSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ニュース記事のURLを貼り付けてください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("https://example.com/news", text: $urlInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .onChange(of: urlInput) { newValue in
                                if !newValue.isEmpty && urlInput.contains("http") {
                                    fetchURLMetadata(newValue)
                                }
                            }

                        if isLoadingMetadata {
                            ProgressView()
                        }
                    }
                }
                .padding()

                if let metadata = urlMetadata {
                    URLMetadataPreviewCard(metadata: metadata)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("ニュースリンクを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showURLInput = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        showURLInput = false
                    }
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var tagsInputSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                // 検索・新規追加フィールド
                HStack {
                    TextField("タグを検索または新規追加", text: $newTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addTag()
                        }

                    Button(action: addTag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tags.count >= maxTags)
                }
                .padding()

                // 選択中のタグ
                if !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("選択中のタグ (\(tags.count)/\(maxTags))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        FlowLayout(spacing: 8) {
                            ForEach(Array(tags), id: \.self) { tag in
                                TagChip(text: tag) {
                                    tags.remove(tag)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                }

                // 人気のタグ
                VStack(alignment: .leading, spacing: 12) {
                    Text("人気のタグ")
                        .font(.headline)
                        .padding(.horizontal)

                    FlowLayout(spacing: 8) {
                        ForEach(filteredPopularTags, id: \.self) { tag in
                            Button(action: {
                                if !tags.contains(tag) && tags.count < maxTags {
                                    tags.insert(tag)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("#\(tag)")
                                        .font(.caption)
                                    if tags.contains(tag) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(tags.contains(tag) ? Color.green.opacity(0.2) : Color(.systemGray5))
                                .foregroundColor(tags.contains(tag) ? .green : .primary)
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("タグ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        showTagsInput = false
                        newTag = ""
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var filteredPopularTags: [String] {
        if newTag.isEmpty {
            return popularTags
        } else {
            return popularTags.filter { $0.localizedCaseInsensitiveContains(newTag) }
        }
    }

    @ViewBuilder
    private var emergencyPickerSheet: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        emergencyLevel = nil
                        showEmergencyPicker = false
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "circle")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("なし")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("通常の投稿として表示されます")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if emergencyLevel == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Button(action: {
                        emergencyLevel = .low
                        showEmergencyPicker = false
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.yellow)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("低")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("注意喚起レベル - 一般的な情報共有")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if emergencyLevel == .low {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Button(action: {
                        emergencyLevel = .medium
                        showEmergencyPicker = false
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("中")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("警告レベル - 注意が必要な情報")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if emergencyLevel == .medium {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Button(action: {
                        emergencyLevel = .high
                        showEmergencyPicker = false
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("高")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("緊急レベル - 即座に対応が必要")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if emergencyLevel == .high {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } header: {
                    Text("緊急度を選択してください")
                } footer: {
                    Text("緊急度が設定された投稿は優先的に表示され、より多くのユーザーに届きます")
                }
            }
            .navigationTitle("緊急度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        showEmergencyPicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
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

    private var hasAnyAttachments: Bool {
        !selectedImages.isEmpty ||
        urlMetadata != nil ||
        !urlInput.isEmpty ||
        selectedLocation != nil ||
        !tags.isEmpty ||
        emergencyLevel != nil
    }

    private var attachmentCount: Int {
        var count = 0
        if !selectedImages.isEmpty { count += 1 }
        if urlMetadata != nil || !urlInput.isEmpty { count += 1 }
        if selectedLocation != nil { count += 1 }
        if !tags.isEmpty { count += 1 }
        if emergencyLevel != nil { count += 1 }
        return count
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

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .cornerRadius(16)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var frames: [CGRect]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var frames: [CGRect] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.frames = frames
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
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

// MARK: - Attachments Preview Sheet

struct AttachmentsPreviewSheet: View {
    @Environment(\.dismiss) var dismiss

    @Binding var selectedImages: [UIImage]
    @Binding var urlInput: String
    @Binding var urlMetadata: URLMetadata?
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Binding var tags: Set<String>
    @Binding var emergencyLevel: EmergencyLevel?

    var onRemoveImage: (Int) -> Void
    var onShowLocationPicker: () -> Void
    var onShowTagsInput: () -> Void
    var onShowEmergencyPicker: () -> Void

    var body: some View {
        NavigationView {
            List {
                // 画像セクション
                if !selectedImages.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))

                                        Button {
                                            onRemoveImage(index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                        }
                                        .padding(8)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    } header: {
                        Label("画像 (\(selectedImages.count))", systemImage: "photo.fill")
                    }
                }

                // URLセクション
                if let metadata = urlMetadata {
                    Section {
                        URLMetadataPreviewCard(metadata: metadata)

                        Button(role: .destructive) {
                            urlInput = ""
                            urlMetadata = nil
                        } label: {
                            Label("リンクを削除", systemImage: "trash")
                        }
                    } header: {
                        Label("ニュースリンク", systemImage: "link")
                    }
                } else if !urlInput.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                            Text(urlInput)
                                .font(.subheadline)
                                .lineLimit(2)
                        }

                        Button(role: .destructive) {
                            urlInput = ""
                        } label: {
                            Label("リンクを削除", systemImage: "trash")
                        }
                    } header: {
                        Label("ニュースリンク", systemImage: "link")
                    }
                }

                // 位置情報セクション
                if let location = selectedLocation {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                Text(locationName.isEmpty ? "位置情報" : locationName)
                                    .font(.body)
                            }

                            Text("\(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Button {
                            onShowLocationPicker()
                        } label: {
                            Label("位置を変更", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            selectedLocation = nil
                            locationName = ""
                        } label: {
                            Label("位置情報を削除", systemImage: "trash")
                        }
                    } header: {
                        Label("位置情報", systemImage: "location.fill")
                    }
                }

                // タグセクション
                if !tags.isEmpty {
                    Section {
                        FlowLayout(spacing: 8) {
                            ForEach(Array(tags), id: \.self) { tag in
                                TagChip(text: tag) {
                                    tags.remove(tag)
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        Button {
                            onShowTagsInput()
                        } label: {
                            Label("タグを編集", systemImage: "pencil")
                        }
                    } header: {
                        Label("タグ (\(tags.count))", systemImage: "number")
                    }
                }

                // 緊急度セクション
                if let level = emergencyLevel {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(emergencyLevelColor(level))
                            Text(level.displayName)
                                .font(.body)
                            Spacer()
                        }

                        Button {
                            onShowEmergencyPicker()
                        } label: {
                            Label("緊急度を変更", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            emergencyLevel = nil
                        } label: {
                            Label("緊急度を削除", systemImage: "trash")
                        }
                    } header: {
                        Label("緊急度", systemImage: "exclamationmark.triangle.fill")
                    }
                }

                // 添付ファイルがない場合のメッセージ
                if !hasAnyAttachments {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "paperclip.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text("添付ファイルがありません")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("下部のツールバーから画像、リンク、位置情報などを追加できます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
            }
            .navigationTitle("添付ファイル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var hasAnyAttachments: Bool {
        !selectedImages.isEmpty ||
        urlMetadata != nil ||
        !urlInput.isEmpty ||
        selectedLocation != nil ||
        !tags.isEmpty ||
        emergencyLevel != nil
    }

    private func emergencyLevelColor(_ level: EmergencyLevel) -> Color {
        switch level {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Compact Attachment Indicator

struct CompactAttachmentIndicator: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "paperclip.circle.fill")
                    .font(.title3)

                Text("添付ファイル")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
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