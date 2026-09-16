# yunomi Plugin for Claude Code

yunomi CLI ツールを Claude Code と連携させるプラグインです。タスク管理、レビューワークフロー、報告書作成を効率化します。

## インストール

```bash
# Claude Code で実行
/plugin marketplace add kazuph/yunomi
/plugin install yunomi-plugin@yunomi-plugins
```

## 更新

プラグインを最新版に更新するには、一度アンインストールしてから再インストールしてください：

```bash
claude plugin uninstall yunomi-plugin@yunomi-plugins
claude plugin install yunomi-plugin@yunomi-plugins
```

※ 新しいエージェントや機能を反映するには、Claude Code の再起動も必要です。

## 旧マーケットプレイス名からの移行

`yunomi-marketplace`（旧名）を使用していた場合は、以下で削除してください：

```bash
# 旧プラグインのアンインストール
claude plugin uninstall yunomi-plugin@yunomi-marketplace

# 旧マーケットプレイスの削除（どちらか一方を実行）
/plugin marketplace remove yunomi-marketplace          # Claude Code内で実行
claude plugin marketplace remove yunomi-marketplace    # ターミナルで実行
```

その後、上記の「インストール」セクションの手順で再インストールしてください。

### 開発ワークフロー

原本は `plugin/skills/do/`・`done/`・`bucho/` です。個人環境へコピーする場合も同じ本文を配布し、配布先で別の手順を保守しません。`tiny-do`・`tiny-done` は統合され、作業規模による品質水準の選択はありません。

| 入口 | 担当する工程 |
|---|---|
| `/do` | 要求確認、種類に合う手順ファイルを読む、現行機能と全呼び出し元の調査、再利用の検討、データ・状態・責任範囲の設計、設計助言、ネストした git wt、TDD、検証できる単位での実装から `/done` まで。 |
| `/done` | 新要件と既存動作の回帰確認、動作を保持した deslop、ビルドと実動作検証、専門レビュー、説明図・スクリーンショット・動画・報告の検証、人間の承認と指摘修正。 |
| `/bucho` | 同じ `/do` → `/done` の全成果を、承認済みのHerdr実装責任者へ委譲。部長は判断記録と実際の差分・証拠を確認して完遂まで責任を持つ。 |

名前空間付きの呼び出し名はエージェントのスキル一覧で確認してください。本文の実行手順は [do](skills/do/SKILL.md)、[done](skills/done/SKILL.md)、[bucho](skills/bucho/SKILL.md) にあります。

### 取り込んだ行動

P-Stackから、依頼の種類に合う手順を選ぶこと、実際の処理の理解、データと責任範囲のモデル化、観測による技術的な不明点の解消、前提を検証してから次へ進む作業順序、判断理由と証拠の記録を取り込みます。Ponytailからは、理解した要求を満たす既存コード → 標準機能 → プラットフォーム機能 → 導入済み依存 → 新しいコードの順で検討し、全呼び出し元から共通原因を直す行動を取り込みます。

既存の必須レビュー・テスト・承認は保持します。deslopでも信頼境界の検証、データ保護、セキュリティ、アクセシビリティ、必要なテストを削りません。第三者のスクリプト・ライブラリ・モデル設定は取り込みません。

### 同梱するレビューと実装の指示

| 指示ファイル（`plugin/agents/`） | 保持する責任 |
|---|---|
| `review-code-security.md` | 設計助言と最終コード・セキュリティレビュー。型、エラー処理、重複、インジェクション、認証認可、秘密情報、暗号化。 |
| `review-e2e.md` | 全プロジェクト種別の実際のフロー、アサーション、永続状態、モック・迂回、待機、テスト環境の確認。 |
| `review-ui-ux.md` | 該当UIのWCAG 2.2 AA、キーボード・フォーカス、デザイン、文言・国際化。 |
| `report-builder.md` / `report-validator.md` | 元の依頼と指摘、判断理由、図と証拠の埋め込み、リンク、報告形式の確認。 |
| `webapp-impl.md` / `backend-impl.md` / `mobile-impl.md` | Web・バックエンド・モバイルの実装と実動作検証。 |
| `dogfooding.md` / `review-video.md` | 実操作と動画の確認。 |

現在の環境で承認された独立レビューの起動方法・モデル・権限を使います。固定数のエージェント起動や退役済みモデルの利用は要求しません。重大な指摘（Critical/High）は修正・再検証・再レビューしてから人間へ提出します。

### Markdownだけを既存環境へ配布する

信頼済みのローカルYunomiチェックアウトから、`plugin/skills/{do,done,bucho}/` を既存のスキル配置先へコピーします。まず配布先の独自変更を確認し、3つを同じ改訂へそろえます。`/do` 配下の `playbooks/` と `why.md` も含めます。追加インストーラーや第三者スクリプトは必要ありません。Claude Codeプラグインのインストールとは別の操作で、hooksは有効化しません。

専門レビューの指示は同じチェックアウトの `plugin/agents/` を参照できます。既存環境の `yunomi`、`artifact-proof`、`validate-report`、該当するテストスキル、Web UIの `frontend-design`、委譲する場合の `herdr-pane-commander` も引き続き使用します。これらの補助スキルはこの3スキルの同梱物ではありません。参照先が見つからないときに検証を省略したり、外部スクリプトを取得したりしてはいけません。

### 証拠・レビュー・再開

- 元のcheckoutは既定ブランチのまま保持し、その配下の `git wt` ワークツリーで開発します。
- Webは実ブラウザ、バックエンドは実テストフレームワーク・DBまたは許可済みローカルエミュレーター・カバレッジ、モバイルはMaestroのアサーションと各段階の証拠を使います。Fullstackは両側と通信経路を検証します。
- 説明図、スクリーンショット、動画を報告の表に埋め込みます。比較では既存と新フローを並べ、維持・追加・変更・明示的廃止を色と文字で区別します。提出前にファイルと埋め込み、起動後にブラウザで画像の読み込みを確認します。
- REPORT.md、証拠、判断記録には合意済みの保存先を使い、圧縮や再起動後も同じ記録から再開します。`.artifacts/` の新設・移動はユーザーの許可が必要です。証跡はコミットせず、PR添付は既存の添付手段を使います。
- `yunomi` スキルの現行プロトコルで、検証済みHerdrまたはtmux通知先と `--loop` を指定します。指摘は原文のTODOにして実装・再検証し、同じ承認ループを継続します。人間の承認をAIが代行しません。
- 完了状態は、実装、ビルド・実動作・証拠の検証、人間の承認、許可済みの配布を区別します。

### 既存のフック

`plugin/hooks/` と `plugin/hooks-handlers/` は、commit/push前のレビュー確認、完了チェックリスト、worktreeとテストの保護を提供します。今回の3スキル統合は新しいフックや外部実行依存を追加しません。スキルだけの配布でフックを有効化しません。

## License

MIT
