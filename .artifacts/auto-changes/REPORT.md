# Phase 1-1 変更ファイル自動検出

**一言でいうと**: `yunomi review [base-ref]` で git の変更ファイルを自動検出し、1 つのサーバーで複数ファイルを切り替えてレビューできるようにした。

## Review Focus

`yunomi review main --no-open --port <port>` が変更済み Markdown / CSV / text を同じサーバー内の `?f=N` で切り替えて表示できること、git 管理外ディレクトリでは exit 1 で止まること、既存の `yunomi <file>` が壊れていないことを見てください。

## User Request ⇄ Response

| Round | User Request (原文) | Response | 検証方法 |
|---|---|---|---|
| 1 | v3 PLANを全部実装するまで止まらないで。ただし、都度都度実装したyunomiを使ってサンプル.mdは開いてください。 | Task Card 2.1 の `yunomi review` を実装し、`サンプル.md` を worktree の built server で開く準備をした。 | `moon test` / `moon build` / `auto_review.ts` / `feature_matrix_regression.ts` / built server で `サンプル.md` |

## WHY

v2 まではレビュー対象を人間またはエージェントが明示的に列挙する必要があり、PR や worktree の実作業から「今見るべきファイル」を作る操作が毎回発生していた。

v3 ではレビューセッションを作業の中心に置くため、変更ファイルの検出と切替表示が CLI の第一級コマンドになっている必要がある。

## HOW

`review` サブコマンドを CLI 分岐へ追加し、git の upstream または `main` を基準に committed / staged / unstaged の ACMR ファイルを重複排除して集める。集めたファイルは同一 port の `ServerContext` 群として保持し、index request の `?f=N` で選択する。

ファイル切替 UI は各ページの header 直下に挿入し、既存の Markdown / CSV / diff / text 生成処理はそのまま使う。

## WHAT

| Area | Change |
|---|---|
| CLI | `yunomi review [base-ref] [--port n] [--no-open] [--host addr]` を追加 |
| Git detection | `git diff --name-only --diff-filter=ACMR <base>...HEAD`、unstaged、staged を順に収集 |
| Review mux | 1 process / 1 port で複数 `ServerContext` を持ち、`/?f=N` でページ HTML を切替 |
| UI | `review-file-switcher` を header 直下に表示し、active file を視覚的に区別 |
| E2E | `v2/e2e/auto_review.ts` を追加し、Markdown / CSV / text / non-git error を確認 |
| Regression | `package.json` の `test:v2` に `auto_review.ts` を追加 |

## Evidence

| Check | Result |
|---|---|
| `moon test --target js` | `Total tests: 180, passed: 180, failed: 0.` |
| `moon build --target js --release` | `Finished. moon: ran 5 tasks, now up to date (1 warnings, 0 errors)` |
| `node --experimental-strip-types e2e/auto_review.ts` | `Auto review E2E: 7 passed, 0 failed` |
| `node --experimental-strip-types e2e/feature_matrix_regression.ts` | `Results: 21 passed, 0 failed` |
| `git diff --check` | no output |

## Remaining Notes

`jj` / `sl` はこの環境で `command -v` が見つからなかったため git path のみ検証済み。PLAN の「無ければ git のみ」に従っている。
