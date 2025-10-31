import SwiftUI
import MapKit

// MARK: - 投稿作成画面

struct PostCreationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var locationService: LocationService
    
    @State private var postContent = ""
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName = ""
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

    // 音声録音関連（インライン統合）
    @StateObject private var audioService = AudioService()
    @State private var recordedAudioURL: URL?
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var audioRecordingTimer: Timer?

    // ステータス投稿関連
    @State private var selectedStatus: StatusType?
    @State private var showToast = false
    @State private var toastMessage = ""

    // パーミッション管理
    @StateObject private var permissionHandler = PermissionHandler()

    private let maxContentLength = 1000
    private let maxTags = 10

    // 人気タグ
    private let popularTags = ["交通情報", "天気", "イベント", "グルメ", "ニュース", "地域情報", "防災", "お知らせ"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // メイン投稿エリア
                ScrollView {
                    VStack(spacing: 8) {
                        // ステータスボタン（投稿作成画面上部）
                        StatusButtonsView(
                            selectedStatus: $selectedStatus,
                            isEnabled: permissionHandler.isStatusPostEnabled,
                            onStatusTapped: handleStatusTapped
                        )
                        .padding(.top, 4)

                        // 投稿テキスト入力
                        TextEditor(text: $postContent)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal)
                            .padding(.top, 4)
                            .onChange(of: postContent) { newValue in
                                if newValue.count > maxContentLength {
                                    postContent = String(newValue.prefix(maxContentLength))
                                }
                            }
                            .overlay(alignment: .topLeading) {
                                if postContent.isEmpty {
                                    Text("今何が起こっていますか？")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 12)
                                        .allowsHitTesting(false)
                                }
                            }

                        // インライン音声録音UI
                        if permissionHandler.shouldShowAudioRecorderButton {
                            InlineAudioRecorderView(
                                audioService: audioService,
                                recordedAudioURL: $recordedAudioURL,
                                isRecording: $isRecording,
                                recordingTime: $recordingTime
                            )
                            .padding(.horizontal)
                        }

                        // 添付ファイルインジケーター
                        if hasAnyAttachments {
                            CompactAttachmentIndicator(count: attachmentCount) {
                                showAttachmentsSheet = true
                            }
                        }

                        // 下部固定要素のための動的スペーサー
                        Color.clear
                            .frame(height: calculateBottomSpacing())
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
                    images: [],
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
                    urlInput: $urlInput,
                    urlMetadata: $urlMetadata,
                    selectedLocation: $selectedLocation,
                    locationName: $locationName,
                    tags: $tags,
                    emergencyLevel: $emergencyLevel,
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
            .overlay(alignment: .top) {
                if showToast {
                    toastView
                }
            }
            .permissionAlerts(permissionHandler)
        }
        .task {
            setupInitialLocation()
            updateLocationPermissionStatus()
        }
    }
    
    // MARK: - Bottom Toolbar

    @ViewBuilder
    private var bottomToolbar: some View {
        HStack(spacing: 16) {
            // リンク追加
            Button(action: {
                showURLInput.toggle()
            }) {
                Image(systemName: (!urlInput.isEmpty || urlMetadata != nil) ? "link.circle.fill" : "link")
                    .foregroundColor((!urlInput.isEmpty || urlMetadata != nil) ? .green : .blue)
                    .imageScale(.medium)
            }

            // 位置情報
            Button(action: {
                showingLocationPicker = true
            }) {
                Image(systemName: selectedLocation != nil ? "mappin.circle.fill" : "mappin.circle")
                    .foregroundColor(selectedLocation != nil ? .green : .blue)
                    .imageScale(.medium)
            }
            .accessibilityLabel("位置情報")
            .accessibilityHint(selectedLocation != nil ? "位置が設定されています。タップして変更できます" : "位置を設定")

            // タグ
            Button(action: {
                showTagsInput.toggle()
            }) {
                Image(systemName: tags.isEmpty ? "number" : "number.circle.fill")
                    .foregroundColor(tags.isEmpty ? .blue : .green)
                    .imageScale(.medium)
            }

            // 緊急度
            Button(action: {
                showEmergencyPicker.toggle()
            }) {
                Image(systemName: emergencyLevel != nil ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                    .foregroundColor(emergencyLevel != nil ? .orange : .blue)
                    .imageScale(.medium)
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
                    .imageScale(.medium)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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

    // MARK: - Toast View

    @ViewBuilder
    private var toastView: some View {
        Text(toastMessage)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Computed Properties

    private var canPost: Bool {
        !postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        postContent.count <= maxContentLength &&
        !isUploading &&
        !isDraftSaving
    }

    /// 下部固定要素のために必要なスペーシングを計算
    /// ツールバー + Divider + 文字数カウンター・投稿ボタン領域 + セーフエリア + 余白
    private func calculateBottomSpacing() -> CGFloat {
        // 実測値ベースでの計算
        let toolbarHeight: CGFloat = 50       // 下部ツールバーの実測高さ (アイコン + パディング16pt)
        let dividerHeight: CGFloat = 1        // Dividerの高さ
        let actionBarHeight: CGFloat = 80     // 文字数カウンター・投稿ボタン領域の実測高さ (パディング含む)
        let safeAreaBottom: CGFloat = 34      // 標準的なボトムセーフエリア (ホームインジケーター)
        let navigationBarHeight: CGFloat = 50 // ナビゲーションバーの影響
        let extraPadding: CGFloat = 40        // 追加の余白（安全マージン）

        return toolbarHeight + dividerHeight + actionBarHeight + safeAreaBottom + navigationBarHeight + extraPadding
    }

    private var hasAnyAttachments: Bool {
        urlMetadata != nil ||
        !urlInput.isEmpty ||
        selectedLocation != nil ||
        !tags.isEmpty ||
        emergencyLevel != nil ||
        recordedAudioURL != nil
    }

    private var attachmentCount: Int {
        var count = 0
        if urlMetadata != nil || !urlInput.isEmpty { count += 1 }
        if selectedLocation != nil { count += 1 }
        if !tags.isEmpty { count += 1 }
        if emergencyLevel != nil { count += 1 }
        if recordedAudioURL != nil { count += 1 }
        return count
    }
    
    // MARK: - Methods
    
    private func setupInitialLocation() {
        print("[PostCreationView] 📍 setupInitialLocation called")
        Task {
            if let currentLocation = locationService.currentLocation {
                print("[PostCreationView] 📍 Current location available: lat=\(currentLocation.coordinate.latitude), lng=\(currentLocation.coordinate.longitude)")
                selectedLocation = currentLocation.coordinate
                do {
                    let address = try await locationService.reverseGeocode(location: currentLocation)
                    locationName = address.city + (address.ward ?? "") + (address.district ?? "")
                    print("[PostCreationView] 📍 Address resolved: \(locationName)")
                } catch {
                    locationName = "現在地"
                    print("[PostCreationView] ⚠️ Failed to resolve address: \(error.localizedDescription)")
                }
            } else {
                print("[PostCreationView] ❌ Current location NOT available")
            }
        }
    }

    /// 位置情報パーミッション状態を更新
    private func updateLocationPermissionStatus() {
        permissionHandler.updateLocationAuthorizationStatus(locationService.authorizationStatus)
    }
    
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty, tags.count < maxTags, !tags.contains(trimmedTag) else { return }
        
        tags.insert(trimmedTag)
        newTag = ""
    }
    
    private func createPost() {
        guard canPost else {
            print("[PostCreationView] ❌ createPost blocked: canPost=false")
            return
        }

        print("[PostCreationView] 🚀 createPost started")
        print("[PostCreationView] 📝 postContent: \"\(postContent)\"")
        print("[PostCreationView] 🎤 recordedAudioURL: \(recordedAudioURL?.absoluteString ?? "nil")")
        print("[PostCreationView] 📍 selectedLocation: \(selectedLocation != nil ? "available" : "nil")")
        print("[PostCreationView] 👤 userID: \(authService.currentUser?.id.uuidString ?? "nil")")

        isUploading = true

        Task {
            do {
                // 音声付き投稿の場合（ステータス+音声の組み合わせを含む）
                if let audioURL = recordedAudioURL,
                   let userID = authService.currentUser?.id,
                   let latitude = selectedLocation?.latitude,
                   let longitude = selectedLocation?.longitude {

                    print("[PostCreationView] ✅ Audio post conditions met")
                    print("[PostCreationView] 🎤 audioURL: \(audioURL.absoluteString)")
                    print("[PostCreationView] 📂 audioURL exists: \(FileManager.default.fileExists(atPath: audioURL.path))")

                    if FileManager.default.fileExists(atPath: audioURL.path) {
                        let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path)
                        let fileSize = attributes?[.size] as? Int64 ?? 0
                        print("[PostCreationView] 📦 audioURL file size: \(fileSize) bytes")
                    }

                    print("[PostCreationView] 📤 Calling createPostWithAudio...")

                    // 音声付き投稿（ステータスの有無にかかわらず通常投稿として扱う）
                    try await postService.createPostWithAudio(
                        content: postContent,
                        audioFileURL: audioURL,
                        latitude: latitude,
                        longitude: longitude,
                        address: locationName,
                        userID: userID
                    )

                    print("[PostCreationView] ✅ Post with audio created. Content: \(postContent)")

                } else {
                    print("[PostCreationView] ⚠️ Audio post conditions NOT met - creating normal post")
                    print("[PostCreationView]   - recordedAudioURL: \(recordedAudioURL?.absoluteString ?? "nil")")
                    print("[PostCreationView]   - userID: \(authService.currentUser?.id.uuidString ?? "nil")")
                    print("[PostCreationView]   - latitude: \(selectedLocation?.latitude.description ?? "nil")")
                    print("[PostCreationView]   - longitude: \(selectedLocation?.longitude.description ?? "nil")")

                    // 通常の投稿（音声なし）
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
                        images: []
                    )

                    await postService.createPost(request)
                }

                await MainActor.run {
                    isUploading = false
                    dismiss()
                }

            } catch {
                print("[PostCreationView] ❌ Post creation failed: \(error.localizedDescription)")
                print("[PostCreationView] Error details: \(error)")
                await MainActor.run {
                    isUploading = false
                    // エラーメッセージを表示（オプション）
                }
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
            }
        }
    }

    // MARK: - Status Post Handlers

    /// ステータスボタンがタップされた時の処理
    /// - Parameter status: 選択されたステータス
    private func handleStatusTapped(_ status: StatusType) {
        // ステータステキストをテキストフィールドに自動入力
        postContent = status.rawValue

        // ステータスを選択状態にする
        selectedStatus = status

        // 音声が録音されている場合は、ワンタップ投稿をスキップ
        // ユーザーが手動で投稿ボタンを押す必要がある
        if recordedAudioURL != nil {
            print("[PostCreationView] Audio recorded. Skipping one-tap post. User must manually submit.")
            return
        }

        // 音声が録音されていない場合のみワンタップ投稿を実行

        // 位置情報が取得済みかチェック
        guard let location = selectedLocation else {
            // 位置情報が未取得の場合、エラートーストを表示
            showToastMessage("位置情報を取得できません。位置情報サービスを有効にしてください", duration: 2.0)
            selectedStatus = nil
            return
        }

        // ワンタップ投稿を実行（音声なしの場合のみ）
        createStatusPost(status: status, location: location)
    }

    /// ステータス投稿を作成
    /// - Parameters:
    ///   - status: ステータスタイプ
    ///   - location: 位置情報
    private func createStatusPost(status: StatusType, location: CLLocationCoordinate2D) {
        isUploading = true

        Task {
            do {
                // PostServiceのcreateStatusPostを呼び出し
                try await postService.createStatusPost(
                    status: status,
                    location: location
                )

                await MainActor.run {
                    isUploading = false

                    // 投稿成功トーストを表示（0.5秒間）
                    showToastMessage("投稿しました", duration: 0.5)

                    // 0.5秒後に画面を自動クローズ
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }

            } catch {
                await MainActor.run {
                    isUploading = false

                    // エラートーストを表示
                    showToastMessage("投稿に失敗しました。もう一度お試しください", duration: 2.0)
                    selectedStatus = nil
                }
            }
        }
    }

    /// トーストメッセージを表示
    /// - Parameters:
    ///   - message: 表示するメッセージ
    ///   - duration: 表示時間（秒）
    private func showToastMessage(_ message: String, duration: TimeInterval) {
        toastMessage = message

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showToast = false
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

    @Binding var urlInput: String
    @Binding var urlMetadata: URLMetadata?
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Binding var tags: Set<String>
    @Binding var emergencyLevel: EmergencyLevel?

    var onShowLocationPicker: () -> Void
    var onShowTagsInput: () -> Void
    var onShowEmergencyPicker: () -> Void

    var body: some View {
        NavigationView {
            List {
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
            HStack(spacing: 6) {
                Image(systemName: "paperclip.circle.fill")
                    .font(.body)

                Text("添付")
                    .font(.caption)
                    .fontWeight(.medium)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline Audio Recorder View

/// 投稿画面内に埋め込む音声録音UI
/// SwiftUIらしい洗練されたインラインコンポーネント
struct InlineAudioRecorderView: View {
    @ObservedObject var audioService: AudioService
    @Binding var recordedAudioURL: URL?
    @Binding var isRecording: Bool
    @Binding var recordingTime: TimeInterval

    @State private var showingPlayer = false
    @State private var audioPlayerService = AudioService()
    @State private var isPlaying = false
    @Namespace private var animation

    var body: some View {
        VStack(spacing: 6) {
            if recordedAudioURL == nil {
                // 未録音状態: 録音ボタン
                recordButton
            } else if isRecording {
                // 録音中: 波形表示とタイマー
                recordingView
            } else {
                // 録音済み: 再生UIと削除ボタン
                playbackView
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: recordedAudioURL != nil)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button(action: startRecording) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                .matchedGeometryEffect(id: "micIcon", in: animation)

                Text("音声を録音")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recording View

    private var recordingView: some View {
        HStack(spacing: 8) {
            // 録音中アニメーション
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 28, height: 28)

                Circle()
                    .stroke(Color.red, lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .opacity(isRecording ? 0 : 1)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: isRecording)

                Image(systemName: "waveform")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            .matchedGeometryEffect(id: "micIcon", in: animation)

            Text("録音中")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.red)

            Text(timeString(from: recordingTime))
                .font(.caption2)
                .foregroundColor(.secondary)
                .monospacedDigit()

            Spacer()

            // 停止ボタン
            Button(action: stopRecording) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 28, height: 28)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Playback View

    private var playbackView: some View {
        HStack(spacing: 8) {
            // 再生ボタン
            Button(action: togglePlayback) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.plain)

            Text("音声")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text(timeString(from: audioService.getDuration()))
                .font(.caption2)
                .foregroundColor(.secondary)
                .monospacedDigit()

            Spacer()

            // 削除ボタン
            Button(action: deleteRecording) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .frame(width: 28, height: 28)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func startRecording() {
        Task { @MainActor in
            do {
                isRecording = true
                let url = try await audioService.startRecording()
                recordedAudioURL = url

                // タイマー更新を監視
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak audioService] timer in
                    guard let audioService = audioService else {
                        timer.invalidate()
                        return
                    }
                    Task { @MainActor in
                        self.recordingTime = audioService.recordingTime
                        if !audioService.isRecording {
                            timer.invalidate()
                        }
                    }
                }
            } catch {
                isRecording = false
                print("Recording failed: \(error)")
            }
        }
    }

    private func stopRecording() {
        audioService.stopRecording()
        isRecording = false
    }

    private func togglePlayback() {
        guard let url = recordedAudioURL else { return }

        if isPlaying {
            audioPlayerService.pauseAudio()
            isPlaying = false
        } else {
            Task { @MainActor in
                do {
                    try await audioPlayerService.playAudio(from: url)
                    isPlaying = true

                    // 再生終了を監視
                    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak audioPlayerService] timer in
                        guard let audioPlayerService = audioPlayerService else {
                            timer.invalidate()
                            return
                        }
                        Task { @MainActor in
                            if !audioPlayerService.isPlaying {
                                self.isPlaying = false
                                timer.invalidate()
                            }
                        }
                    }
                } catch {
                    print("Playback failed: \(error)")
                }
            }
        }
    }

    private func deleteRecording() {
        audioPlayerService.stopAudio()
        isPlaying = false

        if let url = recordedAudioURL {
            try? FileManager.default.removeItem(at: url)
        }

        recordedAudioURL = nil
        recordingTime = 0
    }

    // MARK: - Helpers

    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
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