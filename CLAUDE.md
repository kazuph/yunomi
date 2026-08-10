# yunomi プロジェクト固有ルール

## 開発・テスト時のサーバー起動

yunomiを起動する前に通知経路を実行時に取得・検証する。Herdrを先に試し、失敗した時だけ検証済みtmux adapterを評価する。

```bash
if PANE_ID="$(herdr pane current 2>/dev/null | jq -er '.result.pane.pane_id')" &&
   herdr pane get "$PANE_ID" >/dev/null 2>&1; then
  YUNOMI_ROUTE=herdr
elif [ -n "${TMUX:-}" ] && [ -n "${YUNOMI_NOTIFY_CMD:-}" ]; then
  TMUX_PANE_ID="$(tmux display-message -p '#{pane_id}')" || exit 1
  test "$(tmux display-message -p -t "$TMUX_PANE_ID" '#{pane_id}')" = "$TMUX_PANE_ID" || exit 1
  YUNOMI_ROUTE=tmux
else
  echo "no proven yunomi notification route" >&2
  exit 1
fi
```

- Herdr経路の書込み可能レビューは、自分で確認する場合もユーザーにレビューさせる場合も、必ず `--loop --notify-pane "$PANE_ID"` を付ける。
- 純tmux経路は、事前検証済みの `YUNOMI_NOTIFY_CMD` が設定されている場合だけ `--loop` で起動する。`yunomi share` はread-only例外。
- Claude CodeはBashツールの `run_in_background: true` で起動し、exitを検知する。
- Herdr経路で`--notify-pane`が無い起動、通知経路を実行時に証明できない起動、記憶やfocused paneから通知先を推測する起動は禁止。
- 通知先を証明できない場合は、yunomiを起動せずfail closedで報告する。
- `--notify-pane` はHerdr pane専用。tmuxの`%pane`を渡さず、その場でraw `tmux send-keys` fallbackを作らない。Herdrが使えない純tmux環境は、安全なキュー配送と到達性を事前検証済みの `YUNOMI_NOTIFY_CMD` がある場合だけ `--loop` で起動し、それ以外はfail closedにする。
- ユーザーが「開いて」と明示した場合は、最終ビルドを使うサーバーの `healthz` と対象UIを確認してから、macOSの `open http://127.0.0.1:<port>/` で操作可能な画面を開き、ユーザーの確認が終わるまでサーバーを維持する。スクリーンショットだけを開いて代用してはいけない。明示依頼がない自動起動では、yunomi自身のブラウザ起動を使ってよい。

## この環境のyunomi更新

yunomi本体・UI・生成Skillの確定変更は、ソース変更やMoonBit buildだけで完了扱いにしない。必ず現在のリポジトリから配布物を作り、このMacの標準CLIへ置き換えて実物を検証する。

```bash
npm run prepack
mise exec node@22.22.0 -- npm install -g "$PWD"
shasum -a 256 dist/server/server.js \
  /Users/kazuph/.local/share/mise/installs/node/22.22.0/lib/node_modules/yunomi/dist/server/server.js
yunomi --version
```

- 2つのserver.jsのSHA-256が一致しない状態で完了報告しない。
- 生成Skillを変更した場合は、`yunomi install <agent> --global` でclaude / codex / cursor / opencode / cline / geminiへ再配布し、各ファイルの存在と通知経路契約を再確認する。
- 赤テスト用の途中状態はインストールしない。対象E2Eとrelease buildを通過した確定buildだけを標準CLIへ置き換える。

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
3. 証明済みpaneを渡し、`npx yunomi .artifacts/<feature>/REPORT.md --loop --notify-pane "$PANE_ID"` を `run_in_background: true` で起動
4. ユーザーがブラウザで確認 → Approve/Request Changes

### 禁止事項
- `git diff | yunomi --diff` でコード差分だけ見せる
- AIエージェント（yunomi-plugin:review-code-security等）にレビューさせる
- お膳立てなしでいきなりyunomiを開く
- `--notify-pane` を省略して、人間のコメント・チェックボックス・判定が起動元エージェントへ戻らない状態でレビューを始める

## 完了フロー（必須）

**実装が終わったら必ずskillを実行してユーザー承認を得ること。**

**修正後は、スクリーンショットや静的テスト結果だけで承認待ちにしてはいけない。最終ビルドを実際に起動し、`healthz` と対象UIの表示を確認したうえで、ユーザーがその場で操作できるブラウザ画面を開いた状態にする。操作可能な画面を開けない場合は完了扱いにせず、未達として報告する。**

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
