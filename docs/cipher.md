# Cipher - AIメモリレイヤーツール

## 概要

CipherはAIメモリレイヤーを提供するMCPツールです。長期プロジェクト、チーム開発、過去の決定事項やコンテキストを保持し、継続的な学習と知識の蓄積を可能にします。

## 特徴

- デュアルメモリシステム（System 1：明示的知識、System 2：推論パターン）
- チーム共同作業用のワークスペースメモリ
- セマンティック検索によるインテリジェントなメモリ検索
- ローカル埋め込みモデル対応（OpenAI API不要オプション）

## 前提条件

- Node.js（v18以上）
- npm（v7以上推奨）
- OpenAI APIキー（デフォルト）またはローカル埋め込みモデル

## インストール

### グローバルインストール（推奨）

```bash
# グローバルインストール
npm install -g @byterover/cipher

# Claude Codeに登録
claude mcp add cipher -- cipher --mode mcp
```

### 環境変数の設定

```bash
# デフォルトはOpenAI埋め込みを使用
export OPENAI_API_KEY="sk-your-openai-key"

# ローカル埋め込みモデル（MiniLM等）を使用する場合（実験的機能）
export CIPHER_EMBEDDER="local"
```

環境変数を永続化するため、`~/.bashrc`または`~/.zshrc`に追加：

```bash
echo 'export OPENAI_API_KEY="sk-your-openai-key"' >> ~/.bashrc
echo 'export CIPHER_EMBEDDER="local"' >> ~/.bashrc  # ローカル使用時のみ
source ~/.bashrc
```

### 初期化手順（バージョン別）

| Cipherバージョン | 初期化コマンド |
|---|---|
| ≤ 0.8.x | なし（初回 `cipher --mode mcp` で自動生成） |
| 0.9.x - 0.10.x | `cipher serve --init` |
| 0.11.x 以降 | `cipher init && cipher serve` |

```bash
# バージョン確認
cipher --version

# バージョンに応じた初期化（自動判定）
cipher --version | grep -qE '^0\.[0-8]\.' || cipher serve --init

# ローカル埋め込みモデル使用時のサーバー起動（v0.10系では実験的）
cipher serve --embedder local
```

## 設定

### Claude Code設定ファイル（claude_config.json）

```json
{
  "mcpServers": {
    "cipher": {
      "command": "cipher",
      "args": ["--mode", "mcp"],
      "env": {
        "CIPHER_WORKSPACE": "${workspaceFolder}/.cipher",
        "OPENAI_API_KEY": "${OPENAI_API_KEY}",
        "CIPHER_EMBEDDER": "local"
      }
    }
  }
}
```

### Cipher設定（.cipher/config.json）

```json
{
  "memory": {
    "system1": {
      "enabled": true,
      "maxEntries": 1000,
      "retentionDays": 90
    },
    "system2": {
      "enabled": true,
      "trackReasoningSteps": true
    }
  },
  "workspace": {
    "sharedMemory": true,
    "teamId": "your-team-id"
  },
  "embedder": {
    "type": "openai",
    "model": "text-embedding-ada-002"
  },
  "privacy": {
    "localOnly": false,
    "encryptMemory": true
  },
  "performance": {
    "indexing": "incremental",
    "searchStrategy": "hybrid",
    "cacheExpiry": 3600,
    "maxStorageGB": 5
  }
}
```

### 設定項目の説明

- `embedder.type`: "openai"または"local"を指定（MiniLM等のローカルモデル使用時）
- `embedder.model`: 使用する埋め込みモデルの指定
- `maxStorageGB`: ストレージ上限設定（大規模プロジェクト向け）

## 使用方法

### 基本的な使い方

```bash
# 知識の保存
claude "今回のSuspense実装パターンを将来のために記憶して"

# 過去の知識を参照
claude "前回実装したエラーハンドリングパターンを教えて"

# チーム知識の共有
claude "このプロジェクトのコーディング規約を記憶して"
```

### 実践的な使用例

#### 新機能実装フロー
```bash
# 1. Context7で最新の情報を取得
claude "React 19の新機能Suspenseの使い方を教えて。use context7"

# 2. Serenaでプロジェクト構造を解析
claude "現在のプロジェクトでSuspenseを実装するのに最適な場所を提案して"

# 3. 実装
claude "提案された場所にSuspenseを使った非同期データ取得を実装して"

# 4. Cipherで知識を保存
claude "今回のSuspense実装パターンを将来のために記憶して"
```

