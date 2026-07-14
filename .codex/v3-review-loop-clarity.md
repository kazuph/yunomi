# Round to Review Loop clarity task

## Original user feedback

`左のサイドバーのRound to Review Loopというのがあるのですが、パッと見で言うと何がどう変わっているのか全く分かりません。例えばBeforeに表の先頭のようなファイル、行、コード、判定という風なのが書いてあるのにAfterで過剰書きに変わっています。丸っきり変わっていて、あんちょこやっていう状態です。これもっと分かりやすく表示できないんでしょうか。つまりこの差分の意図が分からないので解決しようがありません。そもそも私の指示、指示による意図も分からないし、あなたの修正意図も分からないので、リゾルブの仕様がないという感じです。`

`タブ表示だとぐちゃぐちゃになってる。 また、サブミットボタンがないyunomiが開いている`

`このチェックなに？？`

`HTLMプレビューの時に、submitボタンがでない。致命的。`

`君が表示している、湯呑みで表示しているものを修正するたびに、私がまだ開いている湯呑みでサブミットだったりコメントを書いていたとしても、リロードが走ってそのダイアログが消えて入力が台無しになるという大問題があるので、そちらも修正してください。プレビューの内容は変わるけど、入力に影響しないようにお願いします。`

`あと submit のダイアログ、これは前からある問題なのですが、キャンセルボタンを押さない限り消えません。submit 以外、submit のダイアログ以外を触った場合に submit ダイアログを閉じてください。もちろん内容はそのままにしてください。`

`あと submit を押した時にタブがそのまま消えるべきです。閉じられるべきです。そうなるようにお願いします。`

`GitHubの概念に慣れているため、diffで実際に指示があった箇所をインラインで展開して表示されるべきです。サイドバーに寄せるのはやめましょう。情報が失われて見づらくなっています。コメントを書いたら、そこの部分にそのコメントが表示され続けるべきです。現状それができていないという問題があると感じました。`

## Goal

Round to Review Loop must tell a reviewer, before resolving anything:

1. Which submitted comment or reviewer request created the round.
2. What the implementer intended to change.
3. A focused before/after representation of the changed source, not unrelated document regions.
4. The concrete condition for resolving the item.
5. Normal review pages must retain a visible submit action; read-only share must be clearly isolated.
6. Multi-file tabs must fit without overlap or clipping at supported viewport widths.
7. The file-level viewed control must state that it records review completion and expose its current state in visible text and accessible labeling.
8. HTML preview must always expose a working Submit & Exit action that opens the final decision flow; this must have browser E2E coverage.
9. Preview changes must not erase an in-progress comment, comment card, submit modal, question modal, or typed form input. Preview content may refresh, but active review input must remain usable without recovery steps.
10. A click outside Submit Review closes it without using Cancel, and reopening preserves its typed summary and comments.
11. Final submit closes the review tab; where the browser refuses window close, it must immediately navigate to `about:blank` rather than retain a dead review page.
12. Review-loop requests must render inline next to the source or diff line they refer to, not in a separate sidebar.
13. Saved comments must remain visibly attached inline at the commented source or diff location after saving and after reload.

## Constraints

- Work only in `/Users/kazuph/src/github.com/kazuph/yunomi`.
- Use existing MoonBit/UI patterns and make the smallest coherent change.
- Add or update permanent E2E under `v2/e2e/`; do not mock or skip behavior.
- Do not commit, push, delete unrelated files, deploy, or modify external systems.
- Validate with the relevant E2E and `npm test` before reporting completion.
- Update `.artifacts/v3-plan/REPORT.md` with the original feedback, response, and evidence.
- Start the current built yunomi with `サンプル.md` before re-review.

## Roles

- Implementer may edit only task-relevant product code/tests/report evidence. No commit/push.
- Advisor is read-only and reviews the final diff for missing user-facing semantics, regression risk, and test gaps.
- Manager owns final integration, verification, yunomi launch, and user-facing report.

## Persistence

After context compaction, pane restart, or unclear state, read this file first.
