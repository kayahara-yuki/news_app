# Kagi News API 仕様書

## 概要

Kagi News APIは、ニュース集約データへのアクセスを提供するAPIです。バッチ、カテゴリー、ストーリー、メディア情報を取得できます。

- **ベースURL（本番環境）**: `https://kite.kagi.com`
- **ベースURL（開発環境）**: `http://localhost:5173`
- **バージョン**: 1.0.0

---

## 認証

現時点では公開されているエンドポイントでは認証は不要です。

---

## 共通パラメータ

### 言語コード (`lang`)

多くのエンドポイントで使用される言語パラメータ：

- `default`: カテゴリーのソース言語で取得（推奨）
- `source`: 常に元の言語で取得
- `en`, `de`, `fr`, `es`, `it`, `pt`, `nl`, `sv`, `pl`, `tr`, `ru`, `zh`, `ja`, `hi`, `uk`: 特定の言語

**複数言語指定**（カンマ区切り）:
```
lang=ja,en
```
ストーリーのソース言語がリスト内にある場合はソース言語を返し、それ以外の場合は最初の言語に翻訳します。

---

## エンドポイント一覧

### 1. Batches（バッチ管理）

#### 1.1 最新バッチの取得

```http
GET /api/batches/latest
```

最も新しいニュースバッチを取得します。

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| `lang` | string | `default` | 言語コード |

**レスポンス例:**
```json
{
  "id": "497f6eca-6276-4993-bfeb-53cbbbba6f08",
  "createdAt": "2025-10-24T12:16:17.819Z",
  "language": "ja",
  "totalCategories": 73,
  "totalClusters": 456,
  "totalArticles": 2345,
  "totalReadCount": 5000
}
```

---

#### 1.2 特定バッチの詳細取得

```http
GET /api/batches/{batchId}
```

**パスパラメータ:**
| パラメータ | 型 | 必須 | 説明 |
|----------|-----|------|------|
| `batchId` | string | ✅ | UUID形式（例: `123e4567-e89b-12d3-a456-426614174000`）<br>または日付スラグ形式（例: `2025-01-15.1`） |

**レスポンス例:**
```json
{
  "id": "497f6eca-6276-4993-bfeb-53cbbbba6f08",
  "createdAt": "2025-10-24T12:16:17.819Z",
  "totalCategories": 73,
  "totalClusters": 456,
  "totalArticles": 2345,
  "processingTime": 120
}
```

---

#### 1.3 バッチの一覧取得

```http
GET /api/batches
```

指定期間内のバッチ一覧を取得します。

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| `from` | string (ISO 8601) | 24時間前 | 開始日時 |
| `to` | string (ISO 8601) | 現在時刻 | 終了日時 |
| `lang` | string | `default` | 言語コード |

**レスポンス例:**
```json
{
  "batches": [
    {
      "id": "uuid",
      "createdAt": "2025-10-24T12:00:00Z",
      "language": "ja",
      "totalCategories": 73,
      "totalClusters": 456,
      "totalArticles": 2345
    }
  ]
}
```

---

#### 1.4 バッチの利用可能言語取得

```http
GET /api/batches/{batchId}/languages
```

特定バッチで利用可能な翻訳言語の一覧を取得します。

**レスポンス例:**
```json
{
  "batchId": "123e4567-e89b-12d3-a456-426614174000",
  "languages": [
    {
      "code": "en",
      "name": "English"
    },
    {
      "code": "ja",
      "name": "Japanese"
    }
  ]
}
```

---

### 2. Categories（カテゴリー）

#### 2.1 最新バッチのカテゴリー一覧取得

```http
GET /api/batches/latest/categories
```

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| `lang` | string | `default` | 言語コード |

