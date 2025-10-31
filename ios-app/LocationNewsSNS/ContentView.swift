import SwiftUI
import MapKit

// MARK: - Constants
private let kPinFocusZoomSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)

struct ContentView: View {
    // MARK: - Constants
    private let defaultMapSpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    private let springAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)

    // MARK: - State Properties
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671), // 東京駅
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showingPostCreation = false
    @State private var selectedPost: Post?
    @State private var selectedPinPost: Post? // ピン選択時の吹き出し表示用
    @State private var selectedCardPost: Post? // カード選択状態
    @State private var selectedNews: NewsStory? // ニュース選択状態
    @EnvironmentObject private var viewModel: NearbyPostsViewModel
    @EnvironmentObject private var locationService: LocationService
    @StateObject private var newsService = NewsService()

    @EnvironmentObject private var postService: PostService
    @EnvironmentObject private var authService: AuthService

    // マップスクロール監視用の変数を削除
    // 地図移動時の自動取得機能を無効化

    // 検索範囲の半径（メートル単位）- 過去3日以内の全投稿を取得するため、距離フィルタは使用しない
    // @State private var selectedRadius: Double = 2000 // デフォルト2km (不要)

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
            mapTabView
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
        .safariSheet() // アプリ全体にSafariシート機能を適用
        .onAppear {
            // アプリ起動時に位置情報の許可をリクエスト
            print("🗺️ [ContentView] アプリ起動 - 位置情報許可をリクエスト")
            locationService.requestPermission()

            // 位置情報が許可されていて現在地が取得できている場合、地図の初期位置を現在地に設定
            if locationService.authorizationStatus == .authorizedWhenInUse ||
               locationService.authorizationStatus == .authorizedAlways,
               let currentLocation = locationService.currentLocation {
                print("📍 [ContentView] 位置情報取得成功: lat=\(currentLocation.coordinate.latitude), lng=\(currentLocation.coordinate.longitude)")
                region = MKCoordinateRegion(
                    center: currentLocation.coordinate,
                    span: defaultMapSpan
                )

                // ニュースを取得
                Task {
                    print("📰 [ContentView] ニュース取得開始")
                    await newsService.fetchNearbyNews(userLocation: currentLocation.coordinate)
                    print("📰 [ContentView] ニュース取得完了: 件数=\(newsService.nearbyNews.count)")
                }
            } else {
                print("⚠️ [ContentView] 位置情報が取得できていません - authStatus=\(locationService.authorizationStatus.rawValue)")
            }
        }
        // 位置情報変更時の自動処理を削除（地図移動時の自動取得機能を無効化したため不要）
        // 投稿リスト変更時の処理を削除（地図移動時の自動取得を無効化したため不要）
    }

    // MARK: - Map Tab View

    private var mapTabView: some View {
        NavigationView {
            ZStack {
                    // パフォーマンス最適化: 投稿IDで差分更新を最適化
                    Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: viewModel.posts) { post in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(
                            latitude: post.latitude ?? 35.6812,
                            longitude: post.longitude ?? 139.7671
                        )) {
                            PostMapAnnotationContent(
                                post: post,
                                selectedPinPost: $selectedPinPost,
                                selectedCardPost: $selectedCardPost,
                                region: $region,
                                selectedPost: $selectedPost,
                                springAnimation: springAnimation
                            )
                            .zIndex(selectedPinPost?.id == post.id ? 1000 : 0)
                            .id(post.id) // SwiftUIの差分更新を最適化
                        }
                    }
                    .id(viewModel.posts.map { $0.id }) // Map全体の再描画を投稿IDリストで制御
                    // 距離フィルタを削除したため、円オーバーレイは不要
                    // .overlay(
                    //     MapCircleOverlay(center: region.center, radius: selectedRadius, span: region.span)
                    // )
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(springAnimation) {
                            selectedPinPost = nil
                            selectedCardPost = nil
                        }
                    }
                    // 地図移動時の自動取得を無効化（onChange削除）

                    // カスタムヘッダー（ナビゲーションバー不使用）
                    VStack(spacing: 8) {
                        HStack(alignment: .top) {
                            // 距離フィルタを削除したため、距離選択ボタンは非表示
                            // RadiusSelectorView(selectedRadius: $selectedRadius)
                            //     .padding(.leading, 16)

                            Spacer()

                            // 右側: 現在位置ボタン
                            Button {
                                // 現在位置にマップを移動
                                if let currentLocation = locationService.currentLocation {
                                    withAnimation {
                                        region = MKCoordinateRegion(
                                            center: currentLocation.coordinate,
                                            span: defaultMapSpan
                                        )
                                    }

                                    // ハプティックフィードバック
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                } else {
                                    // 位置情報がない場合は許可をリクエスト
                                    locationService.requestPermission()
                                }
                            } label: {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.blue)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                            }
                            .accessibilityLabel("現在位置に戻る")
                            .accessibilityHint("マップを現在位置に移動します")
                            .padding(.trailing, 16)
                        }
                        .padding(.top, 8)

                        // 投稿がない場合の上部バナー（ローディング中と空状態の両方で使用）
                        if viewModel.posts.isEmpty {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    // ローディング中
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)

                                    Text("投稿を読み込み中...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    // 空状態
                                    Image(systemName: "map.circle")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text("近くに投稿がありません")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        Spacer()
                    }

                    // FABボタン群（右下角）
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 16) {
                                // 新規投稿FABボタン（プラス）
                                Button {
                                    showingPostCreation = true

                                    // ハプティックフィードバック
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 56)
                                        .background(
                                            LinearGradient(
                                                colors: [.blue, .blue.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .clipShape(Circle())
                                        .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
                                }
                                .accessibilityLabel("新規投稿")
                                .accessibilityHint("タップで投稿作成")
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, !newsService.nearbyNews.isEmpty ? 200 : 30)
                        }
                    }
                    .zIndex(100) // ニュースカルーセルより前面に表示

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

                        // ニュースカルーセル（投稿カルーセルから切り替え）
                        NewsCarouselBottomSheet(
                            newsService: newsService,
                            region: $region,
                            selectedNews: $selectedNews
                        )
                        .padding(.bottom, 4)
                    }
                }
                .sheet(isPresented: $showingPostCreation) {
                    PostCreationView()
                }
                .sheet(item: $selectedPost) { post in
                    PostDetailSheet(post: post)
                }
            }
            .navigationViewStyle(.stack)
    }

    // MARK: - Map Region Changed
    // 地図移動時の自動取得機能を削除
    // onMapRegionChanged関数を削除
}

