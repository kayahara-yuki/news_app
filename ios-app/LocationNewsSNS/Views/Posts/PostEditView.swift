import SwiftUI
import PhotosUI
import MapKit

// MARK: - 投稿編集画面

struct PostEditView: View {
    let post: Post
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mediaUploadService: MediaUploadService
    
    @State private var postContent: String
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var existingMediaFiles: [MediaFile] = []
    @State private var visibility: PostVisibility
    @State private var allowComments: Bool
    @State private var emergencyLevel: EmergencyLevel?
    @State private var tags: Set<String>
    @State private var newTag = ""
    
    @State private var showingLocationPicker = false
    @State private var showingDeleteAlert = false
    @State private var showingDiscardAlert = false
    @State private var isUpdating = false
    @State private var isDeleting = false
    @State private var hasChanges = false
    
    private let maxContentLength = 1000
    private let maxImages = 10
    private let maxTags = 10
    
    init(post: Post) {
        self.post = post
        self._postContent = State(initialValue: post.content)
        self._selectedLocation = State(initialValue: (post.latitude != nil && post.longitude != nil) ? CLLocationCoordinate2D(
            latitude: post.latitude!,
            longitude: post.longitude!
        ) : nil)
        self._locationName = State(initialValue: "") // TODO: 投稿から位置名を取得
        self._visibility = State(initialValue: post.visibility)
        self._allowComments = State(initialValue: true) // デフォルトでコメント許可
        self._emergencyLevel = State(initialValue: nil) // emergencyLevelは削除されたためnil
        self._tags = State(initialValue: Set()) // TODO: Post モデルにtagsプロパティを追加
        self._existingMediaFiles = State(initialValue: []) // mediaFilesは削除されたため空配列
    }
    
    var body: some View {
        mainView
            .modifier(ChangeTracker(checkChanges: checkForChanges))
    }

    struct ChangeTracker: ViewModifier {
        let checkChanges: () -> Void

        func body(content: Content) -> some View {
            content
        }
    }

    private var mainView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 編集情報
                    editInfoSection
                    
                    // 投稿内容編集
                    contentEditSection
                    
                    // メディア編集
                    mediaEditSection
                    
                    // 位置情報編集
                    locationEditSection
                    
                    // タグ編集
                    tagsEditSection
                    
                    // 緊急度編集
                    emergencyEditSection
                    
                    // 公開設定編集
                    privacyEditSection
                    
