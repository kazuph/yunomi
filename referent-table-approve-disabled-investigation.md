| 出典 | 目的 | 具体対象 | 役割 | 前後関係 | 初出定義 | 候補語 |
|---|---|---|---|---|---|---|
| ユーザー指摘「アプルブボタンが押せない時があります。調査して。」 | Approve 操作を阻む条件を特定する | Submit Review ダイアログの `#modal-approve` がクリックを受け付けない表示状態 | 状態 | Approve ボタンを押そうとしたとき |  | Approve ボタン無効状態 |
| `v2/src/ui/app.mbt` と `/review-state` | UIが Approve 可否を判断する | 現在のレビューで承認を妨げる未解決スレッドの件数 | 値 | review state の取得後、Submit Review ダイアログを開く前 |  | `review_loop_unresolved_count` |
| `v2/src/server/main.mbt` の `POST /exit` | UIを迂回しても未解決スレッド付きの承認を確定させない | 承認要求を HTTP 409 で拒否するサーバー応答 | 事象 | `decision=approve` の受信後、レビュー確定前 |  | Approve 拒否応答 |
