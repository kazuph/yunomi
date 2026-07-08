# Task Card 3.5 Report Templates

元の依頼: v3 PLAN の Phase 3 Collaboration として、`yunomi init --template <name>` でレビューテンプレートを生成できるようにする。

## 未達・未確認

- 未達なし。
- `draft_comment_count` の既存 unused warning は残存。

## 達成

- `yunomi init --template default|bugfix|feature` が `.artifacts/<feature>/REPORT.md` を生成する。
- `--list-templates` が組み込みテンプレートと `~/.yunomi/templates/*.md` のユーザー定義テンプレートを一覧する。
- `--json` が `init` と `--list-templates` の両方で使える。
- 既存の `REPORT.md` がある場合は上書きせず exit 1 で止まる。
- テンプレート内の `{{title}}` / `{{feature}}` / `{{template}}` / `{{timestamp}}` を置換する。

## 検証

- `herdr run --label init-template-build-e2e3 --cwd .../feature/report-templates/v2 --close-on-success -- bash -lc 'moon test --target js && moon build --target js --release && node --experimental-strip-types e2e/init_template.ts'`
- 結果:
  - `moon test --target js`: 181 passed, 0 failed
  - `moon build --target js --release`: PASS
  - `Init template E2E`: 7 passed, 0 failed
- `herdr run --label init-template-verify --cwd .../feature/report-templates/v2 --close-on-success -- bash -lc 'moon test --target js && moon build --target js --release && node --experimental-strip-types e2e/init_template.ts && node --experimental-strip-types e2e/smoke.ts'`
- 結果:
  - `moon test --target js`: 181 passed, 0 failed
  - `moon build --target js --release`: PASS
  - `Init template E2E`: 7 passed, 0 failed
  - `smoke`: 134 passed, 0 failed

## サンプル

- `サンプル.md` に 3.5 report-templates の確認項目を追加した。
- `herdr run --label sample-report-templates-live --cwd .../feature/report-templates -- bash -lc 'cd v2 && moon build --target js --release >/tmp/yunomi-sample-report-templates-build.log && cd .. && node v2/_build/js/release/build/server/server.js サンプル.md --host 127.0.0.1 --port 5901 --no-open'`
- `http://127.0.0.1:5901/` を Chrome で開いた。
- `lsof -nP -iTCP:5901 -sTCP:LISTEN`: node process が `127.0.0.1:5901` で LISTEN。