**レスポンス例:**
```json
{
  "batchId": "96cf948f-8a1b-4281-9ba4-8a9e1ad7b3c6",
  "createdAt": "2025-10-24T12:16:17.819Z",
  "hasOnThisDay": true,
  "categories": [
    {
      "id": "1eff836c-c6e2-4885-a547-e252d0439810",
      "categoryId": "japan",
      "categoryName": "Japan",
      "sourceLanguage": "ja",
      "timestamp": 1761301340,
      "readCount": 342,
      "clusterCount": "6"
    }
  ]
}
```

---

#### 2.2 特定バッチのカテゴリー一覧取得

```http
GET /api/batches/{batchId}/categories
```

**パスパラメータ:**
| パラメータ | 型 | 必須 | 説明 |
|----------|-----|------|------|
| `batchId` | string | ✅ | バッチID（UUID or 日付スラグ） |

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| `lang` | string | `default` | 言語コード |

---

### 3. Stories（ストーリー/クラスター）

#### 3.1 最新バッチの特定カテゴリーのストーリー取得

```http
GET /api/batches/latest/categories/{categoryId}/stories
```

**パスパラメータ:**
| パラメータ | 型 | 必須 | 説明 |
|----------|-----|------|------|
| `categoryId` | string | ✅ | カテゴリーUUID |

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 範囲 | 説明 |
|----------|-----|----------|------|------|
| `limit` | integer | 12 | 1-100 | 取得件数 |
| `lang` | string | `default` | - | 言語コード |

**レスポンス例:**
```json
{
  "batchId": "96cf948f-8a1b-4281-9ba4-8a9e1ad7b3c6",
  "categoryId": "1eff836c-c6e2-4885-a547-e252d0439810",
  "categoryName": "Japan",
  "timestamp": "2025-10-24T12:16:17.819Z",
  "stories": [
    {
      "id": "88bb8773-162d-41c0-ae69-fc6146299fef",
      "cluster_number": 1,
      "title": "日本の初の女性首相 たかいち 就任 経済と防衛強化",
      "short_summary": "10月21日に就任したたかいちさなえ首相は...",
      "category": "Politics",
      "location": "Tokyo, Japan",
      "emoji": "🎸",
      "unique_domains": 12,
      "number_of_titles": 23,
      "sourceLanguage": "ja",
      "did_you_know": "たかいち首相はヘビーメタルのファン...",
      "talking_points": [
        "市場の反応: たかいち首相の積極的な財政方針..."
      ],
      "perspectives": [
        {
          "text": "たかいちさなえ首相: 経済と安全保障を...",
          "sources": [
            {
              "name": "Japan Today",
              "url": "https://japantoday.com/..."
            }
          ]
        }
      ],
      "historical_background": "日本は従来、国防費を...",
      "timeline": [
        {
          "date": "October 21, 2025",
          "content": "たかいちさなえ氏が首相に就任..."
        }
      ],
      "user_action_items": [
        "投資の影響を確認する: 政府の財政・防衛方針..."
      ],
      "industry_impact": [
        "防衛産業: 政府が防衛費を年度内に..."
      ],
      "suggested_qna": [
        {
          "question": "防衛費2%引き上げの財源は？",
          "answer": "現時点で財務相は増税や..."
        }
      ],
      "primary_image": {
        "url": "https://example.com/image.jpg",
        "caption": "画像の説明",
        "credit": "撮影者/提供元"
      },
      "secondary_image": {
        "url": "https://example.com/image2.jpg",
        "caption": "画像の説明2",
        "credit": "撮影者/提供元2"
      },
      "articles": [
        {
          "title": "Japan Has a New Leader...",
          "link": "https://news.google.com/...",
          "domain": "google.com",
          "date": "2025-10-23T14:49:00.000Z",
          "image": "",
          "image_caption": ""
        }
      ],
      "domains": [
        {
          "name": "google.com",
          "favicon": "/api/favicon-proxy?domain=google.com"
        }
      ]
    }
  ],
  "readCount": 342,
  "domains": [
    {
      "name": "google.com",
      "favicon": "/api/favicon-proxy?domain=google.com"
    }
  ]
}
```