// MARK: - News Carousel Bottom Sheet

struct NewsCarouselBottomSheet: View {
    @ObservedObject var newsService: NewsService
    @Binding var region: MKCoordinateRegion
    @Binding var selectedNews: NewsStory?
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            if !newsService.nearbyNews.isEmpty {
                NearbyNewsCarouselView(
                    news: $newsService.nearbyNews,
                    selectedNews: $selectedNews,
                    newsService: newsService,
                    onNewsTapped: { news in
                        // ニュースタップ時の処理
                        selectedNews = news

                        // ニュース記事URLをアプリ内ブラウザで開く
                        if let url = URL(string: news.link) {
                            openURL(url)
                        }
                    },
                    onLocationTapped: { coordinate in
                        // 地図を移動
                        withAnimation {
                            region = MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                            )
                        }
                    }
                )
            } else if newsService.isLoading {
                ProgressView("ニュース取得中...")
                    .padding()
            } else {
                // 空の状態はNearbyNewsCarouselView内で表示
                NearbyNewsCarouselView(
                    news: $newsService.nearbyNews,
                    selectedNews: $selectedNews,
                    newsService: newsService,
                    onNewsTapped: nil,
                    onLocationTapped: nil
                )
            }
        }
        .background(Color.clear)
    }
}

struct PostListBottomSheet: View {
    @ObservedObject var viewModel: NearbyPostsViewModel
    @Binding var region: MKCoordinateRegion
    @Binding var selectedPinPost: Post?
    @Binding var selectedCardPost: Post?

