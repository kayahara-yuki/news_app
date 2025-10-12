# MCPツール統合ガイド - Context7、Serena、Cipher

## 概要

このドキュメントでは、Context7、Serena、Cipherの3つのMCPツールを統合して使用する方法について説明します。これらのツールを組み合わせることで、AIコーディングの効率を飛躍的に向上させることができます。

## 各ツールの役割

### Context7 - 最新ドキュメント自動取得
- **役割**: 15,000以上のライブラリの最新ドキュメントをリアルタイム取得
- **いつ使うか**: 新しいフレームワークやライブラリを使用する際
- **メリット**: 古い情報によるエラーを防止、常に最新のAPI仕様を参照

### Serena - セマンティックコード解析
- **役割**: Language Server Protocol統合による深いコード理解
- **いつ使うか**: 大規模リファクタリング、複雑なバグ修正、IDE並みの解析が必要な場合
- **メリット**: 精密なコード解析、依存関係の可視化、バグの迅速な特定

### Cipher - AIメモリレイヤー
- **役割**: 過去の知識と推論パターンの保持・活用
- **いつ使うか**: 長期プロジェクト、チーム開発、知識の蓄積が重要な場合
- **メリット**: 過去の解決策を記憶、同じ問題の対処時間削減、チーム知識の共有

## 統合設定

### 完全統合設定（claude_config.json）

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["--yes", "@upstash/context7-mcp"],
      "env": {}
    },
    "serena": {
      "command": "uv",
      "args": [
        "run", 
        "serena-mcp-server",
        "--port",
        "32123"
      ],
      "cwd": "${workspaceFolder}/serena",
      "port": 32123,
      "env": {
        "SERENA_PROJECT_PATH": "${workspaceFolder}"
      }
    },
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

### 環境変数の設定

```bash
# 必須環境変数
export OPENAI_API_KEY="sk-your-openai-key"
export ANTHROPIC_API_KEY="sk-ant-your-key"

# Cipher用（ローカル埋め込み使用時）
export CIPHER_EMBEDDER="local"

# Serena用
export SERENA_PROJECT_PATH="${PWD}"
```

## 統合ワークフロー

### 1. 新機能実装フロー（3ツール連携）

```bash
# Step 1: Context7で最新の情報を取得
claude "React 19の新機能Suspenseの使い方を教えて。use context7"

# Step 2: Serenaでプロジェクト構造を解析
claude "現在のプロジェクトでSuspenseを実装するのに最適な場所を提案して"

# Step 3: 実装
claude "提案された場所にSuspenseを使った非同期データ取得を実装して"

# Step 4: Cipherで知識を保存
claude "今回のSuspense実装パターンを将来のために記憶して"
```

### 2. バグ修正ワークフロー

```bash
# Step 1: Serenaでエラー箇所を特定
claude "TypeError: Cannot read property 'map' of undefined というエラーが出ています。原因を特定して"

# Step 2: Context7で解決策を検索
claude "このエラーパターンの一般的な解決方法を教えて。use context7"

# Step 3: 修正実装
claude "特定された問題を修正して、同様のエラーを防ぐガード句も追加して"

# Step 4: Cipherで学習
claude "このエラーパターンと解決方法を記憶して、次回同様の問題に遭遇したら警告して"
```

### 3. リファクタリング作業

```bash
# Step 1: Serenaで依存関係を解析
claude "UserServiceクラスの依存関係をすべて洗い出して"

# Step 2: Context7で最新のベストプラクティスを確認
claude "依存性注入パターンの最新のベストプラクティスを教えて。use context7"

# Step 3: リファクタリング計画
claude "依存性注入パターンを使ってUserServiceをリファクタリングする計画を立てて"

# Step 4: 段階的実装
claude "計画に従って、まずインターフェースを定義して"
claude "次に、具象クラスを実装して"
claude "最後に、DIコンテナーの設定を追加して"

# Step 5: 知識の保存
claude "今回のリファクタリングパターンをチーム用のベストプラクティスとして保存"
```

## 高度な活用テクニック

### 1. カスタムプロンプトテンプレート

`.claude/prompts/code-review.md`を作成：

```markdown
以下の観点でコードレビューを実施してください：
1. Serenaを使用してコード品質を分析
2. Context7で最新のベストプラクティスを確認
3. Cipherで過去の同様のレビュー結果を参照

対象ファイル: {files}
重点チェック項目: {focus_areas}
```

使用方法：
```bash
claude --template code-review --files "src/**/*.ts" --focus_areas "セキュリティ,パフォーマンス"
```

### 2. チーム開発での活用

```bash
# チームメモリのセットアップ
cipher serve --team --id "frontend-team"

# 共有知識の登録
claude "このプロジェクトのコーディング規約を記憶して：
- TypeScriptのstrictモードを使用
- 関数は30行以内
- コンポーネントは単一責任原則に従う"

# 新メンバーのオンボーディング
claude "新しいチームメンバー向けに、このプロジェクトの技術スタックと開発フローを説明して"
```

### 3. 自動化スクリプト

`scripts/claude-assistant.js`を作成：

