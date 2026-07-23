| 出典 | 目的 | 具体対象 | 役割 | 前後関係 | 初出定義 | 候補語 |
|---|---|---|---|---|---|---|
| 実ブラウザ再現 `disabled=true`、`cursor=pointer`、`opacity=1` | Approveを押せない理由を操作前に理解できるようにする | 過去ラウンドの未解決コメントが残っているため承認を確定できない理由 | 値 | Submit Reviewを開いた後、Approveを押す前 |  | 承認できない理由 |
| `/review-state` の `gate_unresolved_count` | 解決すべき量を具体的に示す | 承認を妨げている過去ラウンドの未解決コメント件数 | 値 | review state取得後、Submit Review表示時 |  | 未解決件数 |
| Review itemsの未解決カード | ユーザーが承認可能な状態へ戻れるようにする | 最初に確認・Resolveすべき未解決コメントの表示位置 | 目的 | 承認できない理由を理解した後 |  | 解決先 |
| Submit ReviewのApprove領域 | 原因と回復操作を同じ視線範囲に置く | 無効状態のボタン文言・視覚表現・未解決項目へ移動する操作 | 手段 | Submit Review表示中 |  | 承認ゲート表示 |
| 承認ゲート表示 | Approveの無効理由を支援技術を含めて伝える | 未解決件数を含む説明領域 | 表示 | Submit Review表示後、Approve操作前 | `approve-blocked-reason` | 承認不可理由表示 |
| 解決先 | 承認可能な状態へ戻る操作を開始する | モーダルを閉じて最初の未解決コメントへスクロール・フォーカスするボタン | 操作 | 承認不可理由の確認後 | `review-unresolved-action` | 未解決項目確認操作 |
| ブラウザの言語設定 | 既存のreview-loop表示と同じ条件で新しい説明文の言語を選ぶ | `navigator.language` が日本語で始まるか | 条件 | Submit Reviewの説明文生成前 | `is_japanese_locale` | 日本語ロケール条件 |
