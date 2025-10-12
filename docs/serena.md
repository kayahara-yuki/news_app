# Serena - セマンティックコード解析ツール

## 概要

SerenaはLanguage Server Protocol（LSP）を統合したセマンティックコード解析MCPツールです。大規模コードベースのリファクタリング、複雑なバグ修正、IDE並みのコード理解を提供します。

## 特徴

- Language Server Protocol（LSP）統合
- マルチ言語サポート（Python、JavaScript、TypeScript、Rust、Go、Java等）
- プロジェクトメモリによるコンテキスト保持
- セマンティック検索とコード解析

## 前提条件

- Python（3.8以上）
- uv（0.1.40以上）
- Node.js（v18以上）

注意: 2025年8月時点のuvはuvx同梱。古い環境では`pip install uvx`が必要な場合があります。

## インストール

### 方法1: 直接インストール（推奨・最も簡潔）

```bash
# Python uvが必要（事前にインストール）
pip install uv

# 1行でインストールと登録を完了
claude mcp add serena \
  -- uv run --from git+https://github.com/oraios/serena serena-mcp-server \
  --port 32123
```

注意: uv runはpoetry runやpipx runと同等の隔離実行環境を提供します。

### 方法2: ローカルクローン方式（カスタマイズが必要な場合）

```bash
# リポジトリをクローン
git clone https://github.com/oraios/serena.git
cd serena

# 設定ファイルをコピー（必要に応じて編集）
cp src/serena/resources/serena_config.template.yml serena_config.yml

# Claude Codeに登録
claude mcp add serena-local -- uv run serena-mcp-server --port 32123
```

### claude_config.jsonに直接記載する場合

```json
{
  "mcpServers": {
    "serena": {
      "command": "uv",
      "args": ["run", "serena-mcp-server", "--port", "32123"],
      "cwd": "${workspaceFolder}/serena",
      "port": 32123
    }
  }
}
```

注意: ローカルクローン時はcwdパラメータが必須です。

## 設定

### プロジェクト設定（.serena/project.yml）

プロジェクトルートに`.serena`ディレクトリを作成し、以下の設定を追加：

```yaml
project_name: "my-awesome-project"
language: typescript  # python, rust, go, java など
entry_points:
  - src/index.ts
  - src/app.ts
ignored_dirs:
  - node_modules
  - .git
  - dist
  - coverage
  - __pycache__
  - public/images  # 画像ディレクトリを除外
  - docs/pdfs      # PDFドキュメントを除外
ignored_files:
  - "*.log"
  - "*.tmp"
  - ".env*"
  - "*.jpg"
  - "*.png"
  - "*.pdf"
  - "*.zip"
max_file_size: 1048576  # 1MB（バイナリも含む総バイト数）
show_logs: true
use_lsp: true

# セキュリティ設定
security:
  exclude_sensitive:
    - "**/*.key"
    - "**/*.pem"
    - "**/secrets/**"
  sanitize_logs: true
```

注意: `max_file_size`はバイナリファイルも含む総バイト数として扱われます。大きなアセットファイルは`ignored_dirs`や`ignored_files`で除外することを推奨します。

### パフォーマンス設定

```yaml
# .serena/project.yml に追加
performance:
  max_memory: 2048  # MB
  cache_size: 512   # MB
  lazy_loading: true
```

## 使用方法

### 基本的な使い方

```bash
# プロジェクト構造を解析
claude "現在のプロジェクトの構造を解析して"

# 依存関係の確認
claude "UserServiceクラスの依存関係をすべて洗い出して"

# エラー箇所の特定
claude "TypeError: Cannot read property 'map' of undefined というエラーが出ています。原因を特定して"
```

### 実践的な使用例

#### バグ修正ワークフロー
```bash
# エラー箇所を特定
claude "パフォーマンスが遅い箇所を特定して最適化提案をして"

# 影響範囲の確認
claude "この関数を変更した場合の影響範囲を教えて"
```

#### リファクタリング作業
```bash
# 依存関係を解析
claude "UserServiceクラスの依存関係をすべて洗い出して"

# リファクタリング計画
claude "依存性注入パターンを使ってUserServiceをリファクタリングする計画を立てて"

# 段階的実装
claude "計画に従って、まずインターフェースを定義して"
```

#### コードレビュー
```bash
# コード品質の分析
claude "現在のコードベースの品質を分析して改善点を教えて"

# セキュリティチェック
claude "セキュリティの観点からコードをレビューして"
```

## トラブルシューティング

### Serenaがプロジェクトを認識しない

```bash
# 設定ファイルの確認
cat .serena/project.yml

# MCPサーバーの再起動
claude mcp restart serena

# ログ確認
tail -f .serena/logs/serena.log
```

### LSPキャッシュが肥大化した場合

```bash
# LSPキャッシュのクリア（v0.7以降）
serena --clear-cache

# v0.7未満または上記コマンドが存在しない場合
# シンボリックリンク環境でも安全な削除方法
find .serena/cache -type f -delete
# または直接削除
rm -rf .serena/cache/
```

### ポート競合の確認

```bash
# macOS/Linux
lsof -i :32123

# Windows
netstat -ano | findstr :32123
```

### Windows環境でSerenaが動作しない

```bash
# WSL2を使用するか、以下の環境変数を設定
set PATH=%PATH%;C:\Program Files\nodejs\
set PATH=%PATH%;C:\Python311\Scripts\

# PowerShellの場合
$env:PATH += ';C:\Program Files\nodejs\'
$env:PATH += ';C:\Python311\Scripts\'
```

## 既知の問題

- TypeScript/JavaScriptのLSPサポートが不安定な場合があります
- Windows環境でnpmパス解決の問題が発生することがあります
- Java言語サーバーの起動に時間がかかる場合があります（特にmacOS）
- デフォルトポート8000が競合しやすいため、カスタムポート推奨

## 制限事項

- Windows環境では追加の設定が必要な場合があります
- デフォルトポート8000が競合する場合は別ポートを指定してください
- 大規模プロジェクト（1万ファイル超）ではパフォーマンスに影響する可能性があります

## ベストプラクティス

1. **適切な除外設定**
   - 大きなアセットファイルやビルド成果物は除外
   - セキュリティに関わるファイルは必ず除外

2. **パフォーマンス最適化**
   - `lazy_loading: true`を有効化
   - 適切な`max_file_size`設定

3. **定期的なキャッシュクリア**
   - 長期使用時はキャッシュサイズを監視
   - 必要に応じてキャッシュをクリア

## 参考リンク

- [Serena GitHub リポジトリ](https://github.com/oraios/serena)
- [Language Server Protocol 仕様](https://microsoft.github.io/language-server-protocol/)
- [MCP仕様ドキュメント](https://modelcontextprotocol.io/docs)