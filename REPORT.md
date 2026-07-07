# feature/agent-interop report

## チェックボックス式AskUserQ

依頼:

> AskUserQに相当するものも、チェックボックスで選択させる。一度それをAIが受け取ったら、ヒアリング用の `- [ ]` の箇条書きじゃなくて、決定状態の `- ✅️` の箇条書きに代える。そういう運用。

### Why

人間がREPORT内の選択肢をチェックしても、AI側へ即時に伝わらず、Markdown上にも選択状態が残らないと、質問への回答がレビュー提出まで埋もれます。さらに、選択済みの項目が `- [ ]` のまま残ると、AIが次にファイルを読んだ時に「まだ未決定」と誤認します。

### How

Markdownのtask listを操作可能なcheckboxとして描画し、変更時に `POST /decision` へ送ります。serverは該当行の `[ ]` / `[x]` だけを置換し、review.jsonの `decisions` 配列へ `{id, file, line, text, checked, decided_at}` を保存し、SSEと `YUNOMI_NOTIFY_CMD` または `herdr agent send` でAIへ通知します。

AI側の運用はskill文書にも追加しました。ヒアリングは `- [ ]`、通知を受けたらAIが該当行を `- ✅️ 決定内容` に書き換え、`- [ ]` のまま放置しません。`- ✅️` 行はプレビューで `decision-done` classとして控えめに強調されます。

### What

- `v2/src/core/markdown.mbt`: task list checkboxを操作可能化し、`- ✅️` を決定済みclassで描画。
- `v2/src/ui/app.mbt`: checkbox変更時に `/decision` へPOST。
- `v2/src/server/main.mbt`: `/decision`、md行置換、review.json decisions保存、SSE、AI通知、skill文書を追加。
- `v2/e2e/checkbox_decision.ts`: HTTPレベルでHTML/JS配信、md書き換え、SSE、通知、review.json保存を検証。

### Verification

- `cd v2 && moon test --target js`: 180 passed
- `cd v2 && moon build --target js --release && node --experimental-strip-types e2e/agent_interop_comment.ts && node --experimental-strip-types e2e/checkbox_decision.ts`: both PASS
- `npm run prepack`: success

### 親代行証跡枠

- `npm test`: 親代行
- 実環境デモ: 親代行
- commit: 親代行
