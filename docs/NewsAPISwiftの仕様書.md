# NewsAPISwift 仕様書

## 概要

NewsAPISwiftは、[News API V2](http://newsapi.org)のSwiftクライアントライブラリです。30,000以上のニュースソースやブログから、速報ニュースや記事検索を行うことができます。

## 主な機能

### 1. ニュースソース取得（getSources）

ニュースAPIがインデックスしている利用可能なソースの一覧を取得します。

#### パラメータ

| パラメータ | 説明 | 指定可能な値 | デフォルト |
|-----------|------|-------------|-----------|
| `category` | 取得したいソースのカテゴリ | `business`, `entertainment`, `general`, `health`, `science`, `sports`, `technology` | 全カテゴリ |
| `language` | 取得したいソースの言語 | `ar`, `de`, `en`, `es`, `fr`, `he`, `it`, `nl`, `no`, `pt`, `ru`, `se`, `ud`, `zh` | 全言語 |
| `country` | 取得したいソースの国 | [公式ドキュメント](https://newsapi.org/docs/endpoints/sources)を参照 | 全国 |

#### 使用例
```swift
import NewsAPISwift

let newsAPI = NewsAPI(apiKey: "YourKeyHere")

newsAPI.getSources(category: .technology, language: .en, country: .us) { result in
    switch result {
    case .success(let sources):
        // 取得したソースを処理
    case .failure(let error):
        // エラーハンドリング
    }
}
```

### 2. トップヘッドライン取得（getTopHeadlines）

トップヘッドラインを取得します。特定の国、単一または複数のソース、キーワードでフィルタリングできます。

#### パラメータの組み合わせ例

##### キーワード検索
```swift
newsAPI.getTopHeadlines(q: "weather") { result in
    switch result {
    case .success(let headlines):
        // 取得したヘッドラインを処理
    case .failure(let error):
        // エラーハンドリング
    }
}
```

##### 特定ソースからの取得
```swift
newsAPI.getTopHeadlines(sources: ["bbc-news"]) { result in
    switch result {
    case .success(let headlines):
        // 取得したヘッドラインを処理
    case .failure(let error):
        // エラーハンドリング
    }
}
```

##### カテゴリと国でフィルタリング
```swift
newsAPI.getTopHeadlines(category: .technology, country: .us) { result in
    switch result {
    case .success(let headlines):
        // 取得したヘッドラインを処理
    case .failure(let error):
        // エラーハンドリング
    }
}
```

##### ページネーション
```swift
newsAPI.getTopHeadlines(pageSize: 20, page: 1) { result in
    switch result {
    case .success(let headlines):
        // 取得したヘッドラインを処理
    case .failure(let error):
        // エラーハンドリング
    }
}
```

#### 利用可能なパラメータ

詳細なパラメータ仕様については、[公式ドキュメント](https://newsapi.org/docs/endpoints/sources)を参照してください。

## インストール方法

### CocoaPods

1. CocoaPodsのインストール:
```bash
$ gem install cocoapods
```

2. Podfileに以下を追加:
```ruby
platform :ios, '8.0'
use_frameworks!

target '<Your Target Name>' do
  pod 'NewsAPISwift', '~> 2.0'
end
```

3. インストールを実行:
```bash
$ pod install
```

### Carthage

1. Carthageのインストール:
```bash
$ brew update
$ brew install carthage
```

2. Cartfileに以下を追加:
```
github "lucaslimapoa/NewsAPISwift"
```

3. フレームワークをビルド:
```bash
carthage update
```

4. ビルドされた `NewsAPISwift.framework` をXcodeプロジェクトにドラッグ&ドロップ

## サンプルプロジェクト

サンプルプロジェクトを実行する手順:

1. リポジトリをクローン
2. `Example` ディレクトリで `pod install` を実行
3. `Example.xcworkspace` を開いてプロジェクトを実行

## 必要要件

- iOS 8.0以上
- Swift対応
- News API V2のAPIキー（[newsapi.org](https://newsapi.org)で取得可能）

## ライセンス

MITライセンスの下で提供されています。詳細はLICENSEファイルを参照してください。

## 注意事項

このライブラリとその作者は、newsapi.orgによって承認されておらず、関連もありません。

## 参考リンク

- [News API公式サイト](https://newsapi.org)
- [News API公式ドキュメント](https://newsapi.org/docs/endpoints/sources)
- [GitHubリポジトリ](https://github.com/lucaslimapoa/NewsAPISwift)