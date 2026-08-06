# 同名 `REPORT.md` のコメント下書きを絶対パス単位に分離

> 「はい、直して。REPROT.mdって別のdirに何個もあるので。」

## Why

コメント下書きのlocalStorageキーが `yunomi:comments:REPORT.md` のようにファイル名だけで作られていたため、同じlocalhostポートを再利用すると、別ディレクトリの同名 `REPORT.md` に以前の下書きが現れていました。

## How

画面表示やサーバー送信に使うファイル名は変えず、ブラウザ保存専用の識別子として解決済み絶対パスをHTMLへ渡しました。コメント下書き、リロード状態、返信キャッシュ、diff表示状態など、ファイル別のlocalStorageキーはこの識別子を共通利用します。

古いファイル名だけのキーは、別ファイルの内容か判定できないため自動移行しません。

## What

- `/first/REPORT.md` は `yunomi:comments:/first/REPORT.md`
- `/second/REPORT.md` は `yunomi:comments:/second/REPORT.md`
- 同じポートを再利用して順番に開いても、1件目の下書きは2件目へ復元されません。
- 追加E2Eを通常の `test:v2` に登録しました。
- 会話の返信textareaも絶対パス・会話ID単位で入力時にlocalStorageへ保存します。
- エージェント返信によるSSE再描画とページ全体のリロード後に未送信テキストを復元し、送信成功時だけ削除します。
- 新規インラインコメントの永続IDも `絶対パス|位置` とし、別ファイルの同じ行・列に残る過去コメントとの衝突を防ぎます。

## Verification

- `npm run build`: 成功。既存の未使用関数警告5件、エラー0件。
- `moon test --target js`: 190/190成功。
- `storage_scope_isolation.ts`: 同じポートで別ディレクトリの同名 `REPORT.md` を順番に開き、キー分離と誤復元なしを実ブラウザで確認。
- `code_diff_enhance.ts`: 21/21成功。
- `send_now.ts`: 20/20成功。
- `preview_interaction_regression.ts`: 12/12成功。
- `review_loop.ts`: 入力中のSSE再描画、ページリロード、送信後削除を含めて成功。
- `send_now.ts`: パス付きIDでの即時保存、エージェント返信、再読込後の単一表示を確認。
- `inline_comments.ts`: 保存・復元を含む対象項目は成功。ただし今回変更していないエディタ固定幅の既存チェック1件が、期待幅ではなく900pxとなり失敗。単独再実行でも同じ結果で、CSSや幅の期待値はこの修正では変更していません。
