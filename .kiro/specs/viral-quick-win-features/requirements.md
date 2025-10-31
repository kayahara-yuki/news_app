# Requirements Document

## Project Description (Input)

プロジェクト名: バイラル化クイックウィン機能（音声投稿＋ワンタップステータス共有）

### 概要
既存の地図ベースSNSアプリに、投稿ハードルを劇的に下げる2つの機能を追加する。

### 主要機能

#### 1. 音声メッセージ投稿機能
- 音声ファイルの録音とアップロード
- 音声録音ボタンをFABに追加
- 最長30秒の音声録音
- Supabase Storageへのアップロード
- 位置情報自動付与
- 投稿詳細での音声再生機能

#### 2. ワンタップステータス共有
- プリセットステータスボタン（「カフェなう」「ランチ中」「暇してる」等）
- ワンタップで現在地+ステータスを自動投稿
- 3時間後に自動削除（プライバシー保護）
- 地図上にアイコン表示（コーヒーカップ、フォーク等）

### 技術スタック
- iOS 18+ SwiftUI
- AVFoundation（音声録音）
- Supabase Storage（音声ファイル保存）
- MapKit（地図表示）
- Supabase（バックエンド）

### 目標
- 投稿ハードル80%削減
- 投稿数3倍増加
- 新規ユーザーの初回投稿率50%向上

---

## Introduction

本要件定義書は、既存の地図ベースSNSアプリケーション「LocationNewsSNS」に追加する2つの新機能について定義する。これらの機能は、ユーザーの投稿ハードルを大幅に削減し、アプリのバイラル性を高めることを目的とする。

**ビジネス価値:**
- 投稿作成時間を平均30秒から5秒に短縮
- 新規ユーザーの初回投稿完了率を50%向上
- デイリーアクティブユーザー（DAU）を3倍に増加
- ユーザーエンゲージメント指標の向上
- 音声メッセージによるリッチなコンテンツ共有

---

## Requirements

### Requirement 1: 音声メッセージの録音とアップロード

**Objective:** アプリユーザーとして、テキスト入力の代わりに音声メッセージで投稿を作成したい。なぜなら、キーボード入力よりも高速で、移動中や片手操作時でも投稿できるようにするため。

#### Acceptance Criteria

1. WHEN ユーザーが投稿作成画面で音声録音ボタンをタップ THEN LocationNewsSNSアプリ SHALL マイクアクセス許可を要求する

2. IF マイクアクセスが許可されている THEN LocationNewsSNSアプリ SHALL 音声録音を開始し、視覚的なフィードバック（波形アニメーション）を表示する

3. WHILE ユーザーが音声録音中 THE LocationNewsSNSアプリ SHALL 録音経過時間（秒）をリアルタイム表示する

4. WHEN ユーザーが30秒間音声録音を続けた THEN LocationNewsSNSアプリ SHALL 自動的に録音を停止し、音声ファイルを保存する

5. WHEN ユーザーが音声録音停止ボタンをタップ THEN LocationNewsSNSアプリ SHALL 録音を停止し、音声ファイル（.m4a形式）をローカルに一時保存する

6. WHEN 音声録音が完了した THEN LocationNewsSNSアプリ SHALL 音声ファイルをSupabase Storageにアップロードする

7. WHEN 音声ファイルのアップロードが成功した THEN LocationNewsSNSアプリ SHALL アップロードされたファイルのURLを投稿データに添付する

8. IF 音声録音が失敗した（マイクエラー） THEN LocationNewsSNSアプリ SHALL エラーメッセージ「音声を録音できませんでした。もう一度お試しください」を表示する

9. IF 音声ファイルのアップロードが失敗した（ネットワークエラー） THEN LocationNewsSNSアプリ SHALL エラーメッセージ「音声のアップロードに失敗しました。もう一度お試しください」を表示し、ローカルファイルを保持する

### Requirement 2: 音声録音UIの統合

**Objective:** アプリユーザーとして、既存の投稿作成フローに自然に統合された音声録音機能を使いたい。なぜなら、新しい機能を学習するコストを最小限にし、直感的に使えるようにするため。

