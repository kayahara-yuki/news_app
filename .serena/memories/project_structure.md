# プロジェクト構造

## ディレクトリ構造

```
news_sns/
├── ios-app/                          # iOS アプリ
│   ├── LocationNewsSNS.xcodeproj/    # Xcode プロジェクト
│   ├── LocationNewsSNS/              # アプリソースコード
│   │   ├── Configuration/            # 設定・依存性注入
│   │   ├── Models/                   # データモデル
│   │   ├── Services/                 # ビジネスロジック・サービス層
│   │   ├── Repositories/             # データアクセス層
│   │   ├── UseCases/                 # ユースケース（ビジネスロジック）
│   │   ├── Views/                    # SwiftUI ビュー
│   │   │   ├── Maps/                 # 地図関連ビュー
│   │   │   ├── Posts/                # 投稿関連ビュー
│   │   │   └── Social/               # SNS機能関連ビュー
│   │   ├── Storage/                  # ローカルストレージ
│   │   ├── Resources/                # アセット・設定ファイル
│   │   └── Preview Content/          # プレビュー用コンテンツ
│   └── build/                        # ビルド成果物
├── .kiro/specs/                      # Kiro 仕様書
│   └── location-news-sns/
│       ├── spec.md                   # プロジェクト仕様
│       ├── requirements.md           # 要件定義
│       ├── design.md                 # 設計書
│       └── tasks.md                  # タスク分解
├── .claude/                          # Claude設定
├── .serena/                          # Serenaメモリ
├── supabase/                         # Supabaseスクリプト
│   ├── seed.sql                      # 初期データ
│   ├── setup_rls_policies.sql        # RLSポリシー設定
│   └── create_nearby_posts_function.sql # 関数定義
├── docs/                             # ドキュメント
│   └── architecture.md               # アーキテクチャ説明
├── .github/workflows/                # CI/CD パイプライン
├── README.md                         # プロジェクト説明
├── CLAUDE.md                         # AI運用ルール
├── .swiftlint.yml                    # SwiftLint設定
└── .gitignore                        # Git除外設定
```

## 主要ファイル
- **LocationNewsSNSApp.swift**: アプリのエントリーポイント
- **ContentView.swift**: メインビュー
- **AppConfiguration.swift**: アプリ設定管理
- **SupabaseConfig.swift**: Supabase接続設定

## Clean Architecture層構造
1. **Presentation層** (Views/): SwiftUIビュー、ViewModel
2. **Domain層** (UseCases/, Models/): ビジネスロジック、エンティティ
3. **Data層** (Repositories/, Services/): データアクセス、外部サービス連携
4. **Infrastructure層** (Configuration/, Storage/): 設定、ローカルストレージ