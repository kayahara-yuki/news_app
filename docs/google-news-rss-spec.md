# Google News RSS API 仕様書

## 概要

Google News RSSは、Googleニュースの検索結果やトピックをRSS/Atom形式で取得できるフィードサービスです。特定のキーワード、地域、言語でニュースをフィルタリングして取得できます。

- **ベースURL**: `https://news.google.com/rss`
- **フォーマット**: RSS 2.0 / Atom
- **認証**: 不要（公開API）
- **料金**: 無料

---

## 重要な注意事項

⚠️ **利用規約**

Google News RSSフィードは以下の目的でのみ利用可能です：
- 個人的な非商用利用
- 個人用フィードリーダーでの表示

**禁止事項:**
- 商用利用
- 大規模なスクレイピング
- フィードの再配布

フィードには以下の著作権表示が含まれています：
> Copyright © 2025 Google. All rights reserved. This XML feed is made available solely for the purpose of rendering Google News results within a personal feed reader for personal, non-commercial use.

---

## エンドポイント一覧

### 1. トピック別ニュース取得

```
GET https://news.google.com/rss/topics/{TOPIC_ID}
```

**主要トピックID:**
| トピックID | 内容 |
|-----------|------|
| `CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx6TVdZU0FtVnVHZ0pWVXlnQVAB` | World（世界） |
| `CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx1YlY4U0FtVnVHZ0pWVXlnQVAB` | Nation（国内） |
| `CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx6ZEdvU0FtVnVHZ0pWVXlnQVAB` | Business（ビジネス） |
| `CAAqJggKIiBDQkFTRWdvSUwyMHZNRFZxYUdjU0FtVnVHZ0pWVXlnQVAB` | Technology（テクノロジー） |
| `CAAqJggKIiBDQkFTRWdvSUwyMHZNRFZxZFY4U0FtVnVHZ0pWVXlnQVAB` | Sports（スポーツ） |
| `CAAqJggKIiBDQkFTRWdvSUwyMHZNREpxYW5RU0FtVnVHZ0pWVXlnQVAB` | Entertainment（エンターテイメント） |
| `CAAqJggKIiBDQkFTRWdvSUwyMHZNR3QwTlRFU0FtVnVHZ0pWVXlnQVAB` | Science（科学） |
| `CAAqJggKIiBDQkFTRWdvSUwyMHZNR3QwbnNzU0FtVnVHZ0pWVXlnQVAB` | Health（健康） |

**パラメータ:**
| パラメータ | 必須 | 説明 | 例 |
|----------|------|------|-----|
| `hl` | ❌ | 言語コード | `ja`, `en` |
| `gl` | ❌ | 国コード | `JP`, `US` |
| `ceid` | ❌ | 国・言語の組み合わせ | `JP:ja`, `US:en` |

**例:**
```
https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx6TVdZU0FtVnVHZ0pWVXlnQVAB?hl=ja&gl=JP&ceid=JP:ja
```

---

### 2. キーワード検索

```
GET https://news.google.com/rss/search
```

特定のキーワードでニュースを検索します。

**パラメータ:**
| パラメータ | 必須 | 説明 | 例 |
|----------|------|------|-----|
| `q` | ✅ | 検索キーワード | `札幌`, `白石区`, `AI` |
| `hl` | ❌ | 言語コード | `ja` |
| `gl` | ❌ | 国コード | `JP` |
| `ceid` | ❌ | 国・言語の組み合わせ | `JP:ja` |

**検索演算子:**
| 演算子 | 説明 | 例 |
|--------|------|-----|
| `OR` | いずれかのキーワード | `白石区 OR 札幌` |
| `AND` | 両方のキーワード（デフォルト） | `札幌 AND 初雪` |
| `"..."` | 完全一致 | `"札幌市白石区"` |
| `-` | 除外 | `札幌 -観光` |

**例:**

#### 札幌のニュース取得
```
https://news.google.com/rss/search?q=札幌&hl=ja&gl=JP&ceid=JP:ja
```

#### 白石区または札幌のニュース取得
```
https://news.google.com/rss/search?q=白石区 OR 札幌&hl=ja&gl=JP&ceid=JP:ja
```

#### 札幌の天気ニュース（観光除く）
```
https://news.google.com/rss/search?q=札幌 天気 -観光&hl=ja&gl=JP&ceid=JP:ja
```

---

### 3. 地域別ニュース取得

```
GET https://news.google.com/rss/headlines/section/geo/{LOCATION}
```

**例:**
```
https://news.google.com/rss/headlines/section/geo/Tokyo?hl=ja&gl=JP&ceid=JP:ja
```

