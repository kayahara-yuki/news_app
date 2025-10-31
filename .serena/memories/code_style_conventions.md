# コードスタイルと規約

## SwiftLint設定
プロジェクトルートに `.swiftlint.yml` で詳細設定あり

## 主要な規約

### 命名規則
- 変数名・関数名: キャメルケース（例: `userName`, `getUserProfile`）
- 型名・プロトコル名: パスカルケース（例: `UserProfile`, `PostRepositoryProtocol`）
- 定数: 小文字キャメルケース
- 短縮名OK: `id`, `URL`, `lat`, `lng`, `GPS`

### ファイルヘッダー
すべてのSwiftファイルに以下の形式のヘッダーが必要：
```swift
//
//  FileName.swift
//  LocationNewsSNS
//
//  Created by 開発者名 on MM/DD/YY.
//
```

### コード構造
- 1行の長さ: 警告120文字、エラー150文字
- 関数の長さ: 警告50行、エラー100行
- ファイルの長さ: 警告500行、エラー1000行
- ネストレベル: 警告2、エラー3

### 禁止事項
- SupabaseClientの直接使用（`SupabaseClient.shared`を使用）
- URLのハードコーディング（設定ファイルを使用）
- TODO/FIXMEコメントは「:」付きで記述（例: `// TODO: 説明`）

### SwiftUI特有の規約
- @Published を活用した状態管理
- View と ViewModel の適切な分離
- 宣言的UIの原則に従う
- 小さなコンポーネントに分割

### アーキテクチャ規約
- MVVM パターンの遵守
- UseCase 層でのビジネスロジック実装
- Repository パターンでのデータアクセス抽象化
- 依存性注入の活用

## インポート順序
SwiftLintの `sorted_imports` ルールにより自動整列