```javascript
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

async function analyzePR(prNumber) {
  console.log(`PR #${prNumber}の分析を開始...`);
  
  // Serenaでコード解析
  await execPromise(`claude "PR #${prNumber}の変更を解析して"`);
  
  // Context7で関連ドキュメント取得
  await execPromise(`claude "変更されたAPIの最新仕様を確認。use context7"`);
  
  // レビューコメント生成
  await execPromise(`claude "PRレビューコメントを生成して"`);
  
  // 知識ベースに追加
  await execPromise(`claude "このPRから学んだパターンを保存"`);
  
  console.log('分析完了');
}

// GitHub Actionsから実行
if (process.env.PR_NUMBER) {
  analyzePR(process.env.PR_NUMBER);
}
```

## パフォーマンス最適化

### 1. 並列実行の活用

```bash
# 複数のツールを並列で実行
claude "
1. Context7でReact 19の情報を取得
2. Serenaで現在のコードベースを解析
3. Cipherから過去の類似実装を検索
これらを並列で実行して統合レポートを作成"
```

### 2. キャッシュの活用

```bash
# Serenaキャッシュの最適化
echo "cache_strategy: aggressive" >> .serena/project.yml

# Cipherのインクリメンタル更新
cipher config set indexing incremental
```

## トラブルシューティング

### 同時使用時の注意事項

1. **ポート競合**
   ```bash
   # Serenaのポート確認
   lsof -i :32123
   
   # 必要に応じてポート変更
   claude mcp update serena -- uv run serena-mcp-server --port 32124
   ```

2. **メモリ使用量**
   ```bash
   # プロセス監視
   ps aux | grep -E "(context7|serena|cipher)"
   
   # メモリ使用量の確認
   top -p $(pgrep -d',' -f "context7|serena|cipher")
   ```

3. **API制限**
   ```bash
   # Context7のレート制限確認
   claude "現在のContext7使用状況を確認"
   
   # Cipherのローカル埋め込みに切り替え
   export CIPHER_EMBEDDER="local"
   ```

### よくある問題と解決方法

#### 問題1: ツール間の応答が遅い
```bash
# 解決策: 順次実行に変更
claude "まずContext7で情報取得してから、Serenaで解析を実行"
```

#### 問題2: メモリ不足
```bash
# 解決策: 各ツールの制限設定
# .serena/project.yml
performance:
  max_memory: 1024  # 1GB制限

# .cipher/config.json
{
  "performance": {
    "maxStorageGB": 2
  }
}
```

#### 問題3: 設定の競合
```bash
# 解決策: 環境変数の分離
export SERENA_CONFIG_PATH="${PWD}/.serena"
export CIPHER_WORKSPACE="${PWD}/.cipher"
```

## ベストプラクティス

### 1. 適切な使い分け

| シナリオ | 推奨ツール | 理由 |
|---|---|---|
| 新しいライブラリの学習 | Context7 | 最新ドキュメントが必要 |
| バグの原因調査 | Serena | 深いコード解析が必要 |
| 過去の実装パターンの参照 | Cipher | 蓄積された知識が有効 |
| 新機能の実装 | 3ツール連携 | 総合的なアプローチが効果的 |

### 2. チーム運用のガイドライン

```bash
# 1. 共通設定の作成
mkdir -p .team-config
cp claude_config.json .team-config/
cp .serena/project.yml .team-config/
cp .cipher/config.json .team-config/

# 2. チーム知識の初期設定
claude "チーム共通のコーディング規約とアーキテクチャ決定を記録"

# 3. 定期的なメンテナンス
# 週次実行
cipher cleanup --days 7
serena --clear-cache
```

### 3. セキュリティ対策

```json
{
  "security": {
    "exclude_patterns": [
      "**/*.key",
      "**/*.pem", 
      "**/secrets/**",
      "**/.env*",
      "**/node_modules/**"
    ],
    "sanitize_logs": true,
    "encrypt_memory": true
  }
}
```

## コスト最適化

### API使用量の削減

1. **Cipherのメモリ機能を活用**
   - 重複する質問を避ける
   - 過去の回答を再利用

2. **Context7のキャッシュ活用**
   - 同じドキュメントの重複取得を避ける

3. **Serenaのローカル解析**
   - API呼び出しを最小限に抑える

### 使用料金の目安

| ツール | 基本料金 | API使用料 | 月額目安 |
|---|---|---|---|
| Context7 | 無料 | - | $0 |
| Serena | 無料 | - | $0 |
| Cipher | 無料 | OpenAI Embeddings | $5-20 |

注意: Claude APIやOpenAI APIの使用料は別途発生します。

## まとめ

Context7、Serena、Cipherの統合使用により：

1. **開発効率の大幅向上**
   - 最新情報へのアクセス（Context7）
   - 深いコード理解（Serena）
   - 知識の蓄積と活用（Cipher）

2. **品質の向上**
   - 正確な実装
   - バグの早期発見
   - ベストプラクティスの適用

3. **チーム生産性の向上**
   - 知識の共有
   - 標準化された開発プロセス
   - 新メンバーの学習促進

これらのツールを適切に組み合わせることで、AIコーディングを次のレベルへ押し上げることができます。

## 参考リンク

- [Context7 使用方法](./context7.md)
- [Serena 使用方法](./serena.md)
- [Cipher 使用方法](./cipher.md)
- [Claude Code公式ドキュメント](https://docs.anthropic.com/en/docs/claude-code)
- [MCP仕様ドキュメント](https://modelcontextprotocol.io/docs)