#### Acceptance Criteria

1. WHEN ユーザーが地図画面のFAB（Floating Action Button）を長押し THEN LocationNewsSNSアプリ SHALL 音声録音モードを即座に起動する

2. WHERE 投稿作成画面のテキストフィールド下部 THE LocationNewsSNSアプリ SHALL マイクアイコンボタンを表示する

3. WHEN ユーザーが音声録音ボタンをタップ THEN LocationNewsSNSアプリ SHALL 録音UI（波形アニメーション + カウントダウンタイマー + 停止ボタン）を表示する

4. WHILE 音声録音が進行中 THE LocationNewsSNSアプリ SHALL 残り時間（秒）をカウントダウン表示する

5. WHEN 音声録音が完了した THEN LocationNewsSNSアプリ SHALL 音声プレイヤーUI（再生ボタン + 波形 + 長さ表示）を表示する

6. WHEN ユーザーが録音済み音声の再生ボタンをタップ THEN LocationNewsSNSアプリ SHALL 録音された音声を再生する

7. IF ユーザーがキャンセルボタンをタップ THEN LocationNewsSNSアプリ SHALL 音声録音を中断し、ローカルファイルを削除する

8. WHEN ユーザーが「投稿」ボタンをタップした AND 音声ファイルが添付されている THEN LocationNewsSNSアプリ SHALL 音声ファイルURLを含む投稿をSupabaseに送信する

### Requirement 3: 音声ファイルの録音品質と再生

**Objective:** アプリユーザーとして、高品質な音声を録音・再生したい。なぜなら、音質が悪いと内容が聞き取りづらく、音声投稿の価値が下がるため。

#### Acceptance Criteria

1. WHEN ユーザーが音声録音を開始 THEN LocationNewsSNSアプリ SHALL AVFoundationを使用してAAC形式（.m4a）で録音する

2. WHEN 音声ファイルを録音 THEN LocationNewsSNSアプリ SHALL サンプルレート44.1kHz、ビットレート128kbpsで録音する

3. WHEN 音声ファイルがSupabase Storageにアップロード THEN LocationNewsSNSアプリ SHALL ファイルパス「audio/{user_id}/{timestamp}.m4a」に保存する

4. WHERE 投稿詳細画面 THE LocationNewsSNSアプリ SHALL 音声プレイヤー（再生/一時停止ボタン + シークバー + 再生時間表示）を表示する

5. WHEN ユーザーが投稿詳細で音声再生ボタンをタップ THEN LocationNewsSNSアプリ SHALL Supabase Storageから音声ファイルをストリーミング再生する

6. WHILE 音声が再生中 THE LocationNewsSNSアプリ SHALL 再生進捗をシークバーで表示する

7. WHEN ユーザーがシークバーをドラッグ THEN LocationNewsSNSアプリ SHALL 指定された位置から再生を再開する

8. IF 音声ファイルのダウンロードが失敗した THEN LocationNewsSNSアプリ SHALL エラーメッセージ「音声を読み込めませんでした」を表示する

### Requirement 4: プリセットステータスボタンの表示

**Objective:** アプリユーザーとして、ワンタップで現在の状況を共有したい。なぜなら、テキスト入力なしで素早く投稿し、友達に今の状態を伝えたいため。

#### Acceptance Criteria

1. WHERE 投稿作成画面の上部 THE LocationNewsSNSアプリ SHALL プリセットステータスボタン一覧を横スクロール可能なレイアウトで表示する

2. WHEN 投稿作成画面を開いた THEN LocationNewsSNSアプリ SHALL 以下のプリセットステータスを表示する：
   - 「☕ カフェなう」
   - 「🍴 ランチ中」
   - 「🚶 散歩中」
   - 「📚 勉強中」
   - 「😴 暇してる」
   - 「🎉 イベント参加中」
   - 「🏃 移動中」
   - 「🎬 映画鑑賞中」

3. WHEN ユーザーがプリセットステータスボタンをタップ THEN LocationNewsSNSアプリ SHALL 選択されたステータスをハイライト表示する

