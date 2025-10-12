# Context7 - 最新ドキュメント自動取得ツール

## 概要

Context7は、15,000以上のライブラリのドキュメントをリアルタイムで取得・注入できるMCPツールです。新しいフレームワークやライブラリを使用する際に、常に最新のAPIドキュメントを参照できます。

## 特徴

- 15,000以上のライブラリのドキュメントをサポート（2025年8月時点）
- リアルタイムでドキュメントを取得・注入
- OSSで追加料金なし
- 公式ホスティング版はレート制限あり（Free tier: 15 req/min）

## インストール

### Claude Code CLIでの追加（推奨）

```bash
# 基本インストール（npm v9以降推奨）
claude mcp add context7 -- npx --yes @upstash/context7-mcp

# Windows PowerShellでパス警告が出る場合
claude mcp add context7 -- npx --yes --location=global @upstash/context7-mcp
```

注意: npm v10以降でcorepack enable使用時は--locationオプションで警告が出ることがあります。

### 動作確認

```bash
claude "Next.js 14のApp Routerについて教えて。use context7"
```

## 設定

### Claude Code設定ファイル（claude_config.json）

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["--yes", "@upstash/context7-mcp"],
      "env": {}
    }
  }
}
```

## 使用方法

### 基本的な使い方

```bash
# 特定のライブラリの最新ドキュメントを取得
claude "React 19の新機能について教えて。use context7"

# APIの最新仕様を確認
claude "Express.js v5のルーティング機能について。use context7"

# フレームワークの最新情報取得
claude "Vue 3 Composition APIの使い方を詳しく。use context7"
```

### 実践的な使用例

#### 新機能実装時
```bash
# 最新のAPIドキュメントを取得してから実装
claude "Tailwind CSS v4の新機能を使ってダークモードを実装したい。use context7"
```

#### バグ修正時
```bash
# エラーパターンの最新解決方法を検索
claude "このTypeScriptエラーの一般的な解決方法を教えて。use context7"
```

#### ライブラリ選定時
```bash
# 複数ライブラリの比較
claude "状態管理ライブラリZustandとRecoilの最新比較。use context7"
```

## トラブルシューティング

### Context7が動作しない場合

```bash
# キャッシュクリア
npm cache clean --force

# 再インストール
claude mcp remove context7
claude mcp add context7 -- npx --yes @upstash/context7-mcp@latest
```

### よくある問題

1. **ネットワーク接続エラー**
   - インターネット接続を確認
   - プロキシ設定が必要な場合は環境変数を設定

2. **レート制限エラー**
   - 公式ホスティング版を使用している場合、15 req/minの制限があります
   - 少し時間をおいてから再試行

3. **ドキュメントが見つからない**
   - 一部のプライベートパッケージのドキュメントは取得できません
   - ライブラリ名の表記を確認

## 制限事項

- 一部のプライベートパッケージのドキュメントは取得できません
- 公式ホスティング版にはレート制限があります（Free tier: 15 req/min）
- インターネット接続が必要です

## ベストプラクティス

1. **明確なライブラリ名を指定**
   ```bash
   # 良い例
   claude "React Router v6のuseNavigateフックについて。use context7"
   
   # 曖昧な例（避ける）
   claude "ルーティングについて教えて。use context7"
   ```

2. **バージョンを指定**
   ```bash
   # バージョン指定で正確な情報を取得
   claude "TypeScript 5.3の新機能について。use context7"
   ```

3. **具体的な用途を明記**
   ```bash
   # 用途を明記することで適切なドキュメントを取得
   claude "Next.js 14でのSSRの実装方法。use context7"
   ```

## 参考リンク

- [Context7 GitHub リポジトリ](https://github.com/upstash/context7)
- [MCP仕様ドキュメント](https://modelcontextprotocol.io/docs)
- [Claude Code公式ドキュメント](https://docs.anthropic.com/en/docs/claude-code)