---

#### 3.2 特定バッチの特定カテゴリーのストーリー取得

```http
GET /api/batches/{batchId}/categories/{categoryId}/stories
```

**パスパラメータ:**
| パラメータ | 型 | 必須 | 説明 |
|----------|-----|------|------|
| `batchId` | string | ✅ | バッチID |
| `categoryId` | string | ✅ | カテゴリーUUID |

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 範囲 | 説明 |
|----------|-----|----------|------|------|
| `limit` | integer | 50 | 1-100 | 取得件数 |
| `offset` | integer | 0 | 0- | ページネーションオフセット |
| `lang` | string | `default` | - | 言語コード |

---

### 4. OnThisDay（歴史上の出来事）

#### 4.1 最新バッチのOnThisDay取得

```http
GET /api/batches/latest/onthisday
```

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| `lang` | string | `default` | 言語コード（カンマ区切り可） |

**レスポンス例:**
```json
{
  "timestamp": 1729785600,
  "language": "ja",
  "events": [
    {
      "year": 1945,
      "title": "国際連合が正式に発足",
      "description": "第二次世界大戦後の国際平和と安全の維持を目的として...",
      "category": "Politics"
    }
  ]
}
```

---

#### 4.2 特定バッチのOnThisDay取得

```http
GET /api/batches/{batchId}/onthisday
```

**パスパラメータ:**
| パラメータ | 型 | 必須 | 説明 |
|----------|-----|------|------|
| `batchId` | string | ✅ | バッチID |

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| `lang` | string | `default` | 言語コード（カンマ区切り可） |

---

### 5. Search（検索）

#### 5.1 ストーリー検索

```http
GET /api/search
```

全バッチからストーリーをフルテキスト検索します。

**クエリパラメータ:**
| パラメータ | 型 | 必須 | デフォルト | 説明 |
|----------|-----|------|----------|------|
| `q` | string | ✅ | - | 検索クエリ（最低2文字） |
| `limit` | integer | ❌ | 20 | 最大取得件数（1-100） |
| `offset` | integer | ❌ | 0 | オフセット（0-） |
| `from` | string | ❌ | - | 開始日時（ISO 8601） |
| `to` | string | ❌ | - | 終了日時（ISO 8601） |
| `lang` | string | ❌ | `default` | 言語コード |
| `categoryId` | string | ❌ | - | カテゴリーIDでフィルタ |

**レスポンス例:**
```json
{
  "results": [
    {
      "story": {
        "id": "uuid",
        "title": "...",
        "short_summary": "..."
      },
      "batchId": "uuid",
      "batchDate": "2025-10-24T12:00:00Z",
      "categoryId": "japan",
      "categoryName": "Japan"
    }
  ],
  "total": 150,
  "hasMore": true,
  "query": "japan",
  "limit": 20,
  "offset": 0
}
```

**注意:** 現在このエンドポイントは502エラーが発生する可能性があります。

---

### 6. Media（メディア情報）

#### 6.1 特定ホストのメディア情報取得

```http
GET /api/media/{host}
```

**パスパラメータ:**
| パラメータ | 型 | 必須 | 説明 |
|----------|-----|------|------|
| `host` | string | ✅ | ドメイン名（例: `nytimes.com`） |

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| `lang` | string | `default` | 言語コード |

**レスポンス例:**
```json
{
  "mediaInfo": {
    "country": "United States",
    "organization": "The New York Times",
    "domains": ["nytimes.com", "nyti.ms"],
    "description": "American daily newspaper based in New York City",
    "owner": "The New York Times Company",
    "typology": "Quality newspaper"
  }
}
```

---

#### 6.2 全メディアソース情報取得

```http
GET /api/media
```

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| `lang` | string | `default` | 言語コード |

