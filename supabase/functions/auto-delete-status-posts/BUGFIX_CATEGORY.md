# バグ修正: カテゴリ制約エラー

## 発生したエラー

```
ERROR:  23514: new row for relation "posts" violates check constraint "posts_category_check"
```

## 原因

`quick_test.sql` と `test_data.sql` で `category = 'food'` を使用していたが、postsテーブルのカテゴリ制約には `'food'` が含まれていなかった。

## 利用可能なカテゴリ

PostCategoryの定義（[Post.swift:117-125](ios-app/LocationNewsSNS/Models/Post.swift:117-125)）:

- `news` - ニュース
- `event` - イベント
- `emergency` - 緊急情報
- `traffic` - 交通情報
- `weather` - 天気・気象
- **`social`** - ソーシャル
- `business` - 店舗・ビジネス
- `other` - その他

## 修正内容

### 修正前
```sql
category: 'food'  -- ❌ 存在しないカテゴリ
```

### 修正後
```sql
category: 'social'  -- ✅ ステータス投稿に適したカテゴリ
```

## 修正したファイル

1. **[quick_test.sql](quick_test.sql:27)** - カテゴリを `'food'` → `'social'` に変更
2. **[test_data.sql](test_data.sql:46)** - カテゴリを `'food'` → `'social'` に変更

## なぜ 'social' を選択したか

- ステータス投稿（「カフェなう」「散歩中」等）は**ソーシャル**な情報共有
- `social` カテゴリは「ユーザーの状態や行動を共有する」目的に最適
- 他の選択肢（`news`, `event`, `emergency`等）は不適切

## 修正後のテスト手順

1. Supabase SQL Editorで [quick_test.sql](quick_test.sql) を実行
2. エラーなく4件の投稿が作成されることを確認
3. Edge Functionを実行して削除動作を確認

## 期待される結果

```sql
-- テストデータ作成後
SELECT content, category FROM posts WHERE content LIKE '%テスト%';

-- 結果:
☕ カフェなう（テスト期限切れ1）  | social
🚶 散歩中（テスト期限切れ2）      | other
📚 勉強中（テスト有効）           | other
通常の投稿です（テスト）          | other
```

## 今後の注意点

テストデータ作成時は、以下のカテゴリのみを使用すること:

- `news`, `event`, `emergency`, `traffic`, `weather`, `social`, `business`, `other`

## 関連ファイル

- [Post.swift](ios-app/LocationNewsSNS/Models/Post.swift) - PostCategoryの定義
- [quick_test.sql](quick_test.sql) - クイックテスト用SQL（修正済み）
- [test_data.sql](test_data.sql) - テストデータ作成SQL（修正済み）
