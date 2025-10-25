import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - メディア選択画面

struct MediaPickerView: View {
    @EnvironmentObject var imagePickerService: ImagePickerService
    @EnvironmentObject var mediaProcessingService: MediaProcessingService
    @Environment(\.dismiss) var dismiss
    
    let onSelection: ([ProcessedMediaItem]) -> Void
    
    @State private var selectedTab = 0
    @State private var showingCamera = false
    @State private var showingPermissionAlert = false
    @State private var selectedAlbum: MediaAlbum?
    @State private var albumPhotos: [PHAsset] = []
    @State private var isProcessing = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 2)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // タブ選択
                tabSelector
                
                // メディアグリッド
                mediaGridView
                
                // 選択済みメディア表示
                if !imagePickerService.selectedMedia.isEmpty {
                    selectedMediaBar
                }
            }
            .navigationTitle("メディアを選択")
            .navigationBarItems(
                leading: Button("キャンセル") { dismiss() },
                trailing: Button("完了") { processAndReturn() }
                    .disabled(imagePickerService.selectedMedia.isEmpty || isProcessing)
            )
            .onAppear {
                checkPermissionsAndLoad()
            }
            .alert("写真へのアクセスが必要です", isPresented: $showingPermissionAlert) {
                Button("設定を開く") { openSettings() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("写真を選択するには、設定アプリで写真へのアクセスを許可してください。")
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { result in
                    handleCameraResult(result)
                }
            }
        }
    }
    
    // MARK: - Tab Selector
    
    @ViewBuilder
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "最近の項目",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            TabButton(
                title: "アルバム",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            
            TabButton(
                title: "カメラ",
                isSelected: false,
                action: { showingCamera = true }
            )
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Media Grid View
    
    @ViewBuilder
    private var mediaGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                if selectedTab == 0 {
                    recentPhotosGrid
                } else {
                    albumsGrid
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    @ViewBuilder
    private var recentPhotosGrid: some View {
        ForEach(imagePickerService.recentPhotos, id: \.localIdentifier) { asset in
            MediaThumbnailView(
                asset: asset,
                isSelected: imagePickerService.isSelected(asset),
                onTap: { toggleSelection(asset) }
            )
        }
    }
    
    @ViewBuilder
    private var albumsGrid: some View {
        if let selectedAlbum = selectedAlbum {
            // アルバム内の写真表示
            ForEach(albumPhotos, id: \.localIdentifier) { asset in
                MediaThumbnailView(
                    asset: asset,
                    isSelected: imagePickerService.isSelected(asset),
                    onTap: { toggleSelection(asset) }
                )
            }
        } else {
            // アルバム一覧表示
            ForEach(imagePickerService.albums) { album in
                AlbumThumbnailView(
                    album: album,
                    onTap: { selectAlbum(album) }
                )
            }
        }
    }
    
    // MARK: - Selected Media Bar
    
    @ViewBuilder
    private var selectedMediaBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(imagePickerService.selectedMedia.count)件選択中")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("すべて解除") {
                    imagePickerService.clearSelection()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(imagePickerService.selectedMedia) { selectedItem in
                        SelectedMediaThumbnail(
                            asset: selectedItem.asset,
                            onRemove: { imagePickerService.deselectMedia(selectedItem.asset) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Methods
    
    private func checkPermissionsAndLoad() {
        switch imagePickerService.authorizationStatus {
        case .authorized, .limited:
            imagePickerService.loadRecentPhotos()
            imagePickerService.loadAlbums()
        case .notDetermined:
            Task {
                await imagePickerService.requestPhotoLibraryPermission()
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }
    
    private func toggleSelection(_ asset: PHAsset) {
        if imagePickerService.isSelected(asset) {
            imagePickerService.deselectMedia(asset)
        } else {
            imagePickerService.selectMedia(asset)
        }
    }
    
    private func selectAlbum(_ album: MediaAlbum) {
        selectedAlbum = album
        albumPhotos = imagePickerService.loadPhotos(from: album)
    }
    
    private func handleCameraResult(_ result: CameraResult) {
        switch result {
        case .image(let image):
            imagePickerService.handleCameraImage(image)
        case .video(let url):
            imagePickerService.handleCameraVideo(at: url)
        }
        showingCamera = false
    }
    
    private func processAndReturn() {
        isProcessing = true
        
        Task {
            do {
                let processedItems = await imagePickerService.processSelectedMedia()
                await MainActor.run {
                    onSelection(processedItems)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .blue : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .background(
            Rectangle()
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Media Thumbnail View

struct MediaThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @EnvironmentObject var imagePickerService: ImagePickerService
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemGray5))
                .aspectRatio(1, contentMode: .fit)
            
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            // 動画の場合は再生アイコンを表示
            if asset.mediaType == .video {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 24, height: 24)
                            )
                        Spacer()
                    }
                    
                    Text(formatDuration(asset.duration))
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(.bottom, 4)
                        .padding(.trailing, 4)
                }
            }
            
            // 選択状態のオーバーレイ
            if isSelected {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .background(Color.white, in: Circle())
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        Task {
            do {
                let thumbnail = try await imagePickerService.requestThumbnail(for: asset)
                await MainActor.run {
                    self.thumbnailImage = thumbnail
                }
            } catch {
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Album Thumbnail View

struct AlbumThumbnailView: View {
    let album: MediaAlbum
    let onTap: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @EnvironmentObject var imagePickerService: ImagePickerService
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(1, contentMode: .fit)
                
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(album.assetCount)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding(4)
                    }
                }
            }
            
            Text(album.title)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadAlbumThumbnail()
        }
    }
    
    private func loadAlbumThumbnail() {
        let assets = imagePickerService.loadPhotos(from: album)
        guard let firstAsset = assets.first else { return }
        
        Task {
            do {
                let thumbnail = try await imagePickerService.requestThumbnail(for: firstAsset)
                await MainActor.run {
                    self.thumbnailImage = thumbnail
                }
            } catch {
            }
        }
    }
}

// MARK: - Selected Media Thumbnail

struct SelectedMediaThumbnail: View {
    let asset: PHAsset
    let onRemove: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @EnvironmentObject var imagePickerService: ImagePickerService
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .background(Color.white, in: Circle())
                    }
                    .offset(x: 8, y: -8)
                }
                Spacer()
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        Task {
            do {
                let thumbnail = try await imagePickerService.requestThumbnail(for: asset)
                await MainActor.run {
                    self.thumbnailImage = thumbnail
                }
            } catch {
            }
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    let onResult: (CameraResult) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onResult: (CameraResult) -> Void
        
        init(onResult: @escaping (CameraResult) -> Void) {
            self.onResult = onResult
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onResult(.image(image))
            } else if let videoURL = info[.mediaURL] as? URL {
                onResult(.video(videoURL))
            }
            
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

enum CameraResult {
    case image(UIImage)
    case video(URL)
}

// // #Preview {
//     MediaPickerView(onSelection: { _ in })
//         .environmentObject(ImagePickerService())
//         .environmentObject(MediaProcessingService())
// }