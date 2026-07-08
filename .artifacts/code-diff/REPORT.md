# Phase 1-4 コードdiff強化

**一言でいうと**: diff review にファイルツリー、Unified / Split 切替、viewed checkbox を追加し、diff をレビューセッションの中で追いやすくした。

## Review Focus

Diff 画面で changed file が左ペインに並び、Unified / Split の切替が localStorage に保存され、viewed checkbox がファイルブロックにも反映されることを確認してください。`git diff | yunomi` の stdin diff でも同じ UI が出ます。

## User Request ⇄ Response

| Round | User Request (原文) | Response | 検証方法 |
|---|---|---|---|
| 1 | v3 PLANを全部実装するまで止まらないで。ただし、都度都度実装したyunomiを使ってサンプル.mdは開いてください。 | Task Card 2.3 の diff UI 強化を実装し、built yunomi で `サンプル.md` を開いた。 | `moon test` / `moon build` / `code_diff_enhance.ts` / `feature_matrix_regression.ts` / built server で `サンプル.md` |

## WHY

v3 の `yunomi review` は複数ファイルを扱うため、diff 画面が単なる縦長テキストのままだと、どのファイルを見たか、old/new のどちらを読んでいるか、次にどこへ進むかが見えにくい。

## HOW

`build_diff_html` が diff file tree と toolbar を出すようにし、各 diff line は unified 表示用 content と split 表示用 old/new content を持つようにした。UI 側は diff 専用の初期化 FFI で localStorage を読み書きし、mode と viewed 状態を復元する。

## WHAT

| Area | Change |
|---|---|
| Diff tree | `.diff-file-tree` に変更ファイル一覧と viewed checkbox を表示 |
| View mode | `#diff-unified-toggle` / `#diff-split-toggle` を追加し、`body.diff-split` で split view へ切替 |
| Persistence | `yunomi:diff-view:<filename>` と `yunomi:diff-viewed:<filename>` に localStorage 保存 |
| Split markup | 各 `.diff-line` に `.old-content` / `.new-content` を追加 |
| E2E | `v2/e2e/code_diff_enhance.ts` で file tree、split persistence、viewed persistence、stdin diff を検証 |
| Regression | `feature_matrix_regression.ts` も継続 green |

## Evidence

| Check | Result |
|---|---|
| `moon test --target js` | `Total tests: 180, passed: 180, failed: 0.` |
| `moon build --target js --release` | `Finished. moon: ran 2 tasks, now up to date (1 warnings, 0 errors)` |
| `node --experimental-strip-types e2e/code_diff_enhance.ts` | `Code diff enhance E2E: 10 passed, 0 failed` |
| `node --experimental-strip-types e2e/feature_matrix_regression.ts` | `Results: 21 passed, 0 failed` |
| `git diff --check` | no output |

## Remaining Notes

`viewed` はこのカードでは localStorage 永続化として実装した。PLAN の「review.json 統合」は構造化コンテキストや meta command と schema をそろえる後続カードで扱う余地を残している。
