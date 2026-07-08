# Task Card 3.2 GitHub PR Sync

元の依頼: v3 PLAN の Phase 3 Collaboration として、GitHub PRコメントと yunomi コメントを `yunomi pull / push` で双方向同期する。

## 未達・未確認

- 本物の GitHub PR への投稿はこの検証では実行していない。E2E は fake `gh` CLI で、呼び出し引数と `review.json` 更新を検証している。
- GitHub 側の outdated / resolved / multi-line review comment の完全再現は未実装。今回扱うのは通常の PR review comment と threaded reply。
- `draft_comment_count` の既存 unused warning は残存。

## 達成

- `yunomi pull [pr-number|url]` を追加した。
- `gh repo view` と `gh pr view` から owner/repo/PR/head SHA を取得する。
- `gh api repos/{owner}/{repo}/pulls/{pr}/comments --paginate` の結果を `.yunomi/reviews/<branch>/review.json` に取り込む。
- GitHub comment は `id: gh-<comment_id>` と `github.comment_id/html_url/...` メタデータ付きで保存する。
- GitHub threaded reply は対応する yunomi comment の `replies[]` に保存する。
- `yunomi push [pr-number|url]` を追加した。
- `review.json` 内の `github.comment_id` 未設定コメントだけを GitHub PR review-comment API に送る。
- push 成功後、ローカルコメントに `github.comment_id/html_url/pushed_at` を記録し、再pushで重複投稿しない。

## 検証

- `herdr run --label pr-sync-build-e2e3 --cwd .../feature/pr-sync/v2 --close-on-success -- bash -lc 'moon build --target js --release && node --experimental-strip-types e2e/github_pr_sync.ts'`
- 結果:
  - `moon build --target js --release`: PASS
  - `GitHub PR sync E2E: 7 passed, 0 failed`
- `herdr run --label pr-sync-verify --cwd .../feature/pr-sync/v2 --close-on-success -- bash -lc 'moon test --target js && moon build --target js --release && node --experimental-strip-types e2e/github_pr_sync.ts && node --experimental-strip-types e2e/mcp_bridge.ts && node --experimental-strip-types e2e/send_now.ts && node --experimental-strip-types e2e/review_loop.ts && node --experimental-strip-types e2e/smoke.ts'`
- 結果:
  - `moon test --target js`: `Total tests: 181, passed: 181, failed: 0`
  - `GitHub PR sync E2E: 7 passed, 0 failed`
  - `MCP bridge E2E: 5 passed, 0 failed`
  - `Send now E2E: 6 passed, 0 failed`
  - `review loop e2e`: PASS
  - `smoke.ts`: `Results: 134 passed, 0 failed`
- `node --experimental-strip-types e2e/github_pr_sync.ts`
- fake `gh` で検証した内容:
  - `pull` が GitHub review comment を yunomi comment として保存する: PASS
  - `pull` が GitHub metadata を保存する: PASS
  - `pull` が threaded reply を yunomi replies に変換する: PASS
  - `push` が未同期 yunomi comment を送信する: PASS
  - `push` が GitHub metadata をローカルに反映する: PASS
  - `push` が `body/path/line/side/commit_id` を GitHub PR review-comment API に渡す: PASS

## サンプル

- `サンプル.md` に 3.2 github-pr-sync の確認項目を追加する。
- `herdr run --label sample-pr-sync-live ...` で `http://127.0.0.1:5898/` を起動し、Chrome で開いた。