**レスポンス例:**
```json
{
  "mediaData": [
    {
      "country": "United States",
      "organization": "The New York Times",
      "domains": ["nytimes.com", "nyti.ms"],
      "description": "American daily newspaper...",
      "owner": "The New York Times Company",
      "typology": "Quality newspaper"
    }
  ]
}
```

---

### 7. Localization（ローカライゼーション）

#### 7.1 ローカライズされた文字列取得

```http
GET /api/locale/{lang}
```

UI表示用のローカライズされた文字列を取得します。

**パスパラメータ:**
| パラメータ | 型 | 必須 | 説明 |
|----------|-----|------|------|
| `lang` | string | ✅ | ISO 639-1言語コード |

**サポートされる言語:**
`en`, `es`, `fr`, `de`, `it`, `pt`, `ru`, `zh`, `ja`, `ko`, `ar`, `hi`, `nl`, `sv`, `pl`, `da`, `fi`, `no`, `cs`, `hu`, `tr`, `el`, `he`, `th`, `id`, `ms`, `vi`, `ro`, `uk`, `bg`, `hr`, `sk`, `sl`, `lt`, `lv`, `et`, `sr`, `ca`, `eu`, `gl`, `sw`

**レスポンス例:**
```json
{
  "locale": "ja",
  "strings": {
    "title": "Kagi ニュース - Elevated",
    "description": "ニュース閲覧体験を向上させる",
    "categories": {
      "World": "世界",
      "USA": "米国",
      "Business": "ビジネス",
      "Technology": "テクノロジー"
    },
    "ui": {
      "loading": "読み込み中...",
      "error": "エラーが発生しました",
      "showMore": "もっと見る",
      "settings": "設定"
    }
  }
}
```

---

### 8. Chaos Index（混沌指数）

世界のニュース分析に基づく緊張度指数（0-100スケール）

**スケール:**
- **0-20**: 安定（minimal chaos）
- **21-40**: 軽度の混乱（mild turbulence）
- **41-60**: 中程度の混乱（moderate chaos）
- **61-80**: 高い不安定性（high instability）
- **81-100**: 深刻な混乱（severe chaos）

#### 8.1 最新バッチのChaos Index取得

```http
GET /api/batches/latest/chaos
```

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| `lang` | string | `default` | 言語コード |

**レスポンス例:**
```json
{
  "chaosIndex": 65,
  "chaosDescription": "The world is very hot with high instability",
  "chaosLastUpdated": "2025-10-24T12:16:17.819Z"
}
```

---

#### 8.2 特定バッチのChaos Index取得

```http
GET /api/batches/{batchId}/chaos
```

**パスパラメータ:**
| パラメータ | 型 | 必須 | 説明 |
|----------|-----|------|------|
| `batchId` | string | ✅ | バッチID |

**クエリパラメータ:**
| パラメータ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| `lang` | string | `default` | 言語コード |

---

## ストーリーオブジェクトの詳細フィールド

### 基本情報
- `id`: ストーリーID
- `cluster_number`: カテゴリー内の順序番号
- `title`: タイトル
- `short_summary`: 要約（2-3文）
- `category`: カテゴリー名
- `location`: 地理的な位置
- `emoji`: テーマを表す絵文字
- `sourceLanguage`: ソース言語コード

### メタ情報
- `unique_domains`: ユニークなニュースソース数
- `number_of_titles`: 記事タイトル総数

### 詳細コンテンツ（任意フィールド）
- `did_you_know`: 興味深い事実
- `talking_points`: 主要な論点（配列）
- `quote`: 関連する引用
- `quote_author`: 引用の発言者
- `quote_attribution`: 引用の出典
- `quote_source_url`: 引用ソースのURL
- `quote_source_domain`: 引用ソースのドメイン

