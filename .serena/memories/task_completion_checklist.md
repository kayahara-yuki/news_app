# タスク完了時のチェックリスト

## 必須確認事項

### 1. コード品質
```bash
# SwiftLint実行（必須）
swiftlint --config .swiftlint.yml

# SwiftLintエラーがある場合は修正
swiftlint --config .swiftlint.yml --fix
```

### 2. ビルド確認
```bash
# ビルドが通ることを確認
xcodebuild -project ios-app/LocationNewsSNS.xcodeproj -scheme LocationNewsSNS build
```

### 3. テスト実行（テストが存在する場合）
```bash
# ユニットテスト実行
xcodebuild test -project ios-app/LocationNewsSNS.xcodeproj -scheme LocationNewsSNS -destination 'platform=iOS Simulator,name=iPhone 15'
```

### 4. 実行時確認
- Xcodeでアプリを実行し、実装した機能が正常に動作することを確認
- エラーやクラッシュが発生しないことを確認
- UIの表示崩れがないことを確認

### 5. コミット前チェック
- [ ] SwiftLintエラーなし
- [ ] ビルドエラーなし
- [ ] 実行時エラーなし
- [ ] 不要なデバッグコードの削除
- [ ] TODO/FIXMEコメントの形式確認（例: `// TODO: 説明`）
- [ ] ハードコードされたURLがないこと

## 推奨事項

### コードレビュー観点
- MVVM パターンに従っているか
- 適切な責務分離ができているか
- SwiftUIのベストプラクティスに従っているか
- 再利用可能なコンポーネント設計か

### パフォーマンス
- 不要な再レンダリングを避けているか
- 大量データの場合の考慮があるか
- メモリリークの可能性はないか

### セキュリティ
- 個人情報の適切な取り扱い
- 位置情報のプライバシー設定
- APIキーやシークレットの管理

## トラブルシューティング
- ビルドエラー: Clean Build Folder (Cmd+Shift+K) を試す
- SwiftLintエラー: `.swiftlint.yml` の設定を確認
- 実行時エラー: Xcodeのデバッグコンソールで詳細を確認