# 位置情報ベースニュース共有 SNS プラットフォーム - 設計書

## 目次

1. [システムアーキテクチャ設計](#システムアーキテクチャ設計)
2. [UI/UX 設計](#uiux設計)
3. [技術設計](#技術設計)
4. [地図・位置情報設計](#地図位置情報設計)
5. [セキュリティ設計](#セキュリティ設計)
6. [データ設計](#データ設計)

---

## システムアーキテクチャ設計

### 全体アーキテクチャ図（iOS + Supabase）

```
┌─────────────────────────────────────────────────────────────────┐
│                     iOS アプリ層                                │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐│
│  │               SwiftUI App                                   ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        ││
│  │  │  Map View   │  │ Post Feed   │  │ Profile     │        ││
│  │  │  (MapKit)   │  │   View      │  │   View      │        ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘        ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────────────────┐
                    │   Supabase SDK      │
                    │   (Swift Client)    │
                    └───────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                   Supabase Backend                               │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │ PostgreSQL  │  │ Auth        │  │ Realtime    │              │
│  │ + PostGIS   │  │ (JWT)       │  │ (WebSocket) │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │ Storage     │  │ Edge        │  │ API         │              │
│  │ (Files)     │  │ Functions   │  │ (PostgREST) │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

### iOS + Supabase アーキテクチャ構成

#### 1. iOS アプリケーション層

- **フレームワーク**: SwiftUI (iOS 18+)
- **アーキテクチャ**: MVVM + Clean Architecture
- **責務**: ユーザーインターフェース、ユーザーインタラクション、状態管理
- **主要コンポーネント**:
  - MapView (MapKit 統合)
  - PostFeedView (投稿一覧)
  - ProfileView (ユーザープロフィール)
  - EmergencyView (災害時モード)

#### 2. Supabase バックエンド統合

- **認証**: Supabase Auth (JWT + OAuth)
- **データベース**: PostgreSQL + PostGIS
- **リアルタイム**: Supabase Realtime (WebSocket)
- **ストレージ**: Supabase Storage
- **API**: 自動生成 RESTful API (PostgREST)
- **エッジ関数**: Deno による serverless functions

#### 3. 位置情報・地図機能

- **地図エンジン**: MapKit (iOS 18 最新機能)
- **位置情報**: CoreLocation + LocationManager
- **空間データ処理**: PostGIS + Supabase Edge Functions
- **ジオコーディング**: Apple Maps + 独自実装

#### 4. メディア処理

- **アップロード**: Supabase Storage
- **画像処理**: iOS Image I/O + Core Image
- **動画処理**: AVFoundation
- **最適化**: クライアントサイド圧縮 + サーバーサイド最適化

#### 5. 通知システム

- **プッシュ通知**: Apple Push Notification Service (APNs)
- **リアルタイム更新**: Supabase Realtime
- **緊急通知**: 高優先度プッシュ通知
- **位置ベース通知**: CoreLocation + 地域監視

### データフロー設計

#### 1. 投稿作成フロー (iOS + Supabase)

```
1. SwiftUI App → Supabase SDK (投稿データ準備)
2. Supabase SDK → Supabase Storage (メディアアップロード)
3. Supabase SDK → PostgreSQL (投稿保存 + PostGIS位置データ)
4. PostgreSQL Trigger → Supabase Realtime (リアルタイム配信)
5. Supabase Edge Function → APNs (フォロワーへプッシュ通知)
```

#### 2. 地図データ取得フロー (MapKit + Supabase)

```
1. MapView → CoreLocation (現在位置取得)
2. SwiftUI App → Supabase SDK (位置ベース投稿クエリ)
3. Supabase → PostGIS (空間検索処理)
4. MapKit → Apple Maps (地図タイル表示)
5. SwiftUI → MapKit (投稿アノテーション表示)
```

#### 3. リアルタイム通知フロー (iOS Native)

```
1. イベント発生 → Supabase Database
2. Supabase Realtime → iOS WebSocket接続
3. Supabase Edge Function → APNs
4. APNs → iOS デバイス (プッシュ通知)
5. iOS App → UI更新 (リアルタイム反映)
```

---

## UI/UX 設計

### 地図ベースメイン UI 設計

#### 1. iOS アプリレイアウト構成

```
┌─────────────────────────────────────────────────────────────────┐
│ Navigation Bar: タイトル | プロフィール | 通知アイコン        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                                                             │ │
│  │                     MapKit地図                              │ │
│  │                                                             │ │
│  │  📍 投稿アノテーション                                        │ │
│  │  🔴 緊急情報アノテーション                                     │ │
│  │  🏢 避難所アノテーション                                       │ │
│  │                                                             │ │
│  │  [現在位置ボタン]                                             │ │
│  │  [フィルターボタン]                                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  投稿詳細Sheet (表示時)                                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Liquid Glass Effect                                        │ │
│  │ ユーザー情報 | 投稿内容 | アクション                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│ Tab Bar: 地図 | フィード | 投稿 | 緊急 | プロフィール         │
└─────────────────────────────────────────────────────────────────┘
```

#### 2. MapKit インタラクション（iOS）

- **ズーム操作**: ピンチジェスチャ
- **パン操作**: ドラッグジェスチャ
- **マーカータップ**: 投稿詳細カード表示（Liquid Glass エフェクト）
- **長押し**: 新規投稿作成（位置情報自動取得）
- **3D Touch**: 投稿プレビュー表示

#### 3. マーカー設計

- **通常投稿**: 青色円形マーカー
- **ニュース投稿**: オレンジ色新聞アイコン
- **緊急情報**: 赤色警告アイコン
- **避難所**: 緑色家アイコン
- **支援拠点**: 紫色ハートアイコン

### ユーザーインターフェース設計（SwiftUI）

#### 1. 投稿作成画面（Sheet Presentation + Liquid Glass）

```swift
struct PostCreationView: View {
    @State private var content: String = ""
    @State private var url: String = ""
    @State private var selectedLocation: CLLocation?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // テキスト入力
                TextEditor(text: $content)
                    .frame(minHeight: 100)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // URL入力
                HStack {
                    Image(systemName: "link")
                    TextField("ニュースURLを貼り付け", text: $url)
                }
                .padding()
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))

                // 位置情報設定
                LocationSelector(selectedLocation: $selectedLocation)
            }
            .padding()
            .navigationTitle("新規投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("投稿") { }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.regularMaterial)
    }
}
```

│ 📁 メディア: [📷] [🎥] [📎] │
│ 🏷️ カテゴリ: [▼ 選択] │
│ 🔒 公開範囲: [▼ 全体公開] │
│ │
│ [キャンセル] [下書き保存] [投稿] │
└─────────────────────────────────────────┘

```

#### 2. プロフィール画面

```

┌─────────────────────────────────────────┐
│ [@username] [フォロー] │
├─────────────────────────────────────────┤
│ [プロフィール画像] 名前: 田中太郎 │
│ 場所: 東京都 │
│ 投稿: 123 │
│ フォロワー: 456 │
│ フォロー中: 78 │
│ │
│ 自己紹介: 地域のニュースをお届けします │
│ │
│ ┌─────────────────────────────────────┐ │
│ │ 投稿一覧 │ │
│ │ [投稿 1] [投稿 2] [投稿 3] ... │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘

```

#### 3. 災害時緊急画面

```

┌─────────────────────────────────────────┐
│ 🚨 緊急モード - 災害情報 │
├─────────────────────────────────────────┤
│ ⚠️ 最新緊急情報 │
│ ├ 地震情報: M7.0 震度 6 強 東京都... │
│ ├ 津波警報: 千葉県沿岸... │
│ └ 避難指示: 〇〇区全域... │
│ │
│ 🏥 避難所情報 │
│ ├ 〇〇小学校 (空きあり) │
│ ├ △△ 体育館 (満員) │
│ └ ×× 公民館 (不明) │
│ │
│ 👨‍👩‍👧‍👦 安否確認 │
│ [家族の安否を確認] [自分の安否を報告] │
└─────────────────────────────────────────┘

````

### ユーザーエクスペリエンス設計

#### 1. 情報発見体験

- **直感的な地図操作**: パン・ズームで興味のある地域を探索
- **スマートフィルタリング**: カテゴリ・時間・信頼度での絞り込み
- **関連情報の提案**: 閲覧中の投稿に関連する近隣情報を自動提案

#### 2. 投稿作成体験

- **位置情報の自動取得**: GPS による現在地自動設定
- **リンク解析**: URL 貼り付け時の自動メタデータ取得・位置推定
- **メディア最適化**: 画像・動画の自動圧縮・リサイズ

#### 3. 社会的相互作用体験

- **リアルタイム反応**: いいね・コメントの即座反映
- **適切な通知**: 重要度に応じた通知レベルの調整
- **コミュニティ形成**: 地域ベースのつながり促進

### 画面サイズ対応設計 (iOS)

#### 1. iPhone Pro Max (430px幅)

- フルスクリーン地図表示
- 大きなタップターゲット
- 詳細な投稿情報表示

#### 2. iPhone標準 (393px幅)

- 最適化された地図表示
- 標準的なUIコンポーネント
- バランスの取れた情報密度

#### 3. iPhone mini (375px幅)

- コンパクトなUI要素
- 重要情報の優先表示
- 効率的なナビゲーション

#### 4. iPad対応

- Split View / Slide Over対応
- より詳細な情報表示
- マルチタスク最適化

---

## 技術設計

### フロントエンド技術スタック（iOS SwiftUI）

#### 1. 基盤技術

- **フレームワーク**: SwiftUI (iOS 18+)
- **アーキテクチャ**: MVVM + Clean Architecture
- **状態管理**: ObservableObject + @Published
- **ナビゲーション**: NavigationStack + NavigationPath
- **UI コンポーネント**: 最新 SwiftUI + Liquid Glass エフェクト

#### 2. 地図関連ライブラリ

- **地図エンジン**: MapKit (iOS 18の最新機能活用)
- **位置情報**: CoreLocation + LocationManager
- **地理空間処理**: 独自実装 + PostGIS バックエンド連携
- **クラスタリング**: MapKit のカスタムアノテーション

#### 3. データ・通信ライブラリ

- **HTTP クライアント**: URLSession + async/await
- **リアルタイム通信**: Supabase Realtime
- **データベース**: Supabase (PostgreSQL + PostGIS)
- **認証**: Supabase Auth
- **ストレージ**: Supabase Storage

#### 4. 開発・テストツール

- **依存性注入**: Resolver / DIContainer
- **テスト**: XCTest + ViewInspector
- **UI テスト**: XCUITest
- **コードフォーマット**: SwiftFormat + SwiftLint

#### 5. 最新機能活用

- **Liquid Glass**: iOS 18の新しい視覚エフェクト
- **Context7**: 最新ドキュメント自動取得による開発効率化
- **Swift 6**: Concurrency 最適化

### バックエンド技術スタック（Supabase）

#### 1. Supabase 基盤サービス

- **データベース**: PostgreSQL 15.x + PostGIS
- **認証**: Supabase Auth（JWT ベース）
- **リアルタイム**: Supabase Realtime（WebSocket）
- **API**: 自動生成 RESTful API + PostgREST
- **ストレージ**: Supabase Storage
- **関数**: Supabase Edge Functions（Deno）

#### 2. データベース設計（Supabase PostgreSQL）

- **空間データ**: PostGIS 拡張による地理データ処理
- **RLS**: Row Level Security による細かなアクセス制御
- **リアルタイム**: WebSocket による即座データ同期
- **バックアップ**: 自動バックアップ + ポイントインタイム復元

#### 3. Edge Functions（Deno）

```typescript
// 位置ベース投稿取得
export async function handler(req: Request) {
  const { lat, lng, radius } = await req.json()

  const { data, error } = await supabase
    .from('posts')
    .select('*')
    .within('location', lat, lng, radius)
    .order('created_at', { ascending: false })

  return new Response(JSON.stringify(data), {
    headers: { 'Content-Type': 'application/json' }
  })
}
````

#### 4. セキュリティ・認証

- **RLS ポリシー**: テーブルレベルのセキュリティ制御
- **JWT 認証**: Supabase Auth による自動 JWT 管理
- **OAuth**: Apple Sign-in, Google, GitHub 等
- **匿名認証**: ゲストユーザー対応

### API 設計（Supabase + Edge Functions）

#### 1. Supabase 自動生成 API

```swift
// SwiftUI からの Supabase 利用例
class PostViewModel: ObservableObject {
    @Published var posts: [Post] = []
    private let supabase = SupabaseClient(...)

    func fetchNearbyPosts(lat: Double, lng: Double, radius: Int) async {
        do {
            let posts: [Post] = try await supabase
                .from("posts")
                .select()
                .within("location", lat: lat, lng: lng, radius: radius)
                .order("created_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.posts = posts
            }
        } catch {
            print("Error fetching posts: \(error)")
        }
    }
}
```

#### 2. リアルタイム機能

```swift
// リアルタイム投稿監視
func subscribeToNearbyPosts() {
    supabase
        .from("posts")
        .on(.insert) { [weak self] payload in
            // 新しい投稿の受信処理
            self?.handleNewPost(payload.new)
        }
        .subscribe()
}
```

#### 3. Edge Functions エンドポイント

- `/functions/v1/geocoding` - 住所 ⇔ 座標変換
- `/functions/v1/emergency-alert` - 緊急通知処理
- `/functions/v1/post-clustering` - 投稿クラスタリング
- `/functions/v1/news-verification` - ニュース真偽性チェック

---

## 地図・位置情報設計

### 地図プラットフォーム選択（iOS MapKit）

#### 1. MapKit 選択理由

- **ネイティブ統合**: iOS システムとの完璧な統合
- **パフォーマンス**: Metal による高速レンダリング
- **プライバシー**: Apple のプライバシー重視設計
- **コスト効率**: 無料で高機能
- **オフライン対応**: システムレベルのオフライン地図

#### 2. 追加地図サービス連携

```swift
// MapKit + Apple Services 統合
struct MapView: UIViewRepresentable {
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = .standard

        // iOS 17+ の新機能活用
        if #available(iOS 17.0, *) {
            mapView.preferredConfiguration = .standard(elevationStyle: .realistic)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // リアルタイム更新処理
    }
}
```

#### 3. Apple Services 連携

- **Search**: MKLocalSearch による場所検索
- **Directions**: MKDirections による避難経路案内
- **Look Around**: iOS のストリートビュー機能

### 位置情報処理設計

#### 1. 位置情報取得方式 (iOS CoreLocation)

```swift
struct LocationData {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date
    let source: LocationSource
}

enum LocationSource {
    case gps
    case network
    case manual
}

class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: LocationData?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }

    func getCurrentLocation() {
        locationManager.requestLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        currentLocation = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: location.timestamp,
            source: .gps
        )
    }
}
```

#### 2. 位置情報プライバシー保護

- **精度調整**: 用途に応じた位置精度の調整（100m〜1km）
- **位置情報のハッシュ化**: 正確な位置の暗号化保存
- **匿名化オプション**: 大まかなエリア情報のみの表示選択

### ジオロケーション機能設計

#### 1. 逆ジオコーディング (iOS CoreLocation)

```swift
struct AddressComponents {
    let country: String
    let prefecture: String
    let city: String
    let ward: String?
    let district: String?
    let street: String?
    let building: String?
}

class GeocodingService: ObservableObject {
    private let geocoder = CLGeocoder()

    func reverseGeocode(location: CLLocation) async throws -> AddressComponents {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        guard let placemark = placemarks.first else {
            throw GeocodingError.noResults
        }

        return AddressComponents(
            country: placemark.country ?? "",
            prefecture: placemark.administrativeArea ?? "",
            city: placemark.locality ?? "",
            ward: placemark.subLocality,
            district: placemark.subThoroughfare,
            street: placemark.thoroughfare,
            building: placemark.name
        )
    }
}

enum GeocodingError: Error {
    case noResults
    case invalidLocation
}
```

#### 2. 近隣検索機能

```sql
-- PostGIS を使用した近隣検索クエリ例
SELECT
  id, title, content, created_at,
  ST_Distance(location, ST_Point($1, $2)::geography) as distance
FROM posts
WHERE
  ST_DWithin(location, ST_Point($1, $2)::geography, $3)
  AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY distance ASC
LIMIT 50;
```

### 地図上でのデータ表示設計

#### 1. クラスタリング表示 (MapKit)

```swift
struct ClusterConfig {
    let radius: Double
    let maxZoom: Double
    let minPoints: Int
}

class PostAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let post: Post

    init(post: Post) {
        self.post = post
        self.coordinate = CLLocationCoordinate2D(
            latitude: post.latitude,
            longitude: post.longitude
        )
        self.title = post.title
        self.subtitle = post.category.rawValue
        super.init()
    }
}

class PostClusterAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let posts: [Post]

    init(posts: [Post], coordinate: CLLocationCoordinate2D) {
        self.posts = posts
        self.coordinate = coordinate
        self.title = "\(posts.count)件の投稿"
        self.subtitle = "タップして詳細を表示"
        super.init()
    }
}

class MapClusterService {
    func clusterPosts(_ posts: [Post], in region: MKCoordinateRegion) -> [MKAnnotation] {
        // MapKit の自動クラスタリング機能を使用
        return posts.map { PostAnnotation(post: $0) }
    }
}
```

#### 2. 動的マーカー表示

- **ズームレベル連動**: 詳細度に応じたマーカー表示切り替え
- **カテゴリフィルター**: 選択カテゴリのみの表示
- **時間軸フィルター**: 指定期間の投稿のみ表示
- **重要度による優先表示**: 緊急情報の優先レンダリング

---

## セキュリティ設計

### 認証・認可設計

#### 1. Supabase Auth 認証システム

```swift
struct UserProfile {
    let id: UUID
    let email: String
    let role: UserRole
    let permissions: [String]
    let createdAt: Date
    let lastSignInAt: Date?
}

enum UserRole: String, CaseIterable {
    case user = "user"
    case moderator = "moderator"
    case admin = "admin"
}

class AuthService: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false

    private let supabase = SupabaseClient(...)

    func signIn(email: String, password: String) async throws {
        let response = try await supabase.auth.signIn(
            email: email,
            password: password
        )

        await MainActor.run {
            self.currentUser = UserProfile(from: response.user)
            self.isAuthenticated = true
        }
    }

    func signOut() async throws {
        try await supabase.auth.signOut()

        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }

    func signInWithApple() async throws {
        // Apple Sign-in implementation with Supabase
    }
}
```

#### 2. 認可レベル設計

- **Public**: 一般公開情報（地図表示、公開投稿閲覧）
- **Authenticated**: 認証ユーザー（投稿作成、コメント、いいね）
- **Owner**: リソース所有者（投稿編集・削除、プロフィール編集）
- **Moderator**: モデレーター（コンテンツ管理、ユーザー制限）
- **Admin**: 管理者（システム管理、全権限）

### データ保護設計

#### 1. iOS 暗号化戦略

```swift
// 位置情報の暗号化 (iOS CryptoKit)
import CryptoKit

struct LocationEncryption {
    private static let key = SymmetricKey(size: .bits256)

    static func encrypt(latitude: Double, longitude: Double) throws -> Data {
        let locationData = LocationData(latitude: latitude, longitude: longitude)
        let jsonData = try JSONEncoder().encode(locationData)

        let sealedBox = try AES.GCM.seal(jsonData, using: key)
        return sealedBox.combined!
    }

    static func decrypt(encryptedData: Data) throws -> (latitude: Double, longitude: Double) {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        let locationData = try JSONDecoder().decode(LocationData.self, from: decryptedData)
        return (locationData.latitude, locationData.longitude)
    }
}

private struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
}
```

#### 2. データベース暗号化

- **保存時暗号化**: PostgreSQL の TDE（Transparent Data Encryption）
- **カラムレベル暗号化**: 個人情報・位置情報の選択的暗号化
- **キー管理**: AWS KMS による暗号化キー管理

### プライバシー設計

#### 1. 位置情報プライバシー (iOS)

```swift
struct PrivacySettings {
    let locationPrecision: LocationPrecision
    let shareLocation: Bool
    let emergencyOverride: Bool
}

enum LocationPrecision: String, CaseIterable {
    case exact = "exact"
    case approximate = "approximate"
    case areaOnly = "area_only"
}

class LocationPrivacyService {
    func applyPrivacyFilter(
        location: CLLocationCoordinate2D,
        settings: PrivacySettings
    ) -> CLLocationCoordinate2D {
        switch settings.locationPrecision {
        case .exact:
            return location
        case .approximate:
            return addNoise(to: location, radius: 100) // 100m以内のノイズ
        case .areaOnly:
            return roundToArea(location: location, gridSize: 1000) // 1km四方に丸める
        }
    }

    private func addNoise(to location: CLLocationCoordinate2D, radius: Double) -> CLLocationCoordinate2D {
        let randomAngle = Double.random(in: 0...(2 * .pi))
        let randomDistance = Double.random(in: 0...radius)

        let deltaLat = randomDistance * cos(randomAngle) / 111000
        let deltaLng = randomDistance * sin(randomAngle) / (111000 * cos(location.latitude * .pi / 180))

        return CLLocationCoordinate2D(
            latitude: location.latitude + deltaLat,
            longitude: location.longitude + deltaLng
        )
    }

    private func roundToArea(location: CLLocationCoordinate2D, gridSize: Double) -> CLLocationCoordinate2D {
        let gridSizeDegrees = gridSize / 111000 // 約1度 = 111km

        let roundedLat = round(location.latitude / gridSizeDegrees) * gridSizeDegrees
        let roundedLng = round(location.longitude / gridSizeDegrees) * gridSizeDegrees

        return CLLocationCoordinate2D(latitude: roundedLat, longitude: roundedLng)
    }
}
```

#### 2. データ匿名化

- **個人識別子の除去**: 自動的な PII データの検出・マスキング
- **統計的開示制御**: k-匿名性の確保
- **差分プライバシー**: 統計データ提供時のプライバシー保護

### 災害時セキュリティ考慮

#### 1. 緊急時アクセス制御 (iOS)

```swift
enum DisasterLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

class EmergencySecurityService: ObservableObject {
    @Published var currentDisasterLevel: DisasterLevel = .low
    @Published var isEmergencyMode = false

    private let supabase = SupabaseClient(...)

    func activateEmergencyMode(disasterLevel: DisasterLevel) async {
        await MainActor.run {
            self.currentDisasterLevel = disasterLevel
            self.isEmergencyMode = true
        }

        switch disasterLevel {
        case .high:
            // 公式機関のみ投稿可能
            await restrictPostingToOfficial()
            // 位置情報プライバシー設定を緊急モードに変更
            await overrideLocationPrivacy()
        case .medium:
            // 検証済みユーザーのみ投稿可能
            await restrictPostingToVerified()
        case .low:
            // 通常の投稿制限
            await applyStandardRestrictions()
        }
    }

    private func restrictPostingToOfficial() async {
        // Supabase RLS policies を通じて制限実装
    }

    private func overrideLocationPrivacy() async {
        // 緊急時の位置情報共有設定
    }

    private func restrictPostingToVerified() async {
        // 検証済みユーザーのみの投稿制限
    }

    private func applyStandardRestrictions() async {
        // 通常の投稿制限
    }
}
```

#### 2. 情報信頼性確保

- **公式機関認証**: 政府・自治体・報道機関の特別認証
- **ファクトチェック連携**: 外部ファクトチェック機関との API 連携
- **コミュニティ検証**: ユーザーによる情報検証システム

---

## データ設計

### データベーススキーマ

#### 1. ユーザー関連テーブル

```sql
-- users テーブル
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(50) UNIQUE NOT NULL,
  display_name VARCHAR(100),
  bio TEXT,
  avatar_url VARCHAR(500),
  cover_url VARCHAR(500),
  location_precision location_precision_enum DEFAULT 'approximate',
  is_verified BOOLEAN DEFAULT FALSE,
  is_official BOOLEAN DEFAULT FALSE,
  role user_role_enum DEFAULT 'user',
  privacy_settings JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- user_follows テーブル（フォロー関係）
CREATE TABLE user_follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
  following_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(follower_id, following_id)
);
```

#### 2. 投稿関連テーブル

```sql
-- posts テーブル
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  url VARCHAR(2000),
  url_metadata JSONB,
  location GEOGRAPHY(POINT, 4326),
  location_encrypted TEXT,
  address JSONB,
  category post_category_enum NOT NULL,
  visibility post_visibility_enum DEFAULT 'public',
  is_emergency BOOLEAN DEFAULT FALSE,
  emergency_level emergency_level_enum,
  trust_score DECIMAL(3,2) DEFAULT 0.5,
  like_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  share_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 空間インデックス
CREATE INDEX idx_posts_location ON posts USING GIST (location);
CREATE INDEX idx_posts_category_created ON posts (category, created_at DESC);
CREATE INDEX idx_posts_emergency_created ON posts (is_emergency, created_at DESC) WHERE is_emergency = TRUE;

-- post_media テーブル（メディアファイル）
CREATE TABLE post_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  media_type media_type_enum NOT NULL,
  file_url VARCHAR(500) NOT NULL,
  thumbnail_url VARCHAR(500),
  file_size INTEGER,
  width INTEGER,
  height INTEGER,
  duration INTEGER, -- 動画の場合
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 3. ソーシャル機能テーブル

```sql
-- post_likes テーブル
CREATE TABLE post_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  reaction_type reaction_type_enum DEFAULT 'like',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- post_comments テーブル
CREATE TABLE post_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  parent_comment_id UUID REFERENCES post_comments(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  like_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- notifications テーブル
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  type notification_type_enum NOT NULL,
  title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  data JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  is_push_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 4. 緊急時・災害関連テーブル

```sql
-- emergency_events テーブル
CREATE TABLE emergency_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type emergency_event_type_enum NOT NULL,
  title VARCHAR(200) NOT NULL,
  description TEXT NOT NULL,
  severity emergency_severity_enum NOT NULL,
  affected_area GEOGRAPHY(POLYGON, 4326),
  status emergency_status_enum DEFAULT 'active',
  official_source VARCHAR(200),
  external_id VARCHAR(100),
  started_at TIMESTAMP WITH TIME ZONE NOT NULL,
  ended_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- shelters テーブル（避難所情報）
CREATE TABLE shelters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  address VARCHAR(500) NOT NULL,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  capacity INTEGER,
  current_occupancy INTEGER DEFAULT 0,
  facilities JSONB,
  contact_phone VARCHAR(20),
  status shelter_status_enum DEFAULT 'open',
  managed_by VARCHAR(200),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### データモデル設計

#### 1. Enum 型定義

```sql
-- ユーザー関連
CREATE TYPE user_role_enum AS ENUM ('user', 'moderator', 'admin');
CREATE TYPE location_precision_enum AS ENUM ('exact', 'approximate', 'area_only');

-- 投稿関連
CREATE TYPE post_category_enum AS ENUM (
  'news', 'traffic', 'weather', 'crime', 'emergency',
  'community', 'business', 'sports', 'entertainment', 'other'
);
CREATE TYPE post_visibility_enum AS ENUM ('public', 'followers', 'area', 'private');
CREATE TYPE media_type_enum AS ENUM ('image', 'video', 'audio', 'document');
CREATE TYPE reaction_type_enum AS ENUM ('like', 'love', 'laugh', 'angry', 'sad');

-- 緊急時関連
CREATE TYPE emergency_event_type_enum AS ENUM (
  'earthquake', 'tsunami', 'flood', 'fire', 'typhoon',
  'landslide', 'volcanic', 'accident', 'security', 'other'
);
CREATE TYPE emergency_severity_enum AS ENUM ('info', 'warning', 'critical');
CREATE TYPE emergency_level_enum AS ENUM ('low', 'medium', 'high');
CREATE TYPE emergency_status_enum AS ENUM ('active', 'resolved', 'monitoring');
CREATE TYPE shelter_status_enum AS ENUM ('open', 'full', 'closed', 'unknown');

-- 通知関連
CREATE TYPE notification_type_enum AS ENUM (
  'post_like', 'post_comment', 'follow', 'mention',
  'emergency_alert', 'system_notice'
);
```

#### 2. JSONB データ構造例

```typescript
// privacy_settings の構造
interface PrivacySettings {
  locationSharing: boolean;
  locationPrecision: 'exact' | 'approximate' | 'area_only';
  profileVisibility: 'public' | 'followers' | 'private';
  emergencyOverride: boolean;
  dataRetention: {
    deleteAfterDays?: number;
    autoArchive: boolean;
  };
}

// url_metadata の構造
interface URLMetadata {
  title?: string;
  description?: string;
  image?: string;
  siteName?: string;
  publishedAt?: string;
  author?: string;
  extractedLocation?: {
    coordinates?: [number, number];
    address?: string;
    confidence: number;
  };
}

// address の構造
interface AddressComponents {
  country: string;
  countryCode: string;
  prefecture: string;
  prefectureCode: string;
  city: string;
  ward?: string;
  district?: string;
  street?: string;
  building?: string;
  postalCode?: string;
}

// shelter facilities の構造
interface ShelterFacilities {
  hasWater: boolean;
  hasElectricity: boolean;
  hasInternet: boolean;
  hasFood: boolean;
  hasMedical: boolean;
  hasPets: boolean;
  wheelchairAccessible: boolean;
  languages: string[];
}
```

### 位置情報データ構造

#### 1. PostGIS 空間データ型

```sql
-- 地理座標系（WGS84）を使用
-- GEOGRAPHY 型は地球の曲率を考慮した計算が可能

-- ポイント（投稿位置）
ALTER TABLE posts ADD COLUMN location GEOGRAPHY(POINT, 4326);

-- ポリゴン（災害影響エリア）
ALTER TABLE emergency_events ADD COLUMN affected_area GEOGRAPHY(POLYGON, 4326);

-- 空間インデックスの作成
CREATE INDEX idx_posts_location_gist ON posts USING GIST (location);
CREATE INDEX idx_emergency_area_gist ON emergency_events USING GIST (affected_area);
```

#### 2. 空間クエリの例

```sql
-- 指定範囲内の投稿を取得
SELECT p.*, u.username
FROM posts p
JOIN users u ON p.user_id = u.id
WHERE ST_DWithin(
  p.location,
  ST_Point(139.6917, 35.6895)::geography, -- 東京駅の座標
  1000 -- 1km 以内
)
ORDER BY p.created_at DESC;

-- 災害影響エリア内の投稿を取得
SELECT p.*
FROM posts p, emergency_events e
WHERE ST_Within(p.location, e.affected_area)
  AND e.status = 'active'
  AND e.severity IN ('warning', 'critical');
```

#### 3. パフォーマンス最適化

```sql
-- パーティション分割（月別）
CREATE TABLE posts_2025_01 PARTITION OF posts
FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

-- 部分インデックス（緊急投稿のみ）
CREATE INDEX idx_posts_emergency_location
ON posts USING GIST (location)
WHERE is_emergency = TRUE;

-- 複合インデックス
CREATE INDEX idx_posts_category_location_created
ON posts (category, created_at DESC)
INCLUDE (location)
WHERE visibility = 'public';
```

---

**文書バージョン**: 1.0  
**最終更新日**: 2025-10-09  
**承認ステータス**: 承認待ち
