# Task Card 3.4 Meta Commands

元の依頼: v3 PLAN の Phase 3 Collaboration として、`yunomi status` / `yunomi stats` / `yunomi cleanup` のメタコマンドを実装する。

## 未達・未確認

- 未達なし。
- `draft_comment_count` の既存 unused warning は残存。

## 達成

- `yunomi status` がレビュー保存ディレクトリから進行中レビューだけを一覧化し、branch / round / unresolved / files / decision を表示する。
- `yunomi stats` が history JSON から過去30日分を集計し、approve 率、平均ラウンド数、平均コメント数を表示する。
- `yunomi cleanup [--older-than <days>]` が古い approved review ディレクトリだけを削除し、進行中・最近 approve 済みの review は保持する。
- 3コマンドすべてで `--json` 出力を提供する。
- submit history に `decision` と `roundCount` を保存し、今後の stats が実レビュー履歴から計算できるようにした。
- `YUNOMI_REVIEW_DIR` / `YUNOMI_HISTORY_DIR` で e2e 用の隔離ディレクトリを使える。

## 検証

- `herdr run --label meta-cmds-build-e2e --cwd .../feature/meta-cmds/v2 --close-on-success -- bash -lc 'moon test --target js && moon build --target js --release && node --experimental-strip-types e2e/meta_cmds.ts'`
- 結果:
  - `moon test --target js`: 181 passed, 0 failed
  - `moon build --target js --release`: PASS
  - `Meta commands E2E`: 14 passed, 0 failed
- `herdr run --label meta-cmds-verify --cwd .../feature/meta-cmds/v2 --close-on-success -- bash -lc 'moon test --target js && moon build --target js --release && node --experimental-strip-types e2e/meta_cmds.ts && node --experimental-strip-types e2e/smoke.ts'`
- 結果:
  - `moon test --target js`: 181 passed, 0 failed
  - `moon build --target js --release`: PASS
  - `Meta commands E2E`: 14 passed, 0 failed
  - `smoke`: 134 passed, 0 failed

## サンプル

- `サンプル.md` に 3.4 meta-cmds の確認項目を追加した。
- `herdr run --label sample-meta-cmds-live --cwd .../feature/meta-cmds -- bash -lc 'cd v2 && moon build --target js --release >/tmp/yunomi-sample-meta-cmds-build.log && cd .. && node v2/_build/js/release/build/server/server.js サンプル.md --host 127.0.0.1 --port 5900 --no-open'`
- `http://127.0.0.1:5900/` を Chrome で開いた。