**注意:** 地域名は英語表記が必要です（例: `Tokyo`, `Osaka`, `Sapporo`）

---

## レスポンス形式

### RSS 2.0形式

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
    <channel>
        <generator>NFE/5.0</generator>
        <title>"札幌" - Google ニュース</title>
        <link>https://news.google.com/search?q=札幌</link>
        <language>ja</language>
        <lastBuildDate>Fri, 24 Oct 2025 18:02:03 GMT</lastBuildDate>
        <description>Google ニュース</description>
        
        <item>
            <title>札幌で初雪観測 平年より5日早く - HTB北海道テレビ</title>
            <link>https://news.google.com/rss/articles/...</link>
            <guid isPermaLink="false">CBMi...</guid>
            <pubDate>Fri, 24 Oct 2025 03:08:00 GMT</pubDate>
            <description>...</description>
            <source url="https://www.htb.co.jp">HTB 北海道テレビ</source>
        </item>
        
        <item>
            <title>札幌市の公園にヒグマ2頭、緊急銃猟で駆除 - 読売新聞</title>
            <link>https://news.google.com/rss/articles/...</link>
            <guid isPermaLink="false">CBMi...</guid>
            <pubDate>Fri, 24 Oct 2025 06:50:00 GMT</pubDate>
            <description>...</description>
            <source url="https://www.yomiuri.co.jp">読売新聞</source>
        </item>
        
        <!-- 他のアイテム... -->
    </channel>
</rss>
```

### フィールド説明

#### `<channel>` レベル
| フィールド | 説明 | 例 |
|----------|------|-----|
| `<title>` | フィードのタイトル | `"札幌" - Google ニュース` |
| `<link>` | フィードのURL | `https://news.google.com/search?q=札幌` |
| `<language>` | 言語コード | `ja` |
| `<lastBuildDate>` | 最終更新日時 | `Fri, 24 Oct 2025 18:02:03 GMT` |
| `<description>` | フィードの説明 | `Google ニュース` |

#### `<item>` レベル（個別記事）
| フィールド | 説明 | 例 |
|----------|------|-----|
| `<title>` | 記事タイトル | `札幌で初雪観測 平年より5日早く - HTB北海道テレビ` |
| `<link>` | 記事URL | `https://news.google.com/rss/articles/...` |
| `<guid>` | 一意のID | `CBMi...` |
| `<pubDate>` | 公開日時 | `Fri, 24 Oct 2025 03:08:00 GMT` |
| `<description>` | 記事の説明（HTML形式） | `<a href="...">...</a>` |
| `<source url="">` | ソースメディア名とURL | `HTB 北海道テレビ` |

---

## 実際の取得例（札幌・白石区）

### 例1: 札幌のニュース取得

**リクエスト:**
```
GET https://news.google.com/rss/search?q=札幌&hl=ja&gl=JP&ceid=JP:ja
```

**取得できるニュース:**
- 札幌で初雪観測
- 札幌市の公園にヒグマ2頭駆除
- さっぽろ焼き芋テラス2025開催
- 全国うまいもの大会 札幌で開幕
- 華やか菊花 札幌・豊平公園で展示

---

### 例2: 白石区または札幌のニュース取得

**リクエスト:**
```
GET https://news.google.com/rss/search?q=白石区 OR 札幌&hl=ja&gl=JP&ceid=JP:ja
```

**取得できるニュース:**
- 札幌全体のニュース
- 白石区に関連するニュース（もしあれば）

---

### 例3: 特定トピックで絞り込み

**リクエスト:**
```
GET https://news.google.com/rss/search?q=札幌 ヒグマ&hl=ja&gl=JP&ceid=JP:ja
```

**取得できるニュース:**
- ヒグマ関連の札幌ニュースのみ

---

## 言語・地域コード

### よく使用される言語コード (`hl`)
| コード | 言語 |
|--------|------|
| `ja` | 日本語 |
| `en` | 英語 |
| `zh-CN` | 中国語（簡体字） |
| `zh-TW` | 中国語（繁体字） |
| `ko` | 韓国語 |
| `es` | スペイン語 |
| `fr` | フランス語 |
| `de` | ドイツ語 |

### よく使用される国コード (`gl`)
| コード | 国 |
|--------|-----|
| `JP` | 日本 |
| `US` | アメリカ |
| `GB` | イギリス |
| `CN` | 中国 |
| `KR` | 韓国 |
| `AU` | オーストラリア |
| `CA` | カナダ |

### `ceid`（国・言語の組み合わせ）
| コード | 説明 |
|--------|------|
| `JP:ja` | 日本の日本語ニュース |
| `US:en` | アメリカの英語ニュース |
| `GB:en` | イギリスの英語ニュース |
| `CN:zh-Hans` | 中国の簡体字中国語ニュース |

