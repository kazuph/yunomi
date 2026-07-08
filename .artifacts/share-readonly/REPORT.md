# Task Card 3.1 Share Read-only

元の依頼: v3 PLAN の Phase 3 Collaboration として、`yunomi share` でレビューの読み取り専用共有URLを明示操作時のみ提供し、デフォルトは127.0.0.1のローカル完結を維持する。

## 未達・未確認

- 未達なし。
- 外部トンネルや外部サービス送信は実装していない。今回の共有はローカルHTTPサーバーで、外部公開は利用者が明示的に `--host 0.0.0.0` 等を指定した場合だけ。
- `draft_comment_count` の既存 unused warning は残存。

## 達成

- `yunomi share <file...>` サブコマンドを追加した。
- デフォルト bind は既存どおり `127.0.0.1` のまま維持した。
- `--host` / `--port` / `--no-open` / `--encoding` を明示指定として受け付ける。
- 共有ページに read-only banner を表示し、コメント・Submit・復元モーダルなどの操作UIを非表示にした。
- share mode では `/comment` / `/exit` など全POSTを `405 {"error":"read_only_share"}` で拒否する。
- share mode では `.yunomi/reviews/.../server.json` を書かない。
- 複数ファイル共有でも `?f=N` file switcher を維持する。

## 検証

- `herdr run --label share-readonly-verify --cwd .../feature/share-readonly/v2 --close-on-success -- bash -lc 'moon test --target js && moon build --target js --release && node --experimental-strip-types e2e/share_readonly.ts && node --experimental-strip-types e2e/smoke.ts'`
- 結果:
  - `moon test --target js`: `Total tests: 181, passed: 181, failed: 0`
  - `moon build --target js --release`: PASS
  - `e2e/share_readonly.ts`: `Share read-only E2E: 10 passed, 0 failed`
  - `e2e/smoke.ts`: `Results: 134 passed, 0 failed`

## 個別E2E内訳

- `node --experimental-strip-types e2e/share_readonly.ts`
- 結果:
  - share command announces a read-only URL: PASS
  - markdown/second file GET: PASS
  - read-only banner / marker / hidden controls: PASS
  - multi-file switcher: PASS
  - `/comment` POST reject: PASS
  - `/exit` POST reject: PASS
  - no review server metadata write: PASS
  - `Share read-only E2E: 10 passed, 0 failed`

## サンプル

- `サンプル.md` に 3.1 share-readonly の確認項目を追加した。
- `herdr run --label sample-share-readonly-live ...` で `http://127.0.0.1:5897/` を起動し、Chrome で開いた。