    var body: some View {
        VStack(spacing: 0) {
            // 横スクロールカルーセル（投稿がある場合のみ表示）
            if !viewModel.posts.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(viewModel.posts) { post in
                                CarouselPostCardView(
                                    post: post,
                                    isSelected: selectedCardPost?.id == post.id
                                )
                                .onTapGesture {
                                    // 位置情報を先に取得
                                    let postLatitude = post.latitude
                                    let postLongitude = post.longitude

                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedCardPost = post
                                        selectedPinPost = post // ピンの状態も更新

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
                    .onChange(of: selectedCardPost?.id) { newPostId in
                        if let postId = newPostId {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                proxy.scrollTo(postId, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        .onAppear {
            viewModel.fetchNearbyPosts()
        }
    }
}

// PostCardView は NearbyPostCardView.swift に移動しました

struct PostFeedView: View {
    @EnvironmentObject private var viewModel: NearbyPostsViewModel
    @State private var selectedPost: Post?

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
        .sheet(item: $selectedPost) { post in
            // TODO: PostDetailViewを実装
            Text("投稿詳細: \(post.content)")
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


// MARK: - Radius Selector View
struct RadiusSelectorView: View {
    @Binding var selectedRadius: Double
    @State private var isExpanded: Bool = false

    private let radiusOptions: [Double] = [1000, 2000, 3000, 4000, 5000]
    private let springAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)

    var body: some View {
        HStack(spacing: 8) {
            if isExpanded {
                // 展開時: 全てのオプションを表示
                ForEach(radiusOptions, id: \.self) { radius in
                    Button(action: {
                        withAnimation(springAnimation) {
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
                    withAnimation(springAnimation) {
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
        VStack(spacing: 0) {
            // 吹き出し本体
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
                            .font(.subheadline) // キャプションから拡大
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
                    .font(.body) // キャプションから拡大
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
            .frame(width: 280) // 幅を拡大して見やすく
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            // 吹き出しの下にある三角形（独立した要素として配置）
            Triangle()
                .fill(Color(.systemBackground))
                .frame(width: 20, height: 10)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                .offset(y: -5) // 吹き出しと適度な距離を保つ
        }
    }
}

// MARK: - Post Map Annotation Content
struct PostMapAnnotationContent: View {
    let post: Post
    @Binding var selectedPinPost: Post?
    @Binding var selectedCardPost: Post?
    @Binding var region: MKCoordinateRegion
    @Binding var selectedPost: Post?
    let springAnimation: Animation

    var body: some View {
        VStack(spacing: 0) {
            // 吹き出し（選択時のみ表示）
            if selectedPinPost?.id == post.id {
                MapPinCalloutView(post: post) {
                    selectedPost = post
                }
                .transition(.scale.combined(with: .opacity))
                .padding(.bottom, 20) // 三角形とピンの間に十分な余白を追加
            }

            // ピン
            PostPinView(
                post: post,
                isSelected: selectedPinPost?.id == post.id,
                springAnimation: springAnimation,
                onTap: {
                    if selectedPinPost?.id == post.id {
                        withAnimation(springAnimation) {
                            selectedPinPost = nil
                            selectedCardPost = nil
                        }
                    } else {
                        withAnimation(springAnimation) {
                            selectedPinPost = post
                            selectedCardPost = post
                        }

                        if let lat = post.latitude, let lng = post.longitude {
                            withAnimation {
                                // 吹き出しの高さを考慮して、カメラ位置を少し下にオフセット
                                let latitudeOffset = kPinFocusZoomSpan.latitudeDelta * 0.15
                                region = MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(
                                        latitude: lat - latitudeOffset,
                                        longitude: lng
                                    ),
                                    span: kPinFocusZoomSpan
                                )
                            }
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Post Pin View
struct PostPinView: View {
    let post: Post
    let isSelected: Bool
    let springAnimation: Animation
    let onTap: () -> Void

    var body: some View {
        let iconName = post.isUrgent ? "exclamationmark.triangle.fill" : "mappin.circle.fill"
        let pinColor: Color = isSelected ? .orange : (post.isUrgent ? .red : .blue)

        Image(systemName: iconName)
            .font(.title2)
            .foregroundColor(pinColor)
            .background(
                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)
            )
            .scaleEffect(isSelected ? 2.0 : 1.0)
            .contentShape(Circle())
            .highPriorityGesture(
                TapGesture()
                    .onEnded { _ in
                        onTap()
                    }
            )
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

// MARK: - Quick Voice Post Sheet

#Preview {
    ContentView()
}