---

## Postmanでの取得方法

### 設定例: 札幌のニュース取得

```
Method: GET
URL: https://news.google.com/rss/search

Params:
  - q: 札幌
  - hl: ja
  - gl: JP
  - ceid: JP:ja

Headers:
  - Accept: application/xml
  - User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
```

### 設定例: 白石区のニュース取得

```
Method: GET
URL: https://news.google.com/rss/search

Params:
  - q: 白石区
  - hl: ja
  - gl: JP
  - ceid: JP:ja

Headers:
  - Accept: application/xml
```

---

## プログラムでの解析例

### Python（feedparserを使用）

```python
import feedparser

# フィードURL
url = "https://news.google.com/rss/search?q=札幌&hl=ja&gl=JP&ceid=JP:ja"

# フィード取得
feed = feedparser.parse(url)

# 記事を表示
for entry in feed.entries:
    print(f"タイトル: {entry.title}")
    print(f"リンク: {entry.link}")
    print(f"公開日: {entry.published}")
    print(f"ソース: {entry.source.title if hasattr(entry, 'source') else 'N/A'}")
    print("-" * 50)
```

### JavaScript（Node.js + rss-parser）

```javascript
const Parser = require('rss-parser');
const parser = new Parser();

(async () => {
  const feed = await parser.parseURL(
    'https://news.google.com/rss/search?q=札幌&hl=ja&gl=JP&ceid=JP:ja'
  );
  
  console.log(feed.title);
  
  feed.items.forEach(item => {
    console.log(`タイトル: ${item.title}`);
    console.log(`リンク: ${item.link}`);
    console.log(`公開日: ${item.pubDate}`);
    console.log('---');
  });
})();
```

### cURL

```bash
curl "https://news.google.com/rss/search?q=札幌&hl=ja&gl=JP&ceid=JP:ja"
```

---

## XMLのパース方法

### レスポンスの構造

```
<rss>
  └── <channel>
       ├── <title>         # フィードタイトル
       ├── <link>          # フィードURL
       ├── <language>      # 言語
       ├── <lastBuildDate> # 更新日時
       └── <item> × N      # 記事（複数）
            ├── <title>           # 記事タイトル
            ├── <link>            # 記事URL
            ├── <guid>            # 記事ID
            ├── <pubDate>         # 公開日時
            ├── <description>     # 記事説明（HTML）
            └── <source url="">   # ソース
```

### 記事URLの注意点

`<link>`で取得できるURLは、Google News経由のリダイレクトURLです：
```
https://news.google.com/rss/articles/CBMi...
```

実際のニュースサイトにアクセスするには、このURLにアクセスするとリダイレクトされます。

---

## ベストプラクティス

### 1. リクエスト頻度

⚠️ **レート制限**
- Google News RSSには公式のレート制限は明記されていませんが、過度なリクエストは避けてください
- 推奨: **1-5分に1回**程度

### 2. User-Agentの設定

適切なUser-Agentヘッダーを設定してください：
```
User-Agent: YourAppName/1.0 (contact@example.com)
```

### 3. キャッシング

- フィードの`<lastBuildDate>`を確認して、更新がない場合は再取得を避ける
- 記事の`<guid>`を使って重複を排除

### 4. エラーハンドリング

```python
import feedparser
import time

def fetch_news_with_retry(url, max_retries=3):
    for attempt in range(max_retries):
        try:
            feed = feedparser.parse(url)
            if feed.bozo == 0:  # パース成功
                return feed
        except Exception as e:
            print(f"エラー: {e}")
        
        if attempt < max_retries - 1:
            time.sleep(2 ** attempt)  # 指数バックオフ
    
    return None
```

### 5. URLエンコーディング

日本語キーワードは適切にURLエンコードしてください：
```python
from urllib.parse import quote

keyword = "札幌"
encoded = quote(keyword)
url = f"https://news.google.com/rss/search?q={encoded}&hl=ja&gl=JP&ceid=JP:ja"
```

---

## 制限事項

### 1. 取得可能な記事数
- 通常 **10-100件程度**
- ページネーションなし（オフセット指定不可）

### 2. 記事の鮮度
- **リアルタイムではない**
- 数分～数時間の遅延がある場合があります

### 3. フルテキストなし
- RSSフィードには記事の本文は含まれません
- タイトル、要約、リンクのみ

### 4. 画像
- 一部の記事にのみ画像が含まれます
- `<media:content>` や `<enclosure>` タグで提供

### 5. 地域の粒度
- **国・主要都市レベル**は良好
- **区・町レベル**のニュースは限定的
- 例: 「札幌」は多数、「白石区」は少数

