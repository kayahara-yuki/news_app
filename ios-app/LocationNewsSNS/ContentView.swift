import SwiftUI
import MapKit

struct ContentView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671), // 東京駅
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showingPostCreation = false
    @State private var selectedPost: Post?
    @State private var showingPostDetail = false
    @State private var selectedPinPost: Post? // ピン選択時の吹き出し表示用
    @EnvironmentObject private var viewModel: NearbyPostsViewModel

    // マップスクロール監視用
    @State private var lastFetchedCoordinate: CLLocationCoordinate2D?
    @State private var fetchTask: Task<Void, Never>?

    // 検索範囲の半径（メートル単位）
    @State private var selectedRadius: Double = 2000 // デフォルト2km

    init() {
        // タブバーのアイコンとテキストの色を設定
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear

        // 非選択時を濃いグレーに（黒寄り）
        appearance.stackedLayoutAppearance.normal.iconColor = .darkGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.darkGray
        ]

        // 選択時を青色に
        appearance.stackedLayoutAppearance.selected.iconColor = .systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            // メイン地図画面
            NavigationView {
                ZStack {
                    // パフォーマンス最適化: カスタムMapAnnotationから標準Markerに変更
                    Map(coordinateRegion: $region, annotationItems: viewModel.posts) { post in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(
                            latitude: post.latitude ?? 35.6812,
                            longitude: post.longitude ?? 139.7671
                        )) {
                            ZStack {
                                // ピン
                                Image(systemName: post.isUrgent ? "exclamationmark.triangle.fill" : "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(
                                        selectedPinPost?.id == post.id ? .orange :
                                        (post.isUrgent ? .red : .blue)
                                    )
                                    .background(
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 28, height: 28)
                                    )
                                    .scaleEffect(selectedPinPost?.id == post.id ? 2.0 : 1.0)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if selectedPinPost?.id == post.id {
                                                // 同じピンをタップしたら閉じる
                                                selectedPinPost = nil
                                            } else {
                                                // 別のピンをタップしたら選択
                                                selectedPinPost = post
                                            }
                                        }
                                    }

                                // 吹き出し（選択時のみ表示）
                                if selectedPinPost?.id == post.id {
                                    MapPinCalloutView(post: post) {
                                        // 吹き出しタップで詳細画面を表示
                                        selectedPost = post
                                        showingPostDetail = true
                                    }
                                    .offset(y: -140) // ピンの上に配置（絶対位置）
                                    .transition(.scale.combined(with: .opacity))
                                    .zIndex(1)
                                }
                            }
                        }
                    }
                    .overlay(
                        // 選択された範囲の円を表示
                        MapCircleOverlay(center: region.center, radius: selectedRadius, span: region.span)
                    )
                    .ignoresSafeArea()
                    .onChange(of: region.center.latitude) { _ in
                        onMapRegionChanged(newCoordinate: region.center)
                    }
                    .onChange(of: region.center.longitude) { _ in
                        onMapRegionChanged(newCoordinate: region.center)
                    }
                    .onChange(of: selectedRadius) { _ in
                        // 範囲変更時に投稿を再取得
                        onMapRegionChanged(newCoordinate: region.center)
                    }

                    // カスタムヘッダー（ナビゲーションバー不使用）
                    VStack {
                        HStack(alignment: .top) {
                            // 左側: 距離選択ボタン
                            RadiusSelectorView(selectedRadius: $selectedRadius)
                                .padding(.leading, 16)

                            Spacer()

                            // 右側: 投稿作成ボタン
                            Button(action: {
                                showingPostCreation = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .padding(.trailing, 16)
                        }
                        .padding(.top, 8)

                        Spacer()
                    }

                    // タブバーエリアを暗くするグラデーションオーバーレイ
                    VStack {
                        Spacer()
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.6)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 100)
                        .allowsHitTesting(false)
                    }
                    .ignoresSafeArea()

                    VStack {
                        Spacer()

                        // Liquid Glass エフェクトのボトムシート
                        PostListBottomSheet(viewModel: viewModel, region: $region, selectedPinPost: $selectedPinPost)
                            .padding(.bottom, 16)
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
            .navigationViewStyle(.stack)
            .tabItem {
                Label("地図", systemImage: "map")
            }

            // フィード画面
            NavigationView {
                PostFeedView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("フィード", systemImage: "list.bullet")
            }

            // 緊急情報画面
            NavigationView {
                EmergencyView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("緊急", systemImage: "exclamationmark.triangle")
            }

            // プロフィール画面
            NavigationView {
                ProfileView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("プロフィール", systemImage: "person.circle")
            }
        }
        .tabViewStyle(.automatic)
        .preferredColorScheme(.light)
    }

    // MARK: - Map Region Changed

    private func onMapRegionChanged(newCoordinate: CLLocationCoordinate2D) {
        // 前回の取得位置から十分離れているかチェック（約500m以上）
        if let lastCoordinate = lastFetchedCoordinate {
            let distance = newCoordinate.distance(to: lastCoordinate)
            if distance < 500 { // 500m未満の移動は無視
                return
            }
        }

        // 既存のタスクをキャンセル
        fetchTask?.cancel()

        // デバウンス処理: 1秒後に実行
        fetchTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            } catch {
                return // キャンセルされた場合は終了
            }

            guard !Task.isCancelled else { return }

            // 新しい座標で投稿を取得（選択された範囲で）
            await viewModel.fetchNearbyPostsForCoordinate(
                latitude: newCoordinate.latitude,
                longitude: newCoordinate.longitude,
                radius: selectedRadius
            )

            lastFetchedCoordinate = newCoordinate
        }
    }
}

