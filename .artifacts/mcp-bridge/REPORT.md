# Task Card 2.5 MCP Bridge

元の依頼: v3 PLAN の Phase 2 Agent Interop として、`yunomi mcp` で review 状態取得・コメント追加・ラウンド更新を MCP ツールとして公開する。

## 未達・未確認

- 未達なし。
- 実クライアントへの登録作業は行っていない。今回の範囲は `yunomi mcp` の stdio MCP サーバー実装と protocol E2E。
- `draft_comment_count` の既存 unused warning は残存。

## 達成

- `yunomi mcp` サブコマンドを追加した。
- MCP stdio の `Content-Length` framed JSON-RPC を受け付ける。
- `initialize` / `tools/list` / `tools/call` に対応した。
- MCP ツールを3つ公開した。
  - `yunomi_review_state`: 現在 branch の `review.json` を返す。
  - `yunomi_add_comment`: file/line/text/author を受け取り、周辺行 context 付きコメントを `review.json` に追加する。
  - `yunomi_go`: 起動中サーバーがあれば `go.signal` で通知し、なければ `review.json` の次ラウンドを準備する。
- `YUNOMI_REVIEW_DIR` を尊重するため、E2E や agent runtime から isolated review store を使える。

## 検証

- `moon build --target js --release`
- `node --experimental-strip-types e2e/mcp_bridge.ts`
- 結果:
  - MCP initialize: PASS
  - tools/list: PASS
  - add_comment writes review.json: PASS
  - review_state returns structured context: PASS
  - go is idempotent while current round is open: PASS
  - `MCP bridge E2E: 5 passed, 0 failed`

## サンプル

- `サンプル.md` に 2.5 mcp-bridge の確認項目を追加した。
