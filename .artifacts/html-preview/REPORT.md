# Phase 1-3 静的HTMLプレビューレビュー

**一言でいうと**: `yunomi <file>.html` で静的 HTML を sandboxed iframe に表示し、DOM 要素へ selector / bounds 付きコメントを残せるようにした。

## Review Focus

HTML file を通常の text preview としてではなく iframe preview として開けること、相対アセットが同一ディレクトリから配信されること、submit YAML に `mode: html` / `selector` / `bounds` が入ることを見てください。

## User Request ⇄ Response

| Round | User Request (原文) | Response | 検証方法 |
|---|---|---|---|
| 1 | v3 PLANを全部実装するまで止まらないで。ただし、都度都度実装したyunomiを使ってサンプル.mdは開いてください。 | Task Card 2.2 の HTML preview を実装し、built yunomi で `サンプル.md` を開く流れに組み込んだ。 | `moon test` / `moon build` / `html_preview.ts` / `feature_matrix_regression.ts` / built server で `サンプル.md` |

## WHY

静的 HTML は Markdown 内 HTML とは違い、実際の CSS / 画像 / JS と組み合わせて画面としてレビューされる。v2 の text fallback では DOM 要素のどこに指摘しているのかを表現できず、LP や生成 HTML のレビューで selector / bounds が欠けていた。

## HOW

`FileMode::Html` を追加し、`*.html` / `*.htm` だけ専用の HTML preview server に分岐した。親ページは `sandbox="allow-scripts allow-same-origin"` の iframe を持ち、iframe target には `yunomi live` と同系統の overlay を注入する。

相対アセットは reviewed HTML の同一ディレクトリを base にして配信し、path traversal は `path.relative` で base 外を拒否する。

## WHAT

| Area | Change |
|---|---|
| Mode detection | `FileMode::Html` と `html` / `htm` 拡張子判定を追加 |
| Server | `start_html_preview_server` を追加し、iframe shell / target HTML / relative assets / `/exit` を提供 |
| Comment output | HTML preview submit YAML に `mode: html`、各 comment の `selector` / `value` / `bounds` を出力 |
| E2E | `v2/e2e/html_preview.ts` で iframe shell、sandbox policy、asset 200、YAML fields を検証 |
| Regression | `package.json` の `test:v2` に `html_preview.ts` を追加 |

## Evidence

| Check | Result |
|---|---|
| `moon build --target js --release` | `Finished. moon: ran 2 tasks, now up to date` |
| `node --experimental-strip-types e2e/html_preview.ts` | `HTML preview E2E: 17 passed, 0 failed` |
| `git diff --check` | no output |

## Remaining Notes

HTML preview は file mode 専用の server として実装した。通常 Markdown / CSV / diff / text server への変更面を広げず、v3 後続の構造化コンテキスト統一で schema をまとめる前提にしている。
