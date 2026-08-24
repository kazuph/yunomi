| 出典 | 目的 | 具体対象 | 役割 | 前後関係 | 初出定義 | 候補語 |
|---|---|---|---|---|---|---|
| ユーザー質問「今ってherdr対応されている？」 | 現行実装でHerdr通知を利用できるか答える | yunomiから起動元Herdr paneへレビュー情報を届ける処理 | 手段 | yunomi起動後、レビュー操作時 |  | Herdr通知 |
| ユーザー質問「コメントすると都度送信？」 | コメント操作ごとの通知タイミングを答える | コメント本文を保存する操作 | 事象 | コメント入力後、即時送信または最終Submitより前 |  | コメント保存 |
| 現行UIとサーバーAPI | 最終Submitを待たずに個別コメントをAIへ届ける | コメントカードのAdd single comment操作により通知APIを呼ぶ処理 | 事象 | コメント入力後、最終Submitより前 |  | Add single comment |
| 現行サーバー通知処理 | Herdrへ送る条件を答える | `HERDR_PANE_ID`または`--notify-pane`で通知先paneが設定されたプロセスが、実行中Herdrのhelp契約に応じて本家の`herdr agent prompt`またはfork版の`herdr agent send`を実行する条件 | 条件 | 通知処理の実行前 |  | Herdr通知条件 |
| 現行サーバー通知処理 | tmuxへ送る条件を答える | Herdr通知先がなく`TMUX_PANE`があるか、`--notify-tmux-pane`で通知先を明示したプロセスが、対象paneを検証して`tmux send-keys`を実行する条件 | 条件 | 通知処理の実行前 |  | tmux通知条件 |
| ユーザー質問「herdrでyunomiを開いた人自身のIDを特定するの？」 | 通知先の取得元を答える | Herdrが管理paneのプロセス環境へ設定し、yunomi起動プロセスへ継承されるpane ID | 値 | herdr管理paneの生成後、yunomi起動前 | 人のアカウントIDではなく、起動元のHerdr paneを指す値 | 起動元pane ID |
| `--notify-pane` の引数処理 | 自動取得できない起動経路でも通知先を指定する | コマンドラインで明示された通知先pane ID | 値 | yunomi起動時、HERDR_PANE_IDの参照前 |  | 明示通知先pane ID |
