| 出典 | 目的 | 具体対象 | 役割 | 前後関係 | 初出定義 | 候補語 |
|---|---|---|---|---|---|---|
| review.json実データとユーザー指摘「未解決項目が4件のまま」 | 開いているファイルで解決できる指摘だけを件数・承認ゲートへ反映する | 現在表示中のrepo相対パスと一致し、scopeがroundではなくstatusがresolvedでないコメントの集合 | 状態 | review.json読取後、画面描画と承認可否判定前 | 現在ファイルの未解決項目とは表示中ファイルに属し、人間がその画面で解決できる未解決コメントを指す | current-file unresolved comments |
| ユーザー指摘「解決してもずっと4件を維持してる」 | 解決操作の直後に同じ画面で件数とカードを更新し、スクロールを動かさない | 解決後のreview-stateを送って再描画するSSE通知 | 事象 | resolve-comment保存後、ブラウザの件数再描画前 | resolveイベントとは解決済み状態だけを画面へ反映し、ページ再読込を起こさない通知を指す | resolve |
| ユーザー指摘「Comment 0件という表示もおかしい」 | 未送信のローカル入力と保存済みレビュー会話を同じComments件数に見せない | 送信前でpendingのローカルコメント数を表示し、その一覧を開く上部ボタン | 値 | 本文で新規コメントを入力後、Submitで送信する前 | Draftsとはまだreview.jsonへ送信されていないローカルコメントを指す | Drafts |
| share URLのトークン検証と会話添付の保存 | 共有URLを知らない第三者へレビュー状態・履歴・添付を返さない | shareモード中にHTML以外のGETへ適用するquery token検証 | 条件 | GETリクエスト受信後、review.json・history・静的ファイル読取前 | share GET認証とは起動時に発行したtokenとqueryのtokenが一致する条件を指す | share GET authentication |
| package version 2.4.0とMCP initialize | npm公開物とMCPクライアントへ返す自己申告を一致させる | initialize結果のserverInfo.version | 値 | MCP initialize要求受信後、応答生成時 | MCP server versionとは実行中npmパッケージと同じ公開版を指す | 2.4.0 |
| フルE2E中に本文未変更の同一ページへreloadが発生した実測 | 本文の保存だけをhot reloadへ結び、同じ内容のwriteやファイル属性変化で編集中画面を再読込しない | 現在のファイル全体から計算したSHA-256と直前値が異なる監視通知 | 条件 | fs.watchFile通知後、HTML再生成とreload SSE送信前 | 本文変更とはファイルのバイト列が直前の読取結果と異なることを指す | file content change |
| 同上 | ファイル属性ではなく本文そのものの同一性を比較する | ファイル全体のSHA-256文字列 | 値 | 監視開始時と各fs.watchFile通知時 | 本文署名とは現在のファイル全体をSHA-256へ変換した比較値を指す | file content signature |
| 複数ファイル起動時に各contextが同じgo.signalへ空文字を書き、先に起動したcontextが新ラウンドと誤認した実測 | 実際のyunomi goだけを新ラウンド開始へ結ぶ | go.signal全体のSHA-256が直前値と異なる監視通知 | 条件 | go.signalのfs.watchFile通知後、start_next_review_round実行前 | goシグナル変更とはgo.signalの内容が直前の読取結果と異なることを指す | go signal change |
| フルE2EでサーバーAの最初のSSE hello前に停止すると、同一ポートのサーバーBを初回接続と誤認した実測 | 通信到着順に依存せず、同一ポートを再利用した別レビューへ旧タブを参加させない | HTML生成時に埋め込まれたサーバーinstance ID | 状態 | ページ初期化後、EventSource接続とhello受信前 | 現在サーバーinstanceとは表示中HTMLを生成したサーバープロセスのIDを指す | current server instance |