struct PostListBottomSheet: View {
    @ObservedObject var viewModel: NearbyPostsViewModel
    @Binding var region: MKCoordinateRegion
    @Binding var selectedPinPost: Post?
    @State private var selectedPost: Post?
    @State private var scrollPosition: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // 横スクロールカルーセル
            if viewModel.posts.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(viewModel.posts) { post in
                                CarouselPostCardView(
                                    post: post,
                                    isSelected: selectedPost?.id == post.id
                                )
                                .onTapGesture {
                                    // 位置情報を先に取得
                                    let postLatitude = post.latitude
                                    let postLongitude = post.longitude

                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedPost = post
                                        selectedPinPost = post // ピンの状態も更新
                                        scrollPosition = post.id

                                        // カードを中央にスクロール
                                        proxy.scrollTo(post.id, anchor: .center)
                                    }

                                    // マップをピンの位置に移動
                                    if let lat = postLatitude, let lng = postLongitude {
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
                        .padding(.vertical, 4)
                    }
                    .frame(height: 175)
                }
            }
        }
        .background(Color.clear)
        .onAppear {
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
    @EnvironmentObject private var viewModel: NearbyPostsViewModel
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
    @EnvironmentObject var authService: AuthService
    @State private var showLogoutAlert = false

    var body: some View {
        VStack(spacing: 20) {
            // プロフィール画像
            Circle()
                .fill(.gray.opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay {
                    if let avatarURL = authService.currentUser?.avatarURL,
                       let url = URL(string: avatarURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(Circle())

            VStack(spacing: 8) {
                Text(authService.currentUser?.displayName ?? authService.currentUser?.username ?? "ユーザー名")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let username = authService.currentUser?.username {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let email = authService.currentUser?.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 20) {
                VStack {
                    Text("投稿")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("0")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                VStack {
                    Text("フォロワー")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("0")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                VStack {
                    Text("フォロー中")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("0")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }

            // ログアウトボタン
            Button(action: {
                showLogoutAlert = true
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("ログアウト")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundColor(.white)
                .background(Color.red)
                .cornerRadius(12)
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)

            Spacer()
        }
        .padding()
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.large)
        .alert("ログアウト", isPresented: $showLogoutAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("ログアウト", role: .destructive) {
                Task {
                    await authService.signOut()
                }
            }
        } message: {
            Text("本当にログアウトしますか？")
        }
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
                        CachedAsyncImage(url: URL(string: post.user.avatarURL ?? "")) { image in
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

// MARK: - Radius Selector View
struct RadiusSelectorView: View {
    @Binding var selectedRadius: Double
    @State private var isExpanded: Bool = false

    let radiusOptions: [Double] = [1000, 2000, 3000, 4000, 5000]

    var body: some View {
        HStack(spacing: 8) {
            if isExpanded {
                // 展開時: 全てのオプションを表示
                ForEach(radiusOptions, id: \.self) { radius in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedRadius = radius
                            isExpanded = false
                        }
                    }) {
                        Text("\(Int(radius / 1000))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedRadius == radius ? .white : .primary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(selectedRadius == radius ? Color.blue : Color.white.opacity(0.3))
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(selectedRadius == radius ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            } else {
                // 折りたたみ時: 現在の選択値のみ表示
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "scope")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(Int(selectedRadius / 1000))km")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, isExpanded ? 12 : 0)
        .padding(.vertical, isExpanded ? 8 : 0)
    }
}

// MARK: - Map Circle Overlay
struct MapCircleOverlay: View {
    let center: CLLocationCoordinate2D
    let radius: Double // メートル単位
    let span: MKCoordinateSpan

    var body: some View {
        GeometryReader { geometry in
            // 緯度1度あたりのメートル数（約111km）
            let metersPerLatitudeDegree = 111000.0

            // 経度1度あたりのメートル数（緯度によって変わる）
            let metersPerLongitudeDegree = 111000.0 * cos(center.latitude * .pi / 180)

            // 画面上でのスケール計算
            let latitudeScale = geometry.size.height / (span.latitudeDelta * metersPerLatitudeDegree)
            let longitudeScale = geometry.size.width / (span.longitudeDelta * metersPerLongitudeDegree)

            // 平均スケールを使用（円形を保つため）
            let averageScale = (latitudeScale + longitudeScale) / 2
            let radiusInPoints = radius * averageScale

            ZStack {
                // 塗りつぶし（透明度を下げて視認性向上）
                Circle()
                    .fill(Color.blue.opacity(0.05))
                    .frame(
                        width: radiusInPoints * 2,
                        height: radiusInPoints * 2
                    )

                // 境界線（より目立たせる）
                Circle()
                    .stroke(Color.blue.opacity(0.8), lineWidth: 2.5)
                    .frame(
                        width: radiusInPoints * 2,
                        height: radiusInPoints * 2
                    )
            }
            .position(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Map Pin Callout View
struct MapPinCalloutView: View {
    let post: Post
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ユーザー情報
            HStack(spacing: 8) {
                if let avatarURL = post.user.avatarURL, let url = URL(string: avatarURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.user.displayName ?? post.user.username)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(post.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if post.user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                        .font(.caption2)
                }
            }

            // 投稿内容プレビュー
            Text(post.content)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.primary)

            // バッジとエンゲージメント
            HStack(spacing: 8) {
                if post.isUrgent {
                    Label("緊急", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }

                if post.isVerified {
                    Label("検証済み", systemImage: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                }

                Spacer()

                HStack(spacing: 12) {
                    Label("\(post.likeCount)", systemImage: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Label("\(post.commentCount)", systemImage: "bubble.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture {
            onTap()
        }
        // 吹き出しの下にある三角形
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(Color(.systemBackground))
                .frame(width: 20, height: 10)
                .offset(y: 10)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
        }
    }
}

// 三角形の形状
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ContentView()
}