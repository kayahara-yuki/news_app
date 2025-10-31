# Supabase Storage セットアップガイド: Audioバケット

## 概要

このガイドでは、音声メッセージ投稿機能のためのSupabase Storageバケット設定を行います。

### 設定内容

- **バケット名**: `audio`
- **公開設定**: 非公開（認証必須でアップロード/削除、公開読み取り可能）
- **ファイルサイズ制限**: 5MB
- **許可するMIMEタイプ**: audio/mpeg, audio/mp4, audio/x-m4a, audio/aac

---

## セットアップ手順

### Step 1: Audioバケットの作成

#### Option A: Supabase Dashboard（推奨）

1. Supabaseダッシュボードにログイン
2. `Storage`メニューをクリック
3. `Create a new bucket`ボタンをクリック
4. 以下の設定を入力：
   - **Name**: `audio`
   - **Public bucket**: ❌ オフ（チェックしない）
   - **File size limit**: `5 MB`
   - **Allowed MIME types**: `audio/mpeg, audio/mp4, audio/x-m4a, audio/aac`（オプション）
5. `Create bucket`ボタンをクリック

#### Option B: Supabase CLI

```bash
# Audioバケットを作成（非公開）
supabase storage create audio --public false
```

### Step 2: RLSポリシーの設定

#### Option A: SQLスクリプトで一括設定（推奨）

```bash
# SQLスクリプトを実行
supabase db execute -f supabase/storage_setup_audio_bucket.sql
```

または、Supabase Dashboard > SQL Editorから`storage_setup_audio_bucket.sql`の内容を実行。

#### Option B: Dashboard UI から手動設定

1. Supabaseダッシュボード > `Storage` > `audio`バケットを選択
2. `Policies`タブをクリック
3. 以下の3つのポリシーを作成：

##### ポリシー1: アップロード許可（自分のフォルダのみ）

- **Policy name**: `Users can upload to their own folder`
- **Allowed operation**: `INSERT`
- **Policy definition**:
  ```sql
  auth.uid()::text = (storage.foldername(name))[1]
  ```
- **Check expression**:
  ```sql
  auth.uid()::text = (storage.foldername(name))[1]
  ```

##### ポリシー2: 削除許可（自分のファイルのみ）

- **Policy name**: `Users can delete their own files`
- **Allowed operation**: `DELETE`
- **Policy definition**:
  ```sql
  auth.uid()::text = (storage.foldername(name))[1]
  ```

##### ポリシー3: 読み取り許可（全員）

- **Policy name**: `Anyone can read audio files`
- **Allowed operation**: `SELECT`
- **Policy definition**:
  ```sql
  true
  ```

### Step 3: CORS設定

Supabase Storageは自動的にCORSを設定しますが、iOSアプリからのアクセスを確実にするため、以下を確認してください。

#### Supabase Dashboard > Project Settings > API

以下の設定が有効になっているか確認：

- **Allow requests from any origin**: ✅ オン（開発環境のみ）
- **本番環境では特定のドメインを設定**: iOSアプリの場合は不要

---

## 検証手順

### Step 4: バケットとポリシーの検証

```bash
# SQLスクリプトで検証
supabase db execute -f supabase/storage_setup_audio_bucket.sql
```

期待される出力：

```
NOTICE:  Bucket "audio" exists
NOTICE:  RLS policies configured: 3 policies found
NOTICE:  Test 1 PASS: Upload policy logic verified
NOTICE:  Test 2 PASS: Upload restriction verified
```

### Step 5: 手動テスト（curlコマンド）

#### テスト用の音声ファイルを準備

```bash
# テスト用の空の音声ファイルを作成
touch test_audio.m4a
```

#### アップロードテスト

```bash
# Supabase認証トークンを取得（Supabase Dashboard > Settings > API > service_role key）
SUPABASE_URL="https://your-project.supabase.co"
SERVICE_ROLE_KEY="your-service-role-key"
USER_ID="your-test-user-id"

# ファイルをアップロード
curl -X POST "$SUPABASE_URL/storage/v1/object/audio/$USER_ID/test_audio.m4a" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: audio/x-m4a" \
  --data-binary @test_audio.m4a
```

期待されるレスポンス：

```json
{
  "Key": "audio/{user_id}/test_audio.m4a"
}
```