                    // 削除ボタン
                    deleteSection
                }
                .padding()
            }
            .navigationTitle("投稿を編集")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    if hasChanges {
                        showingDiscardAlert = true
                    } else {
                        dismiss()
                    }
                },
                trailing: Button("更新") {
                    updatePost()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canUpdate)
            )
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(
                    selectedLocation: $selectedLocation,
                    locationName: $locationName
                )
            }
            .alert("変更を破棄", isPresented: $showingDiscardAlert) {
                Button("破棄", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("未保存の変更があります。破棄しますか？")
            }
            .alert("投稿を削除", isPresented: $showingDeleteAlert) {
                Button("削除", role: .destructive) { deletePost() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この投稿を完全に削除しますか？この操作は取り消せません。")
            }
            .disabled(isUpdating || isDeleting)
            .overlay {
                if isUpdating || isDeleting {
                    updatingOverlay
                }
            }
        }
    }
    
    // MARK: - Edit Info Section
    
    @ViewBuilder
    private var editInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.blue)
                
                Text("投稿の編集")
                    .font(.headline)
                
                Spacer()
            }
            
            Text("投稿日: \(post.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if post.updatedAt != post.createdAt {
                Text("最終更新: \(post.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Content Edit Section
    
    @ViewBuilder
    private var contentEditSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("投稿内容")
                .font(.headline)
            
            ZStack(alignment: .topLeading) {
                if postContent.isEmpty {
                    Text("投稿内容を入力...")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $postContent)
                    .frame(minHeight: 120)
                    .onChange(of: postContent) { newValue in
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
    
    // MARK: - Media Edit Section
    
    @ViewBuilder
    private var mediaEditSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("メディア")
                    .font(.headline)
                
                Spacer()
                
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: maxImages - existingMediaFiles.count,
                    matching: .images
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                        Text("写真を追加")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .disabled(existingMediaFiles.count + selectedImages.count >= maxImages)
            }
            
            // 既存のメディアファイル
            if !existingMediaFiles.isEmpty {
                Text("既存の画像")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ExistingMediaGrid(
                    mediaFiles: $existingMediaFiles,
                    onRemove: { index in
                        existingMediaFiles.remove(at: index)
                        checkForChanges()
                    }
                )
            }
            
            // 新規追加画像
            if !selectedImages.isEmpty {
                Text("追加する画像")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                MediaAttachmentView(
                    images: $selectedImages,
                    onRemove: { index in
                        selectedImages.remove(at: index)
                    }
                )
            }
        }
        .onChange(of: selectedPhotos) { newItems in
            loadSelectedPhotos(newItems)
        }
    }
    
    // MARK: - Location Edit Section
    
    @ViewBuilder
    private var locationEditSection: some View {
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
                    locationName: locationName.isEmpty ? "投稿位置" : locationName,
                    onRemove: {
                        selectedLocation = nil
                        locationName = ""
                        checkForChanges()
                    }
                )
            }
        }
    }
    
    // MARK: - Tags Edit Section
    
    @ViewBuilder
    private var tagsEditSection: some View {
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
                TextField("タグを追加", text: $newTag)
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
                            checkForChanges()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Emergency Edit Section
    
    @ViewBuilder
    private var emergencyEditSection: some View {
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
    
    // MARK: - Privacy Edit Section
    
    @ViewBuilder
    private var privacyEditSection: some View {
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
    
    // MARK: - Delete Section
    
    @ViewBuilder
    private var deleteSection: some View {
        VStack(spacing: 16) {
            Divider()
            
            Button("投稿を削除") {
                showingDeleteAlert = true
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Updating Overlay
    
    @ViewBuilder
    private var updatingOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(isDeleting ? "削除中..." : "更新中...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Computed Properties
    
    private var canUpdate: Bool {
        !postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        postContent.count <= maxContentLength &&
        hasChanges &&
        !isUpdating &&
        !isDeleting
    }
    
    // MARK: - Methods
    
    private func checkForChanges() {
        hasChanges = postContent != post.content ||
                    selectedLocation?.latitude != post.latitude ||
                    selectedLocation?.longitude != post.longitude ||
                    visibility != post.visibility ||
                    !selectedImages.isEmpty
                    // emergencyLevelとmediaFilesは削除されたため比較から除外
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
                selectedImages.append(contentsOf: images)
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty, tags.count < maxTags, !tags.contains(trimmedTag) else { return }
        
        tags.insert(trimmedTag)
        newTag = ""
        checkForChanges()
    }
    
    private func updatePost() {
        guard canUpdate else { return }
        
        isUpdating = true
        
        Task {
            do {
                let request = UpdatePostRequest(
                    postID: post.id,
                    content: postContent,
                    latitude: selectedLocation?.latitude,
                    longitude: selectedLocation?.longitude,
                    locationName: locationName,
                    visibility: visibility,
                    allowComments: allowComments,
                    emergencyLevel: emergencyLevel,
                    tags: Array(tags),
                    newImages: selectedImages,
                    existingMediaFiles: existingMediaFiles
                )
                
                // TODO: PostServiceにupdatePostメソッドを実装する必要があります
                // await postService.updatePost(request)

                await MainActor.run {
                    isUpdating = false
                    // 暫定的に閉じる
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isUpdating = false
                }
            }
        }
    }
    
    private func deletePost() {
        isDeleting = true

        Task {
            await postService.deletePost(id: post.id)

            await MainActor.run {
                isDeleting = false
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views

struct ExistingMediaGrid: View {
    @Binding var mediaFiles: [MediaFile]
    let onRemove: (Int) -> Void
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(mediaFiles.enumerated()), id: \.element.id) { index, mediaFile in
                CachedAsyncImage(url: URL(string: mediaFile.url)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topTrailing) {
                    Button(action: { onRemove(index) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(4)
                }
            }
        }
    }
}

#Preview {
    PostEditView(post: Post(
        id: UUID(),
        user: UserProfile(
            id: UUID(),
            email: "test@example.com",
            username: "testuser",
            displayName: "Test User",
            bio: nil,
            avatarURL: nil,
            location: nil,
            isVerified: false,
            role: .user,
            privacySettings: PrivacySettings.default,
            createdAt: Date(),
            updatedAt: Date()
        ),
        content: "Test post content for editing",
        url: nil,
        latitude: 35.6762,
        longitude: 139.6503,
        address: "東京都",
        category: .other,
        visibility: .public,
        isUrgent: false,
        isVerified: false,
        likeCount: 5,
        commentCount: 2,
        shareCount: 1,
        createdAt: Date().addingTimeInterval(-3600),
        updatedAt: Date()
    ))
    .environmentObject(PostService())
    .environmentObject(AuthService())
    .environmentObject(LocationService())
    .environmentObject(MediaUploadService())
}