import SwiftUI
import PhotosUI

// MARK: - メディア添付コンポーネント

struct MediaAttachmentView: View {
    @Binding var images: [UIImage]
    let onRemove: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                MediaImageThumbnailView(
                    image: image,
                    onRemove: { onRemove(index) }
                )
            }
        }
    }
}

// MARK: - メディア画像サムネイル

struct MediaImageThumbnailView: View {
    let image: UIImage
    let onRemove: () -> Void

    @State private var showingFullScreen = false

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    showingFullScreen = true
                }

            // 削除ボタン
            VStack {
                HStack {
                    Spacer()
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                Spacer()
            }
            .padding(4)
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            FullScreenImageView(image: image)
        }
    }
}

// MARK: - フルスクリーン画像ビュー

struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, min(value, 4.0))
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .background(Color.black)
            .navigationBarItems(
                leading: Button("完了") { dismiss() }
                    .foregroundColor(.white)
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MediaPickerViewはMediaPickerView.swiftで定義

// MARK: - メディアアップロード進捗

struct MediaUploadProgressView: View {
    let progress: Double
    let fileName: String
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(Int(progress * 100))% アップロード中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - メディアエラー表示

struct MediaErrorView: View {
    let error: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("アップロードに失敗")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("再試行") {
                    onRetry()
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("削除") {
                    onDismiss()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - メディアタイプ判定

enum AttachmentMediaType {
    case image
    case video
    case unknown

    var iconName: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .unknown:
            return "doc"
        }
    }

    var displayName: String {
        switch self {
        case .image:
            return "画像"
        case .video:
            return "動画"
        case .unknown:
            return "ファイル"
        }
    }
}

extension AttachmentMediaType {
    static func from(url: String) -> AttachmentMediaType {
        let lowercaseURL = url.lowercased()
        
        if lowercaseURL.contains(".jpg") || lowercaseURL.contains(".jpeg") ||
           lowercaseURL.contains(".png") || lowercaseURL.contains(".gif") ||
           lowercaseURL.contains(".webp") || lowercaseURL.contains(".heic") {
            return .image
        } else if lowercaseURL.contains(".mp4") || lowercaseURL.contains(".mov") ||
                  lowercaseURL.contains(".avi") || lowercaseURL.contains(".mkv") {
            return .video
        } else {
            return .unknown
        }
    }
}

#Preview {
    VStack {
        MediaAttachmentView(
            images: .constant([
                UIImage(systemName: "photo")!,
                UIImage(systemName: "camera")!,
                UIImage(systemName: "video")!
            ]),
            onRemove: { _ in }
        )
        
        MediaUploadProgressView(
            progress: 0.65,
            fileName: "IMG_001.jpg",
            onCancel: {}
        )
        
        MediaErrorView(
            error: "ネットワークエラーが発生しました",
            onRetry: {},
            onDismiss: {}
        )
    }
    .padding()
}