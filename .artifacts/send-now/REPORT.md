# Task Card 2.4 Phase 2-1 Send now

元の依頼: v3 PLAN の Task Card 2.4 として、保存済みコメントを最終 Submit 前に agent へ即時送信し、agent 返信を同じレビュー画面に返す。

## 未達・未確認

- 未達なし。
- `draft_comment_count` の既存 unused warning は残存。今回の Send now 実装の失敗ではない。

## 達成

- コメントカードの Save 隣に `Send now` ボタンを追加した。
- `Send now` は `/comment` に `type: "send-now"` と既存 comment key を送信し、SSE `event: send-now` を配信する。
- `send-now` コメントは最終 Submit 前に `review.json` へ `send_now: true` 付きで保存されるため、`yunomi reply <comment-id>` が同じ id に返信できる。
- `/reply-comment` は `event: reply` と既存互換の `event: round` を両方配信する。
- UI は `event: reply` を受け、該当コメント一覧の下に agent reply を inline 表示する。
- text/table/diff viewer にも既存の comment list aside を出すようにし、Markdown 以外でも inline reply の着地点を保証した。

## 検証

- `herdr run --label send-now-verify8 --cwd .../v2 --close-on-success -- bash -lc 'moon test --target js && moon build --target js --release && node --experimental-strip-types e2e/send_now.ts && node --experimental-strip-types e2e/realtime_relay.ts'`
- 結果:
  - `moon test --target js`: 180 passed, 0 failed
  - `moon build --target js --release`: OK
  - `send_now.ts`: 6 passed, 0 failed
  - `realtime_relay.ts`: PASS
- `git diff --check`: clean

## サンプル

- `サンプル.md` に 2.4 send-now の確認項目を追加した。
