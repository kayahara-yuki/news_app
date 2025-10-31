# Supabase Storage 手動セットアップガイド

## ⚠️ SQLエラー回避のため、Dashboard UIから手動で設定します

`must be owner of table objects`エラーが発生する場合は、このガイドに従って手動セットアップしてください。

---

## Step 1: Audioバケットの作成

1. **Supabaseダッシュボード**を開く
2. 左メニューから**Storage**をクリック
3. **Create a new bucket**ボタンをクリック
4. 以下を入力：
   - **Name**: `audio`
   - **Public bucket**: ❌ オフ（チェックしない）
   - **File size limit**: `5242880` (5MB)
   - **Allowed MIME types**: `audio/mpeg, audio/mp4, audio/x-m4a, audio/aac`
5. **Save**をクリック

---

## Step 2: RLSポリシーの作成

### 2-1. Storageポリシー画面を開く

1. Storage画面で**`audio`**バケットをクリック
2. 上部の**Policies**タブをクリック
3. **Create policy**ボタンをクリック

---

### ポリシー1: アップロード許可（自分のフォルダのみ）

1. **Create policy**をクリック
2. **Get started quickly**セクションで**Custom**を選択
3. 以下を入力：

   - **Policy name**: `Users can upload to their own folder`
   - **Allowed operation**: `INSERT`にチェック
   - **Target roles**: `authenticated`を選択
   - **USING expression** (空欄のまま)
   - **WITH CHECK expression**:
     ```sql
     bucket_id = 'audio' AND auth.uid()::text = (storage.foldername(name))[1]
     ```

4. **Save policy**をクリック

---

### ポリシー2: 更新許可（自分のファイルのみ）

1. **Create policy**をクリック
2. **Custom**を選択
3. 以下を入力：

   - **Policy name**: `Users can update their own files`
   - **Allowed operation**: `UPDATE`にチェック
   - **Target roles**: `authenticated`を選択
   - **USING expression**:
     ```sql
     bucket_id = 'audio' AND auth.uid()::text = (storage.foldername(name))[1]
     ```
   - **WITH CHECK expression**:
     ```sql
     bucket_id = 'audio' AND auth.uid()::text = (storage.foldername(name))[1]
     ```

4. **Save policy**をクリック

---

### ポリシー3: 削除許可（自分のファイルのみ）

1. **Create policy**をクリック
2. **Custom**を選択
3. 以下を入力：

   - **Policy name**: `Users can delete their own files`
   - **Allowed operation**: `DELETE`にチェック
   - **Target roles**: `authenticated`を選択
   - **USING expression**:
     ```sql
     bucket_id = 'audio' AND auth.uid()::text = (storage.foldername(name))[1]
     ```
   - **WITH CHECK expression** (空欄のまま)

4. **Save policy**をクリック

---

### ポリシー4: 読み取り許可（全員）

1. **Create policy**をクリック
2. **Custom**を選択
3. 以下を入力：

   - **Policy name**: `Anyone can read audio files`
   - **Allowed operation**: `SELECT`にチェック
   - **Target roles**: `public`を選択
   - **USING expression**:
     ```sql
     bucket_id = 'audio'
     ```
   - **WITH CHECK expression** (空欄のまま)

4. **Save policy**をクリック

---

## Step 3: 検証

### 3-1. ポリシー一覧を確認

Storage > audio > Policiesタブで、以下の4つのポリシーが表示されることを確認：

- ✅ Users can upload to their own folder (INSERT)
- ✅ Users can update their own files (UPDATE)
- ✅ Users can delete their own files (DELETE)
- ✅ Anyone can read audio files (SELECT)

### 3-2. SQLで検証（オプション）

Supabase Dashboard > SQL Editorで以下を実行：

```sql
-- バケット確認
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id = 'audio';

-- ポリシー確認
SELECT
    policyname,
    CASE cmd
        WHEN 'r' THEN 'SELECT'
        WHEN 'a' THEN 'INSERT'
        WHEN 'w' THEN 'UPDATE'
        WHEN 'd' THEN 'DELETE'
    END as operation
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname LIKE '%audio%'
ORDER BY policyname;
```

期待される出力：

| id | name | public | file_size_limit | allowed_mime_types |
|----|------|--------|-----------------|-------------------|
| audio | audio | false | 5242880 | {audio/mpeg,audio/mp4,audio/x-m4a,audio/aac} |

| policyname | operation |
|-----------|-----------|
| Anyone can read audio files | SELECT |
| Users can delete their own files | DELETE |
| Users can update their own files | UPDATE |
| Users can upload to their own folder | INSERT |

---

## Step 4: iOSアプリからのテスト

### テストコード

`test_storage_upload.swift`を参照してください。

```swift
import Supabase

let tester = StorageSetupTester(supabase: SupabaseConfig.shared.client)
let passed = await tester.runTests()
```

### 期待される結果

```
========================================
🧪 Supabase Storage Setup Tests
========================================

[Test 1] Authentication Check
✅ User authenticated: <user-id>

[Test 2] File Upload (Own Folder)
✅ Upload successful
   File path: audio/<user-id>/test_<timestamp>.m4a

[Test 3] File Read (Public URL)
✅ Public URL retrieved: https://...
✅ File downloaded successfully

[Test 4] File Delete (Own File)
✅ Delete successful

[Test 5] Unauthorized Upload (Should Fail)
✅ Unauthorized upload blocked (as expected)
   RLS policy is working correctly

========================================
✅ All tests passed!
========================================
```

---

## トラブルシューティング

### エラー: "new row violates row-level security policy"

**原因**: ポリシーの条件式が間違っている

**解決策**: 各ポリシーのUSING/WITH CHECK式を再確認してください

### エラー: "Bucket not found"

**原因**: バケットが作成されていない

**解決策**: Step 1を再実行してください

---

## ✅ 完了確認チェックリスト

- [ ] audioバケットが作成されている
- [ ] 4つのRLSポリシーが作成されている
- [ ] ポリシー条件式が正しい
- [ ] iOSアプリからのテストが成功した

すべてチェックできたら、**タスク1.2完了**です。

---

## 次のステップ

⏭️ **タスク1.3**: Postモデルの拡張（SwiftUIコード）

Postエンティティに以下を追加：
- `audioURL: String?`
- `isStatusPost: Bool`
- `expiresAt: Date?`
- 計算プロパティ（`isExpired`, `remainingTime`）
