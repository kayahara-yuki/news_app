# 残り3つのポリシーを作成（コピー&ペースト用）

## ✅ 既に作成済み
- ✅ Users can upload to their own folder (INSERT)

## ⏳ 以下の3つを Dashboard UI から作成してください

---

## ポリシー2: UPDATE（更新）

**Dashboard UI での入力内容:**

```
Policy name:
Users can update their own files

Policy command:
UPDATE

Target roles:
authenticated

USING expression:
(bucket_id = 'audio') AND ((auth.uid())::text = (storage.foldername(name))[1])

WITH CHECK expression:
(bucket_id = 'audio') AND ((auth.uid())::text = (storage.foldername(name))[1])
```

**コピー用（USING）:**
```sql
(bucket_id = 'audio') AND ((auth.uid())::text = (storage.foldername(name))[1])
```

**コピー用（WITH CHECK）:**
```sql
(bucket_id = 'audio') AND ((auth.uid())::text = (storage.foldername(name))[1])
```

---

## ポリシー3: DELETE（削除）

**Dashboard UI での入力内容:**

```
Policy name:
Users can delete their own files

Policy command:
DELETE

Target roles:
authenticated

USING expression:
(bucket_id = 'audio') AND ((auth.uid())::text = (storage.foldername(name))[1])
```

**コピー用（USING）:**
```sql
(bucket_id = 'audio') AND ((auth.uid())::text = (storage.foldername(name))[1])
```

---

## ポリシー4: SELECT（読み取り）

**Dashboard UI での入力内容:**

```
Policy name:
Anyone can read audio files

Policy command:
SELECT

Target roles:
public

USING expression:
(bucket_id = 'audio')
```

**コピー用（USING）:**
```sql
(bucket_id = 'audio')
```

---

## 📍 Dashboard UI の場所

### 方法1: Database > Policies
1. 左メニュー > **Database**
2. **Policies** タブをクリック
3. テーブル一覧から **`storage.objects`** を選択
4. **New Policy** をクリック

### 方法2: Storage > Configuration
1. 左メニュー > **Storage**
2. **audio** バケットをクリック
3. **Configuration** または **Policies** タブ
4. **New Policy** をクリック

---

## ✅ 完了確認

3つのポリシーを作成したら、以下のSQLで確認してください：

```sql
SELECT
    policyname as "Policy Name",
    CASE cmd
        WHEN 'r' THEN 'SELECT'
        WHEN 'a' THEN 'INSERT'
        WHEN 'w' THEN 'UPDATE'
        WHEN 'd' THEN 'DELETE'
    END as "Operation",
    roles as "Target Roles"
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname IN (
      'Users can upload to their own folder',
      'Users can update their own files',
      'Users can delete their own files',
      'Anyone can read audio files'
  )
ORDER BY policyname;
```

### 期待される結果（4行）

| Policy Name | Operation | Target Roles |
|------------|-----------|--------------|
| Anyone can read audio files | SELECT | {public} |
| Users can delete their own files | DELETE | {authenticated} |
| Users can update their own files | UPDATE | {authenticated} |
| Users can upload to their own folder | INSERT | {authenticated} |

---

## 🎯 次のステップ

4つすべて作成できたら、**タスク1.2完了** → **タスク1.3（Postモデル拡張）** に進みます。
