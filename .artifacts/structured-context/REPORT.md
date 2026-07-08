# Task Card 2.6 Structured Context

元の依頼: v3 PLAN の Phase 2 Agent Interop として、コメントYAML/JSONに周辺行スニペット・DOMセレクタ・添付画像パスを含め、agent が探さずに直せる情報密度にする。

## 未達・未確認

- 未達なし。
- DOM selector / bounds は既存の live/html preview YAML で出力済みのため、今回の変更は通常ファイル submit YAML と review.json の周辺行・画像パス強化に絞った。
- `draft_comment_count` の既存 unused warning は残存。

## 達成

- submit YAML の各コメントに `context.before` / `context.after` を出力するようにした。
- submit YAML の画像付きコメントに、保存済みファイルの `image_path` を出力するようにした。
- `review.json` に保存する submit コメントにも `image_path` を含めるようにした。
- 複数ファイル YAML でも `value` / `context` / `image_path` を出力するようにした。
- HTML/live preview の selector / bounds 出力は既存挙動を維持した。

## 検証

- `moon test --target js`: 181 passed, 0 failed
- `moon build --target js --release`: OK
- `node --experimental-strip-types e2e/smoke.ts`: 134 passed, 0 failed
- `node --experimental-strip-types e2e/review_loop.ts`: PASS
- `node --experimental-strip-types e2e/send_now.ts`: 6 passed, 0 failed
- `node --experimental-strip-types e2e/mcp_bridge.ts`: 5 passed, 0 failed

## サンプル

- `サンプル.md` に 2.6 structured-context の確認項目を追加した。
