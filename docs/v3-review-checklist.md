# yunomi v3 Review Checklist

このチェックリストは、v3 PLAN の機能をレビュー時に迷わず触るための入口です。ポートは PLAN-v3 5.2 のレビュー用 5900+ 帯を使っています。埋まっていたら `--port` だけ変えてください。

## 先にビルド

```bash
herdr run --label v3-review-build --cwd /Users/kazuph/src/github.com/kazuph/yunomi --close-on-success -- npm run build
```

## 触るURL

0. Review loop / live proxy / agent interop

最初に Markdown demo を起動してから、コメントを保存して `Submit & Exit` を押します。`Send to AI` を選ぶとラウンドを継続でき、`yunomi go` で次ラウンドに進めます。

```bash
herdr run --label v3-demo-markdown --cwd /Users/kazuph/src/github.com/kazuph/yunomi -- node v2/_build/js/release/build/server/server.js サンプル.md --host 127.0.0.1 --port 5910 --no-open
node v2/_build/js/release/build/server/server.js comment サンプル.md:1 "agent interop comment"
node v2/_build/js/release/build/server/server.js reply <comment-id> "agent reply"
```

ライブアプリのピンコメントは、別paneで対象ページを起動してから実行します。

```bash
herdr run --label v3-live-target --cwd /Users/kazuph/src/github.com/kazuph/yunomi -- node examples/v3-live-demo-server.mjs
herdr run --label v3-demo-live --cwd /Users/kazuph/src/github.com/kazuph/yunomi -- node v2/_build/js/release/build/server/server.js live http://127.0.0.1:5915 --host 127.0.0.1 --port 5916 --no-open
```

見ること:
- ライブページ上の要素をクリックして、DOM selector / element text / bounds を持つコメントを作れる。
- `comment` と `reply` の結果が、起動中のレビュー画面へ即時に反映される。
- Submit 時に `Send to AI` を選ぶと review loop を継続できる。

対応E2E: `review_loop.ts`, `realtime_relay.ts`, `live_review.ts`, `agent_interop_comment.ts`, `checkbox_decision.ts`。

1. Markdown / comments / Send now / Vim keys / structured context

```bash
herdr run --label v3-demo-markdown --cwd /Users/kazuph/src/github.com/kazuph/yunomi -- node v2/_build/js/release/build/server/server.js サンプル.md --host 127.0.0.1 --port 5910 --no-open
```

見ること:
- 行または表セルをクリックしてコメントカードが開く。
- `Save` の隣に `Send now` がある。
- `j/k` でレビュー対象を移動し、`c` でコメントカードを開ける。
- Submit YAML と `review.json` の comment に `file`, range, `snippet`, five-line context, DOM fields, and `attachments` の共通schemaが入る。

対応E2E: `send_now.ts`, `vim_keys.ts`, `smoke.ts` の submit context 検証、`table_cell_comment_regression.ts`。

2. 変更ファイル自動検出 / file switcher

```bash
herdr run --label v3-demo-review --cwd /Users/kazuph/src/github.com/kazuph/yunomi -- node v2/_build/js/release/build/server/server.js review HEAD~1 --host 127.0.0.1 --port 5911 --no-open
```

見ること:
- header 直下に file switcher が出る。
- `?f=N` で複数ファイルを同一プロセス内で切り替えられる。
- Git repositoryではbranch diffとstaged / unstaged変更を集める。Gitでないworkspaceでは `jj root`、次に `sl root` を検出して変更ファイルを集める。

対応E2E: `auto_review.ts`、Sapling status path parserのMoonBit unit tests。

3. HTML iframe preview

```bash
herdr run --label v3-demo-html --cwd /Users/kazuph/src/github.com/kazuph/yunomi -- node v2/_build/js/release/build/server/server.js examples/v3-html-preview.html --host 127.0.0.1 --port 5912 --no-open
```

見ること:
- iframe sandbox で HTML が描画される。
- `#cta` button をクリックして HTML element comment が作れる。
- 相対CSS `examples/v3-html-preview.css` が配信される。

対応E2E: `html_preview.ts`。

4. Diff split/unified / file tree / viewed

```bash
herdr run --label v3-demo-diff --cwd /Users/kazuph/src/github.com/kazuph/yunomi -- node v2/_build/js/release/build/server/server.js examples/v3-code.diff --host 127.0.0.1 --port 5913 --no-open
```

見ること:
- file tree が出る。
- Unified / Split toggle が効く。
- viewed checkbox が永続化される。

対応E2E: `code_diff_enhance.ts`。

5. Read-only share

```bash
herdr run --label v3-demo-share --cwd /Users/kazuph/src/github.com/kazuph/yunomi -- node v2/_build/js/release/build/server/server.js share サンプル.md examples/v3-code.diff --port 5914 --no-open
```

見ること:
- stdout に `?share=<token>` 付き URL が出る。
- token なし `/?f=0` は 403。
- token あり URL では read-only banner が出て、comment/submit 操作が隠れる。
- file switcher の `?f=1&share=<token>` で2つ目のファイルに移動できる。
- `--host 0.0.0.0` だけでは起動を拒否し、明示的な `--public` のときだけ公開bindする。

対応E2E: `share_readonly.ts`。

## CLI / agent-facing 機能

6. MCP bridge

```bash
node v2/_build/js/release/build/server/server.js mcp
```

見ること:
- `tools/list` に `mcp__yunomi__list_reviews`, `mcp__yunomi__get_review`, `mcp__yunomi__add_comment`, `mcp__yunomi__advance_round` が出る。
- `mcp__yunomi__resolve_comment` は PLAN 通り未実装、人間限定。

対応E2E: `mcp_bridge.ts`。

7. GitHub PR sync

```bash
node v2/_build/js/release/build/server/server.js pull <pr-url>
node v2/_build/js/release/build/server/server.js push <review-id> <pr-url>
```

見ること:
- pull は GitHub review comments を yunomi comment/reply へ取り込む。
- push は未同期コメントを GitHub PR review-comment API 引数で送る。

対応E2E: `github_pr_sync.ts`。

8. Meta commands

```bash
node v2/_build/js/release/build/server/server.js status --json
node v2/_build/js/release/build/server/server.js stats --json
node v2/_build/js/release/build/server/server.js cleanup --json
```

対応E2E: `meta_cmds.ts`。

9. Report templates

```bash
node v2/_build/js/release/build/server/server.js init --list-templates --json
node v2/_build/js/release/build/server/server.js init --template bugfix
```

対応E2E: `init_template.ts`。

## 全機能E2E

`npm test` は v3 の全レビュー面と横断回帰を実行します。PLAN-v3 5.2 の port fallback も `port_auto_fallback.ts` として含めています。

```bash
herdr run --label v3-full-e2e --cwd /Users/kazuph/src/github.com/kazuph/yunomi --close-on-success -- npm test
```