4. IF 複数のステータスボタンが選択された THEN LocationNewsSNSアプリ SHALL 最後に選択されたステータスのみをアクティブ状態にする

5. WHEN プリセットステータスが選択された THEN LocationNewsSNSアプリ SHALL 投稿テキストフィールドに選択されたステータステキストを自動入力する

### Requirement 5: ワンタップ投稿の実行

**Objective:** アプリユーザーとして、ステータスボタンをタップするだけで投稿を完了したい。なぜなら、投稿確認画面や追加入力なしで、最速で共有したいため。

#### Acceptance Criteria

1. WHEN ユーザーがプリセットステータスボタンをタップ THEN LocationNewsSNSアプリ SHALL 以下の情報を自動的に設定する：
   - 投稿内容: 選択されたステータステキスト
   - 位置情報: 現在地の緯度経度
   - 住所: 逆ジオコーディング結果
   - 投稿時刻: 現在時刻

2. WHEN ステータス投稿が作成された AND 位置情報が取得済み THEN LocationNewsSNSアプリ SHALL 確認画面なしで即座にSupabaseに投稿データを送信する

3. WHEN 投稿送信が成功した THEN LocationNewsSNSアプリ SHALL 「投稿しました」のトーストメッセージを0.5秒間表示する

4. WHEN 投稿送信が成功した THEN LocationNewsSNSアプリ SHALL 投稿作成画面を自動的に閉じ、地図画面に戻る

5. IF 位置情報が取得できていない THEN LocationNewsSNSアプリ SHALL エラーメッセージ「位置情報を取得できません。位置情報サービスを有効にしてください」を表示する

6. IF 投稿送信が失敗した（ネットワークエラー） THEN LocationNewsSNSアプリ SHALL エラーメッセージ「投稿に失敗しました。もう一度お試しください」を表示し、投稿内容を保持する

7. WHEN ユーザーが「投稿」ボタンをタップせずにキャンセルした THEN LocationNewsSNSアプリ SHALL 下書きを破棄し、確認なしで画面を閉じる

### Requirement 6: ステータス投稿の自動削除

**Objective:** アプリユーザーとして、ステータス投稿が一定時間後に自動削除されることを期待する。なぜなら、古い位置情報が残り続けるとプライバシーリスクになるため。

#### Acceptance Criteria

1. WHEN ステータス投稿（ワンタップ投稿）が作成された THEN LocationNewsSNSアプリ SHALL 投稿メタデータに「自動削除フラグ」と「削除予定時刻（投稿時刻+3時間）」を設定する

2. WHEN 投稿作成から3時間が経過した THEN Supabaseバックエンド SHALL 該当する投稿を自動的にデータベースから削除する

3. WHERE 地図画面の投稿一覧 THE LocationNewsSNSアプリ SHALL 残り時間（例: 「あと2時間で削除」）を投稿カードに表示する

4. WHEN 削除予定時刻の1時間前になった THEN LocationNewsSNSアプリ SHALL 投稿カードに「まもなく削除されます」のバッジを表示する

5. IF ユーザーが手動でステータス投稿を削除した THEN LocationNewsSNSアプリ SHALL 自動削除スケジュールをキャンセルし、即座に削除する

6. WHEN 自動削除が実行された THEN Supabaseバックエンド SHALL 関連するいいね・コメントも同時に削除する

### Requirement 7: 地図上のステータス投稿表示

**Objective:** アプリユーザーとして、地図上でステータス投稿を視覚的に区別したい。なぜなら、通常の投稿とステータス投稿を一目で見分けたいため。

#### Acceptance Criteria

1. WHEN 地図画面にステータス投稿が表示される THEN LocationNewsSNSアプリ SHALL 専用アイコン（絵文字ベース）をピンとして表示する

2. WHERE 地図上のステータス投稿ピン THE LocationNewsSNSアプリ SHALL 以下のマッピングでアイコンを表示する：
   - 「カフェなう」→ ☕
   - 「ランチ中」→ 🍴
   - 「散歩中」→ 🚶
   - 「勉強中」→ 📚
   - 「暇してる」→ 😴
   - 「イベント参加中」→ 🎉
   - 「移動中」→ 🏃
   - 「映画鑑賞中」→ 🎬

