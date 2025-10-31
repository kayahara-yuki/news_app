# Kiro仕様駆動開発ワークフロー

## 概要
Kiro-style Spec Driven Development (SDD) による開発フロー

## コマンド一覧

### Phase 0: Steering（任意）
```
/kiro:steering              # ステアリングドキュメントの作成/更新
/kiro:steering-custom       # カスタムステアリング作成
```

### Phase 1: 仕様作成
```
/kiro:spec-init [description]     # 仕様の初期化
/kiro:spec-requirements [feature] # 要件定義書の生成
/kiro:spec-design [feature]       # 設計書の生成（対話式）
/kiro:spec-tasks [feature]        # タスク分解（対話式）
```

### Phase 2: 進捗追跡
```
/kiro:spec-status [feature]       # 現在の進捗とフェーズ確認
```

## ワークフロー規則
1. **3段階承認フロー**: Requirements → Design → Tasks → Implementation
2. **承認必須**: 各フェーズは人間のレビューが必要
3. **フェーズスキップ禁止**: 設計は承認済み要件が必要、タスクは承認済み設計が必要
4. **タスクステータス更新**: 作業中のタスクは完了時にマーク
5. **仕様準拠確認**: `/kiro:spec-status` で整合性を確認

## ファイル構成
```
.kiro/
├── steering/              # プロジェクト全体のガイドライン
│   ├── product.md        # 製品コンテキスト
│   ├── tech.md          # 技術スタック
│   └── structure.md     # ファイル構成
└── specs/               # 機能別仕様
    └── location-news-sns/
        ├── spec.md          # プロジェクト仕様
        ├── requirements.md  # 要件定義
        ├── design.md       # 設計書
        └── tasks.md        # タスク分解
```

## 現在のアクティブ仕様
- location-news-sns: 位置情報ベースニュース共有SNS

## 開発ガイドライン
- 思考は英語、回答生成は日本語で行う
- 新機能や小規模な追加ではステアリングは任意
- 大規模変更後は `/kiro:steering` で最新化を検討