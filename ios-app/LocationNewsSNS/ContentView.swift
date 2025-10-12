import SwiftUI
import MapKit

struct ContentView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503), // 東京駅
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showingPostCreation = false
    @State private var selectedPost: Post?
    @State private var showingPostDetail = false
    @StateObject private var viewModel = NearbyPostsViewModel()

    var body: some View {
        TabView {
            // メイン地図画面
            NavigationStack {
                ZStack {
                    Map(coordinateRegion: $region, annotationItems: viewModel.posts) { post in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(
                            latitude: post.latitude ?? 35.6762,
                            longitude: post.longitude ?? 139.6503
                        )) {
                            VStack(spacing: 0) {
                                Image(systemName: post.isUrgent ? "exclamationmark.triangle.fill" : "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundColor(post.isUrgent ? .red : .blue)
                                    .background(
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 32, height: 32)
                                    )
                            }
                            .onTapGesture {
                                selectedPost = post
                                showingPostDetail = true
                            }
                        }
                    }
                    .ignoresSafeArea()

                    VStack {
                        Spacer()

                        // Liquid Glass エフェクトのボトムシート
                        PostListBottomSheet(viewModel: viewModel)
                    }
                }
                .navigationTitle("地図SNS")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingPostCreation = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
                .sheet(isPresented: $showingPostCreation) {
                    PostCreationView()
                }
                .sheet(isPresented: $showingPostDetail) {
                    if let post = selectedPost {
                        PostDetailSheet(post: post)
                    }
                }
            }
            .tabItem {
                Label("地図", systemImage: "map")
            }
            
            // フィード画面
            NavigationStack {
                PostFeedView()
            }
            .tabItem {
                Label("フィード", systemImage: "list.bullet")
            }
            
            // 緊急情報画面
            NavigationStack {
                EmergencyView()
            }
            .tabItem {
                Label("緊急", systemImage: "exclamationmark.triangle")
            }
            
            // プロフィール画面
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("プロフィール", systemImage: "person.circle")
            }
        }
        .preferredColorScheme(.light)
    }
}

struct PostListBottomSheet: View {
    @ObservedObject var viewModel: NearbyPostsViewModel
    @State private var selectedPost: Post?
    @State private var showingPostDetail = false
    @State private var scrollPosition: Int?

    var body: some View {
        VStack(spacing: 12) {
            // ハンドル
            Capsule()
                .fill(.secondary)
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                Text("近くの投稿")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)

            // 横スクロールカルーセル
            if viewModel.posts.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            let _ = print("🎨 [ContentView] 投稿を表示: \(post.id) - \(post.content.prefix(30))...")
                            CarouselPostCardView(
                                post: post,
                                isSelected: selectedPost?.id == post.id,
                                onTap: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedPost = post
                                        scrollPosition = index
                                    }
                                    showingPostDetail = true
                                },
                                onLocationTap: {
                                    // TODO: 地図の位置を移動
                                }
                            )
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $scrollPosition)
                .scrollTargetBehavior(.viewAligned)
                .frame(height: 240)
            }
        }
        .frame(height: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .sheet(isPresented: $showingPostDetail) {
            if let post = selectedPost {
                // TODO: PostDetailViewを実装
                Text("投稿詳細: \(post.content)")
            }
        }
        .onAppear {
            print("👀 [ContentView] PostListBottomSheet.onAppear - viewModel.posts.count: \(viewModel.posts.count)")
            viewModel.fetchNearbyPosts()
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "map.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("近くに投稿がありません")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
        .padding()
    }
}

// PostCardView は NearbyPostCardView.swift に移動しました

struct PostFeedView: View {
    @StateObject private var viewModel = NearbyPostsViewModel()
    @State private var selectedPost: Post?
    @State private var showingPostDetail = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView()
                        .padding()
                } else if viewModel.posts.isEmpty {
                    emptyStateView
                } else {
                    ForEach(viewModel.posts) { post in
                        NearbyPostCardView(
                            post: post,
                            onTap: {
                                selectedPost = post
                                showingPostDetail = true
                            },
                            onLocationTap: {
                                // TODO: 地図タブに移動して該当位置を表示
                            },
                            onUserTap: {
                                // TODO: ユーザープロフィールを表示
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("フィード")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.refreshPosts()
        }
        .sheet(isPresented: $showingPostDetail) {
            if let post = selectedPost {
                // TODO: PostDetailViewを実装
                Text("投稿詳細: \(post.content)")
            }
        }
        .onAppear {
            if viewModel.posts.isEmpty {
                viewModel.fetchNearbyPosts()
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("投稿がありません")
                .font(.title3)
                .fontWeight(.semibold)

            Text("近くで投稿を作成してみましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 100)
    }
}

struct EmergencyView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("緊急情報")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("現在、緊急情報はありません")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
        .navigationTitle("緊急情報")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ProfileView: View {
    var body: some View {
        VStack(spacing: 20) {
            // プロフィール画像
            Circle()
                .fill(.gray.opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
            
            VStack(spacing: 8) {
                Text("ユーザー名")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("@username")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 20) {
                VStack {
                    Text("投稿")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("42")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("フォロワー")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("128")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("フォロー中")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("67")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Post Detail Sheet
struct PostDetailSheet: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // User Info Section
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: post.user.avatarURL ?? "")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            if let displayName = post.user.displayName {
                                Text(displayName)
                                    .font(.headline)
                            }
                            Text("@\(post.user.username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    Divider()

                    // Post Content Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(post.content)
                            .font(.body)
                            .lineSpacing(4)

                        // Badges
                        HStack(spacing: 8) {
                            if post.isUrgent {
                                Label("緊急", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }

                            if post.isVerified {
                                Label("検証済み", systemImage: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }

                            Text(post.category.displayName)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.gray)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // Location Section
                    if post.latitude != nil && post.longitude != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("位置情報", systemImage: "location.fill")
                                .font(.headline)

                            if let address = post.address {
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("緯度: \(post.latitude!, specifier: "%.6f"), 経度: \(post.longitude!, specifier: "%.6f")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        Divider()
                    }

                    // Stats Section
                    HStack(spacing: 24) {
                        Label("\(post.likeCount)", systemImage: "heart.fill")
                            .foregroundColor(.red)

                        Label("\(post.commentCount)", systemImage: "bubble.left.fill")
                            .foregroundColor(.blue)

                        Label("\(post.shareCount)", systemImage: "square.and.arrow.up.fill")
                            .foregroundColor(.green)
                    }
                    .font(.subheadline)
                    .padding(.horizontal)

                    Divider()

                    // Timestamp Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("投稿日時")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(post.createdAt, style: .date)
                            .font(.subheadline)
                        Text(post.createdAt, style: .time)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("投稿詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}