3. WHEN ユーザーがステータス投稿ピンをタップ THEN LocationNewsSNSアプリ SHALL 簡易カード（ユーザー名 + ステータス + 残り時間）を表示する

4. WHEN ステータス投稿の残り時間が1時間未満 THEN LocationNewsSNSアプリ SHALL ピンの透明度を50%に下げる

5. IF ステータス投稿が削除された THEN LocationNewsSNSアプリ SHALL 即座に地図からピンを削除する

### Requirement 8: 音声投稿とステータス投稿の統合

**Objective:** アプリユーザーとして、音声メッセージとステータス共有を組み合わせて使いたい。なぜなら、「カフェなう + 音声メッセージ」のような投稿をしたいため。

#### Acceptance Criteria

1. WHEN ユーザーがプリセットステータスを選択した AND その後音声録音ボタンをタップ THEN LocationNewsSNSアプリ SHALL ステータステキストと音声ファイルの両方を投稿に添付する

2. WHEN ユーザーが音声録音後にプリセットステータスを選択 THEN LocationNewsSNSアプリ SHALL 音声ファイルを保持し、ステータステキストを追加する

3. WHEN 音声ファイルとステータスが両方設定された THEN LocationNewsSNSアプリ SHALL 投稿データに以下を含める：
   - content: ステータステキスト
   - audio_url: 音声ファイルURL

4. WHERE 投稿カード（地図・フィード画面） THE LocationNewsSNSアプリ SHALL ステータステキストと音声プレイヤーの両方を表示する

5. IF ユーザーがテキスト編集でステータス以外の内容を追加した THEN LocationNewsSNSアプリ SHALL 通常投稿として扱う（自動削除なし）

### Requirement 9: パフォーマンスと応答性

**Objective:** アプリユーザーとして、音声録音とステータス投稿がスムーズに動作することを期待する。なぜなら、遅延やラグがあると使いづらくなるため。

#### Acceptance Criteria

1. WHEN ユーザーが音声録音ボタンをタップ THEN LocationNewsSNSアプリ SHALL 0.5秒以内に録音を開始する

2. WHEN 音声ファイルのアップロードが開始された THEN LocationNewsSNSアプリ SHALL アップロード進捗（%）をリアルタイム表示する

3. WHEN ユーザーがプリセットステータスボタンをタップ THEN LocationNewsSNSアプリ SHALL 0.3秒以内に投稿を送信開始する

4. WHEN 投稿送信が開始された THEN LocationNewsSNSアプリ SHALL ローディングインジケーターを表示し、ユーザーに進行状況を伝える

5. IF 音声ファイルのアップロードに10秒以上かかる THEN LocationNewsSNSアプリ SHALL タイムアウトエラーを表示し、リトライオプションを提供する

6. WHEN 音声ファイルサイズが2MB以上 THEN LocationNewsSNSアプリ SHALL 警告「ファイルサイズが大きいため、アップロードに時間がかかる場合があります」を表示する

### Requirement 10: プライバシーとセキュリティ

**Objective:** アプリユーザーとして、音声データと位置情報が適切に保護されることを期待する。なぜなら、プライバシーが侵害されないことが重要だから。

#### Acceptance Criteria

1. WHEN アプリが音声録音機能を使用する THEN LocationNewsSNSアプリ SHALL 初回使用時にマイクアクセス許可のダイアログを表示する

2. WHEN 音声ファイルがSupabase Storageにアップロード THEN LocationNewsSNSアプリ SHALL HTTPSで暗号化転送する

3. WHEN 投稿が削除された THEN Supabaseバックエンド SHALL 関連する音声ファイルもStorageから完全に削除する

4. WHERE 位置情報設定画面 THE LocationNewsSNSアプリ SHALL ステータス投稿の自動削除機能について説明テキストを表示する

5. IF ユーザーが位置情報アクセスを拒否している THEN LocationNewsSNSアプリ SHALL ステータス投稿ボタンを非アクティブ化し、設定画面へのリンクを表示する

