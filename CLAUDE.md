# yunomi プロジェクト固有ルール

## 開発・テスト時のサーバー起動

### 自分で確認する場合（デフォルト）
1. `run_in_background: true` でcli.cjsを起動
2. Playwrightでスクリーンショットを撮影して確認
3. 確認完了後、ユーザーに報告
4. **ユーザーを待たせない・中断させない**

### ユーザーにレビューさせる場合のみ
- **フォアグラウンドで起動する**（`run_in_background` は使わない）
- ユーザーがブラウザでSubmit & Exitするまで待機する
- ユーザーが明示的に「開いて」「見せて」と言った場合のみ

## 構文エラーの回避

テンプレートリテラル内でバッククォートを使う場合はエスケープする：
- 正: `\\\``
- 誤: `` ` ``

## 主要ファイル

- `cli.cjs` - メインソースコード（単一ファイル）
- `package.json` - yunomi CLI本体のバージョン管理

## バージョン管理

**yunomi CLIとpluginのバージョンは別管理**:
- yunomi CLI: `package.json` の `version`
- plugin: `plugin/.claude-plugin/plugin.json` の `version`

plugin変更時は必ず `plugin/.claude-plugin/plugin.json` のバージョンを上げること。

### plugin更新手順（コミット・プッシュ後）

```bash
# 1. マーケットプレースを更新（GitHubから最新を取得）
claude plugin marketplace update yunomi-plugins

# 2. プラグインを更新
claude plugin update yunomi-plugin@yunomi-plugins

# 3. Claude Codeを再起動して適用
```

## テストファイルの配置

- テスト用のmd/動画ファイルは `examples/` ディレクトリに配置する
- **プロジェクトルートにテストファイルを置かない**
- 一時的なテストは `/tmp/` に配置

## yunomiのコンセプト

**yunomiは人間がブラウザでレビューするための確認ツール**。コードを読ませる場ではなく、**「これで問題ないですよね？」の確認の場**。

### yunomiに渡すのはコードではなくREPORT.md
- REPORT.mdに **変更の意図・影響範囲・テスト結果・エビデンス** をまとめる
- それをyunomiで開いて、ユーザーが「OK」か「ダメ」か判断できる状態にする
- コードの差分を直接yunomiに渡すのは冒涜（ユーザーにコードを読ませるな）

### 正しいフロー
1. 実装 → テスト → エビデンス収集
2. REPORT.mdに「何を・なぜ・どう変えた」「テスト結果」「確認項目」をまとめる
3. `npx yunomi .artifacts/<feature>/REPORT.md` でフォアグラウンド起動
4. ユーザーがブラウザで確認 → Approve/Request Changes

### 禁止事項
- `git diff | yunomi --diff` でコード差分だけ見せる
- AIエージェント（yunomi-plugin:review-code-security等）にレビューさせる
- お膳立てなしでいきなりyunomiを開く

## 完了フロー（必須）

**実装が終わったら必ずskillを実行してユーザー承認を得ること。**

| 変更規模 | 使うskill | 説明 |
|---|---|---|
| 小さな修正・バグ修正 | `/tiny-done` | ビルド → スクショ/テスト結果 → openで開く → ユーザー承認 |
| 大きな機能・複数ファイル変更 | `/done` | ビルド → 検証 → REPORT.md作成 → yunomiで開く → ユーザー承認 |

- **skillを実行せずに「完了しました」と言うのは禁止**
- 判断に迷ったら `/tiny-done` でOK（軽量で速い）

## コミット・プッシュのルール

- 実装は1/3、テストで2/3、私が承認したら3/3です
- **コミット前には必ずユーザー承認が必要**
- 「コミットしてよいですか？」と聞くのは禁止 → 確認用のreviewを開いて承認を待つ
- 「ご自身で確認されますか？」と聞くのも禁止 → 確認はフォアグラウンドでyunomiを開いて行う
- 承認なしでcommit/push禁止