#### バグ修正ワークフロー
```bash
# エラーパターンと解決方法を学習
claude "このエラーパターンと解決方法を記憶して、次回同様の問題に遭遇したら警告して"

# 過去の類似問題を参照
claude "この問題と似たエラーを以前に解決したことはありますか？"
```

#### チーム開発での活用
```bash
# チームメモリのセットアップ
cipher serve --team --id "frontend-team"

# 共有知識の登録
claude "このプロジェクトのコーディング規約を記憶して：
- TypeScriptのstrictモードを使用
- 関数は30行以内
- コンポーネントは単一責任原則に従う"

# チームメンバーが参照
claude "このプロジェクトのコーディング規約を教えて"
```

### 高度な機能

#### セマンティック検索
```bash
# 関連する過去の実装を検索
claude "認証周りで過去に実装したパターンを検索して"

# 特定のトピックの学習履歴
claude "React hooksについて過去に学んだことを整理して"
```

#### パターン学習
```bash
# 推論パターンの記録
claude "この問題解決のアプローチを今後同様の問題に適用できるように記憶して"

# 決定事項の記録
claude "今回のアーキテクチャ選択の理由と背景を記録して"
```

## トラブルシューティング

### Cipherのメモリが同期されない

```bash
# メモリのリビルド
cipher rebuild

# 同期状態の確認
cipher status

# 手動同期
cipher sync --force

# ストレージ容量の確認（大規模プロジェクトの場合）
du -sh .cipher/  # macOS/Linux
dir .cipher /s   # Windows
```

### 起動時のエラー

```bash
# 設定ファイルの確認
cat .cipher/config.json

# ログの確認
tail -f .cipher/logs/cipher.log

# キャッシュのクリア
rm -rf .cipher/cache/
cipher rebuild
```

### APIキー関連のエラー

```bash
# 環境変数の確認
echo $OPENAI_API_KEY

# ローカル埋め込みモデルに切り替え
export CIPHER_EMBEDDER="local"
cipher serve --embedder local
```

## セキュリティ考慮事項

### APIキーの管理

```bash
# .envファイルを使用（.gitignoreに追加必須）
echo "OPENAI_API_KEY=sk-..." >> .env
echo "ANTHROPIC_API_KEY=sk-ant-..." >> .env

# 環境変数として読み込み
source .env
```

### プライベートデータの保護

```json
{
  "privacy": {
    "localOnly": true,
    "encryptMemory": true,
    "excludePatterns": [
      "**/*.key",
      "**/*.pem",
      "**/secrets/**",
      "**/.env*"
    ]
  }
}
```

## 既知の制限事項と注意点

- デフォルトではOpenAI APIキーが必要（ローカル埋め込みモデル使用時は不要）
- 大規模プロジェクト（1万ファイル超）では`.cipher`ディレクトリが数GB規模になります
- v0.9時点では`cipher init`コマンドは存在せず、`cipher serve --init`を使用
- `--embedder local`オプションはv0.10系では実験的機能
- ローカルモデル使用時は`~/.cache/cipher/models`に1GB超のモデルファイルがダウンロードされます

## パフォーマンス最適化

### メモリ使用量の最適化

```json
{
  "memory": {
    "system1": {
      "maxEntries": 500,  // エントリ数を制限
      "retentionDays": 30  // 保持期間を短縮
    }
  },
  "performance": {
    "indexing": "incremental",
    "searchStrategy": "hybrid",
    "cacheExpiry": 1800,  // キャッシュ有効期限を短縮
    "maxStorageGB": 2     // ストレージ上限を設定
  }
}
```

### ストレージ管理

```bash
# ストレージ使用量の確認
cipher stats

# 古いメモリのクリーンアップ
cipher cleanup --days 30

# インデックスの最適化
cipher optimize
```

## ベストプラクティス

1. **定期的なメンテナンス**
   - 月1回程度のクリーンアップ実行
   - ストレージ使用量の監視

2. **適切なチーム設定**
   - チームIDの適切な設定
   - 共有メモリのアクセス権限管理

3. **セキュリティ対策**
   - 機密情報の除外設定
   - ローカル暗号化の有効化

## 参考リンク

- [Cipher GitHub リポジトリ](https://github.com/byterover/cipher)
- [OpenAI Embeddings API](https://platform.openai.com/docs/guides/embeddings)
- [MCP仕様ドキュメント](https://modelcontextprotocol.io/docs)