6. WHEN ステータス投稿が自動削除された THEN Supabaseバックエンド SHALL 関連する位置情報と音声ファイルも完全に削除し、バックアップにも残さない

### Requirement 11: エラーハンドリングとフォールバック

**Objective:** アプリユーザーとして、エラー発生時にも適切なフィードバックを得たい。なぜなら、何が問題なのかを理解し、対処方法を知りたいため。

#### Acceptance Criteria

1. IF AVFoundationが利用できない（古いiOSバージョン） THEN LocationNewsSNSアプリ SHALL 音声録音ボタンを非表示にする

2. IF マイクアクセスが拒否されている THEN LocationNewsSNSアプリ SHALL 「マイクアクセスが必要です」のアラートと設定画面へのリンクを表示する

3. WHEN 音声録音中にアプリがバックグラウンドに移行 THEN LocationNewsSNSアプリ SHALL 録音を一時停止し、フォアグラウンド復帰時に再開オプションを表示する

4. IF ネットワークエラーで投稿送信が失敗した THEN LocationNewsSNSアプリ SHALL ローカルストレージに下書き保存し、「後で送信」オプションを提供する

5. WHEN ユーザーが再試行ボタンをタップ THEN LocationNewsSNSアプリ SHALL 下書きから投稿内容と音声ファイルを復元し、再送信を試みる

6. IF Supabase Storageの容量制限に達した THEN LocationNewsSNSアプリ SHALL エラーメッセージ「ストレージ容量が不足しています。古い投稿を削除してください」を表示する

### Requirement 12: アクセシビリティ対応

**Objective:** 視覚障害や聴覚障害のあるユーザーとして、音声録音機能を支援技術と併用したい。なぜなら、すべてのユーザーが平等に機能を使えるべきだから。

#### Acceptance Criteria

1. WHERE 音声録音ボタン THE LocationNewsSNSアプリ SHALL VoiceOverアクセシビリティラベル「音声メッセージを録音」を設定する

2. WHEN VoiceOverが有効な状態で音声録音が開始された THEN LocationNewsSNSアプリ SHALL 「録音開始」の音声フィードバックを提供する

3. WHERE プリセットステータスボタン THE LocationNewsSNSアプリ SHALL 各ボタンにアクセシビリティラベルを設定する（例: 「カフェなう ステータスボタン」）

4. WHEN ユーザーがDynamic Typeで大きいフォントサイズを設定 THEN LocationNewsSNSアプリ SHALL 音声録音UIとステータスボタンのテキストサイズを自動調整する

5. IF ユーザーがVoiceOverを使用している THEN LocationNewsSNSアプリ SHALL 音声録音の進行状況を音声で通知する（例: 「15秒経過」）

6. WHERE 音声プレイヤー THE LocationNewsSNSアプリ SHALL 再生/一時停止ボタンにアクセシビリティヒント「ダブルタップで再生」を設定する

---

## Non-Functional Requirements

### Performance
- 音声録音の開始時間: 0.5秒以内
- 音声ファイルアップロード: 1MB/秒以上（通常ネットワーク）
- ステータス投稿の送信時間: 1秒以内（通常ネットワーク）
- UIアニメーションフレームレート: 60fps維持

### Scalability
- 同時音声録音セッション: 端末あたり1セッション
- ステータス投稿の同時送信: サーバーサイドで毎秒100リクエストまで対応
- Supabase Storage容量: ユーザーあたり100MB上限

### Compatibility
- iOS 18.0以上
- AVFoundation対応デバイス
- 既存のLocationNewsSNSアプリとの完全互換性
- 音声形式: AAC (.m4a)

### Security
- 音声ファイルの暗号化転送（HTTPS）
- 位置情報の匿名化オプション
- 自動削除機能による個人情報保護
- Supabase Storage RLSポリシーによるアクセス制御

### Usability
- 音声録音の成功率: 95%以上（標準的な音響環境）
- ステータス投稿の完了率: 95%以上
- 新規ユーザーの機能理解度: チュートリアルなしで80%以上
- 音声再生の成功率: 98%以上