---

## トラブルシューティング

### 問題1: 記事が取得できない

**原因:**
- キーワードが一般的すぎる/特殊すぎる
- 地域ニュースがGoogle Newsにインデックスされていない

**対策:**
```
# より広いキーワードを使用
q=札幌 → より多くの結果

# OR演算子で範囲を広げる
q=白石区 OR 札幌

# 時間を置いて再試行
```

### 問題2: XMLのパースエラー

**原因:**
- 不正なXML
- エンコーディングの問題

**対策:**
```python
import feedparser

feed = feedparser.parse(url)
if feed.bozo:
    print(f"パースエラー: {feed.bozo_exception}")
```

### 問題3: リンクが機能しない

**原因:**
- Google News経由のリダイレクトURL

**対策:**
```python
import requests

def get_real_url(google_news_url):
    response = requests.get(google_news_url, allow_redirects=True)
    return response.url
```

---

## 使用例: 札幌・白石区のニュース監視システム

### Python実装例

```python
import feedparser
import time
from datetime import datetime

def fetch_sapporo_news():
    """札幌・白石区のニュースを取得"""
    url = "https://news.google.com/rss/search?q=白石区 OR 札幌&hl=ja&gl=JP&ceid=JP:ja"
    
    feed = feedparser.parse(url)
    
    news_items = []
    for entry in feed.entries:
        news_items.append({
            'title': entry.title,
            'link': entry.link,
            'published': entry.published,
            'source': entry.source.title if hasattr(entry, 'source') else 'Unknown'
        })
    
    return news_items

def monitor_news(interval=300):  # 5分ごと
    """ニュースを定期的に監視"""
    seen_guids = set()
    
    while True:
        try:
            url = "https://news.google.com/rss/search?q=札幌&hl=ja&gl=JP&ceid=JP:ja"
            feed = feedparser.parse(url)
            
            for entry in feed.entries:
                if entry.id not in seen_guids:
                    print(f"🆕 新着ニュース: {entry.title}")
                    print(f"   ソース: {entry.source.title if hasattr(entry, 'source') else 'N/A'}")
                    print(f"   リンク: {entry.link}")
                    print(f"   時刻: {entry.published}")
                    print("-" * 80)
                    
                    seen_guids.add(entry.id)
            
            time.sleep(interval)
            
        except Exception as e:
            print(f"エラー: {e}")
            time.sleep(60)

if __name__ == "__main__":
    # 札幌のニュースを取得
    news = fetch_sapporo_news()
    
    print(f"取得したニュース: {len(news)}件\n")
    
    for item in news[:5]:  # 最新5件を表示
        print(f"タイトル: {item['title']}")
        print(f"ソース: {item['source']}")
        print(f"公開日: {item['published']}")
        print("-" * 80)
```

---

## よくある質問（FAQ）

### Q1: APIキーは必要ですか？
**A:** いいえ、Google News RSSは認証不要で利用できます。

### Q2: 商用利用は可能ですか？
**A:** いいえ、利用規約により個人的・非商用利用に限定されています。

### Q3: どのくらいの頻度でアクセスできますか？
**A:** 公式の制限はありませんが、1-5分に1回程度を推奨します。

### Q4: 記事の本文を取得できますか？
**A:** いいえ、RSSフィードにはタイトルと要約のみ含まれます。本文は各ニュースサイトから取得する必要があります。

### Q5: 白石区のニュースが少ないのはなぜですか？
**A:** Google Newsは主に大手メディアのニュースを収集しており、地域の小規模なニュースは含まれないことがあります。

### Q6: 過去のニュースを取得できますか？
**A:** いいえ、RSSフィードには直近のニュースのみ含まれます（通常数日～1週間程度）。

---

## 参考リンク

- [Google News](https://news.google.com/)
- [RSS 2.0 Specification](https://www.rssboard.org/rss-specification)
- [feedparser Documentation](https://feedparser.readthedocs.io/)

---

## 更新履歴

- **2025-10-24**: 初版作成、札幌・白石区の実例を含む

---

## まとめ

Google News RSSは、**地域ニュース（札幌、白石区など）を取得するのに適したAPI**です。

### ✅ 適している用途
- 地域ニュースの取得
- 特定キーワードでのニュース検索
- リアルタイム性が不要な用途
- 個人プロジェクト・学習目的

### ❌ 適していない用途
- 商用サービス
- 高頻度のリクエスト（スクレイピング）
- 記事本文の取得
- 詳細な分析・メタデータが必要な場合

地域ニュースには**Google News RSS**、国際的・包括的なニュースには**Kagi News API**を使い分けることをお勧めします。