#### ダウンロードテスト

```bash
# ファイルをダウンロード（公開読み取り）
curl "$SUPABASE_URL/storage/v1/object/public/audio/$USER_ID/test_audio.m4a" \
  -o downloaded_test.m4a
```

#### 削除テスト

```bash
# ファイルを削除
curl -X DELETE "$SUPABASE_URL/storage/v1/object/audio/$USER_ID/test_audio.m4a" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY"
```

期待されるレスポンス：

```json
{
  "message": "Successfully deleted"
}
```

---

## iOSアプリからのテスト

### Step 6: Swift UIでのテストコード

```swift
import Supabase

// Supabaseクライアント初期化（既存のクライアントを使用）
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://your-project.supabase.co")!,
    supabaseKey: "your-anon-key"
)

// テスト用の音声ファイルアップロード
func testAudioUpload() async throws {
    // テスト用のダミーデータ
    let testData = Data("test audio content".utf8)

    // ユーザーID取得
    guard let userId = try await supabase.auth.session.user.id else {
        throw NSError(domain: "Auth", code: 401, userInfo: nil)
    }

    // ファイルパス生成
    let fileName = "test_\(Date().timeIntervalSince1970).m4a"
    let filePath = "\(userId.uuidString)/\(fileName)"

    // アップロード
    let response = try await supabase.storage
        .from("audio")
        .upload(path: filePath, data: testData)

    print("✅ Upload success: \(response)")

    // Public URL取得
    let publicURL = try supabase.storage
        .from("audio")
        .getPublicURL(path: filePath)

    print("✅ Public URL: \(publicURL)")

    // 削除
    try await supabase.storage
        .from("audio")
        .remove(paths: [filePath])

    print("✅ Delete success")
}
```

### 実行方法

```swift
// ViewDidAppear または onAppear で実行
Task {
    do {
        try await testAudioUpload()
    } catch {
        print("❌ Test failed: \(error)")
    }
}
```

---

## トラブルシューティング

### エラー: "Bucket not found"

**原因**: audioバケットが作成されていない

**解決策**:
```bash
supabase storage create audio --public false
```

### エラー: "new row violates row-level security policy"

**原因**: RLSポリシーが正しく設定されていない

**解決策**:
1. `storage_setup_audio_bucket.sql`を再実行
2. Supabase Dashboard > Storage > audio > Policiesでポリシーを確認
3. ポリシーの定義が正しいか確認

### エラー: "CORS policy blocked"

**原因**: CORS設定が不足

**解決策**:
1. Supabase Dashboard > Project Settings > API
2. "Allow requests from any origin"を有効化（開発環境）
3. 本番環境では、アプリのドメインを明示的に設定

### エラー: "File size exceeds limit"

**原因**: ファイルサイズが5MBを超えている

**解決策**:
1. 音声ファイルを30秒以内に制限（アプリ側で制御）
2. 必要に応じてバケットのファイルサイズ制限を引き上げ

---

## ファイルパス構造

設定完了後、以下のパス構造で音声ファイルが保存されます：

```
audio/
├── {user_id_1}/
│   ├── 1735344000_abc123.m4a
│   ├── 1735344030_def456.m4a
│   └── ...
├── {user_id_2}/
│   ├── 1735344100_ghi789.m4a
│   └── ...
```

**パス形式**: `audio/{user_id}/{timestamp}_{uuid}.m4a`

---

## セキュリティ確認チェックリスト

- [x] audioバケットが非公開設定になっている
- [x] アップロードは自分のフォルダのみ可能
- [x] 削除は自分のファイルのみ可能
- [x] 読み取りはすべてのユーザーが可能（公開投稿のため）
- [x] ファイルサイズ制限が設定されている（5MB）
- [x] 許可するMIMEタイプが設定されている

---

## 次のステップ

✅ **タスク1.2完了**: Supabase Storageバケットとセキュリティポリシーの設定

⏭️ **次はタスク1.3**: Postモデルの拡張（SwiftUIコード）

---

## 参考情報

- **SQLスクリプト**: `supabase/storage_setup_audio_bucket.sql`
- **Supabase Storage公式ドキュメント**: https://supabase.com/docs/guides/storage
- **RLSポリシーリファレンス**: https://supabase.com/docs/guides/auth/row-level-security
