# 開発で使用するコマンド

## ビルド・実行
```bash
# Xcodeプロジェクトを開く
open ios-app/LocationNewsSNS.xcodeproj

# コマンドラインビルド
xcodebuild -project ios-app/LocationNewsSNS.xcodeproj -scheme LocationNewsSNS build

# シミュレータでビルド&実行
xcodebuild -project ios-app/LocationNewsSNS.xcodeproj -scheme LocationNewsSNS -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## テスト実行
```bash
# ユニットテスト実行
xcodebuild test -project ios-app/LocationNewsSNS.xcodeproj -scheme LocationNewsSNS -destination 'platform=iOS Simulator,name=iPhone 15'
```

## コード品質チェック
```bash
# SwiftLint実行（プロジェクトルートから）
swiftlint --config .swiftlint.yml

# SwiftLint自動修正
swiftlint --config .swiftlint.yml --fix
```

## Git操作
```bash
# ステータス確認
git status

# 差分確認
git diff

# コミット履歴
git log --oneline -10

# ブランチ作成
git checkout -b feature/機能名
git checkout -b bugfix/バグ名
```

## Supabase関連
```bash
# Supabaseデータベース設定（手動でSupabaseダッシュボードから実行）
# SQLファイルは supabase/ ディレクトリに格納
```

## システムコマンド (macOS)
```bash
# ファイル検索
find . -name "*.swift" -type f

# 内容検索（ripgrep推奨）
rg "検索文字列" --type swift

# ディレクトリ構造表示
ls -la
tree -I 'build|.git' # treeコマンドがある場合

# プロセス確認
ps aux | grep Xcode
```

## 注意事項
- Fastlaneは未設定のため、デプロイは手動で行う
- テスト実行前にシミュレータが起動していることを確認
- SwiftLintエラーがある場合はコミット前に修正する