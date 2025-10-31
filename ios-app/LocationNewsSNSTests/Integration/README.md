# Integration Tests

## 概要

このディレクトリには、複数のコンポーネントを組み合わせた統合テストが含まれています。

## AudioRecorderPlayerIntegrationTests

### 目的

AudioRecorderとAudioPlayerの統合動作を検証します。

### テストケース

1. **録音→再生の完全フロー**: 録音開始→停止→再生→停止の一連の流れが正常に動作することを確認
2. **複数回の録音と再生**: 複数回の録音サイクルが正常に動作し、古いファイルが適切に削除されることを確認
3. **録音中の再生試行**: 録音中に再生を試みるとエラーが発生することを確認
4. **再生中の録音開始**: 再生中に新しい録音を開始すると再生が停止されることを確認
5. **AudioPlayerViewとの統合**: AudioPlayerViewが録音したファイルを正常に再生できることを確認
6. **ファイルの削除**: 録音削除後にファイルが適切に削除されることを確認
7. **最大録音時間の自動停止**: 最大録音時間(30秒)が正しく設定されていることを確認
8. **シーク機能のテスト**: 再生中のシーク機能が正常に動作することを確認
9. **排他制御のテスト**: 複数のAudioServiceインスタンスで排他制御が動作することを確認
10. **エラーリカバリー**: エラー発生後のリカバリーが正常に動作することを確認

### 実行方法

#### Xcodeから実行

1. Xcodeでプロジェクトを開く
2. テストナビゲーター (⌘5) を開く
3. `AudioRecorderPlayerIntegrationTests` を選択
4. テストを実行 (⌘U)

#### コマンドラインから実行

```bash
xcodebuild test \
  -project LocationNewsSNS.xcodeproj \
  -scheme LocationNewsSNS \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:LocationNewsSNSTests/AudioRecorderPlayerIntegrationTests
```

### 注意事項

- **マイクアクセス許可**: 一部のテストはマイクアクセス許可が必要です。シミュレーターでマイクアクセスが拒否されている場合、該当テストはスキップされます。
- **実行時間**: 統合テストは録音・再生の待機時間があるため、通常のユニットテストより実行時間が長くなります(約30-60秒)。
- **排他制御**: テストは`@MainActor`で実行されるため、順次実行されます。

### テスト戦略

これらの統合テストは、以下のTDD原則に従って作成されています:

1. **RED**: 失敗するテストを先に書く
2. **GREEN**: テストを通過させる最小限の実装
3. **REFACTOR**: コードのクリーンアップと改善

### カバレッジ

このテストスイートは、以下のRequirementsをカバーしています:

- Requirement 1: 音声メッセージの録音とアップロード
- Requirement 2: 音声録音UIの統合
- Requirement 3: 音声ファイルの録音品質と再生

### 関連ファイル

- `AudioService.swift`: 音声録音・再生・アップロードサービス
- `AudioRecorderViewModel.swift`: 音声録音のViewModel
- `AudioPlayerView.swift`: 音声再生UI
- `AudioRecorderView.swift`: 音声録音UI