### 分析・背景情報
- `perspectives`: 異なる視点（配列）
- `geopolitical_context`: 地政学的な背景
- `historical_background`: 歴史的な背景
- `international_reactions`: 国際的な反応（配列）
- `humanitarian_impact`: 人道的影響
- `economic_implications`: 経済的影響
- `timeline`: 時系列（配列）
- `future_outlook`: 将来の見通し
- `key_players`: 主要人物・組織（配列）

### 専門分野別情報
- `technical_details`: 技術的詳細（配列）
- `business_angle_text`: ビジネス観点のテキスト
- `business_angle_points`: ビジネス観点のポイント（配列）
- `scientific_significance`: 科学的重要性（配列）
- `performance_statistics`: パフォーマンス統計（配列）
- `league_standings`: リーグ順位
- `gameplay_mechanics`: ゲームメカニクス（配列）
- `technical_specifications`: 技術仕様（配列）

### アクション・影響
- `user_action_items`: ユーザーが取るべき行動（配列）
- `industry_impact`: 業界への影響（配列）

### その他
- `travel_advisory`: 旅行注意事項（配列）
- `destination_highlights`: 目的地のハイライト
- `culinary_significance`: 料理的重要性
- `diy_tips`: DIYのヒント
- `design_principles`: デザイン原則
- `user_experience_impact`: ユーザー体験への影響（配列）
- `suggested_qna`: 推奨Q&A（配列）

### 画像
- `primary_image`: メイン画像
  - `url`: 画像URL
  - `caption`: キャプション
  - `credit`: クレジット
- `secondary_image`: サブ画像

### 記事・ドメイン
- `articles`: 個別記事の配列
  - `title`: 記事タイトル
  - `link`: URL
  - `domain`: ドメイン名
  - `date`: 公開日時
  - `image`: 画像URL
  - `image_caption`: 画像キャプション
- `domains`: ニュースソース情報（配列）
  - `name`: ドメイン名
  - `favicon`: ファビコンURL

---

## エラーレスポンス

### 400 Bad Request
```json
{
  "error": "Invalid request parameters"
}
```

### 404 Not Found
```json
{
  "error": "Batch not found"
}
```

### 500 Server Error
```json
{
  "error": "Internal server error"
}
```

### 502 Bad Gateway
現在、検索エンドポイント (`/api/search`) で発生する可能性があります。

---

## 使用例

### 1. 日本の最新ニュースを取得

```bash
# ステップ1: カテゴリー一覧取得
curl "https://kite.kagi.com/api/batches/latest/categories?lang=ja"

# ステップ2: Japanカテゴリーのストーリー取得
curl "https://kite.kagi.com/api/batches/latest/categories/japan/stories?lang=ja&limit=20"
```

### 2. 世界のChaos Index取得

```bash
curl "https://kite.kagi.com/api/batches/latest/chaos?lang=ja"
```

### 3. 特定メディアの情報取得

```bash
curl "https://kite.kagi.com/api/media/nytimes.com?lang=en"
```

---

## 注意事項

1. **検索API (`/api/search`) は現在不安定**: 502エラーが発生する可能性があります
2. **データの鮮度**: バッチは定期的に更新されますが、リアルタイムではありません
3. **地域ニュース**: 国際的・全国的なニュースが中心で、地域レベル（区・市町村）のニュースは含まれません
4. **フィールドの省略**: データがない場合、フィールドは省略されます（配列は空配列 `[]` を返します）

---

## ベストプラクティス

1. **言語設定**: `lang=default` を使用すると各カテゴリーのソース言語でコンテンツを取得できます
2. **ページネーション**: `limit` と `offset` を使用して効率的にデータを取得してください
3. **キャッシング**: バッチIDを使用してクライアント側でキャッシュすることを推奨します
4. **エラーハンドリング**: 502エラーに対する適切なリトライロジックを実装してください

---

## 更新履歴

- **2025-10-24**: 初版作成
- API仕様はKagi公式ドキュメントに基づく

---

## サポート

詳細はKagi公式サイトを参照してください: https://kagi.com
