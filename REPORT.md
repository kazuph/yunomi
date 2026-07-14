# yunomi summary 添付画像の stdout 出力修正

## 元の依頼

summary 欄に添付した画像が `~/.yunomi/outputs/image_0.png` に保存されるだけで、stdout の結果に保存先が出ない問題を今すぐ直す。
同時に、この環境で古い `npx` キャッシュが混在しないようにし、最新だけが使われる状態にする。

## 未達・未確認

- yunomi review の人間承認は未実施。次に `herdr run --label yunomi --cwd /Users/kazuph/src/github.com/kazuph/yunomi -- npx yunomi REPORT.md` で承認に出す。
- 既存の作業ツリーには広範な他者変更があるため、今回の修正に必要な範囲だけ触り、無関係な diff は保持した。

## Why

これまで summary 添付画像は保存されても、その保存パスがレビュー結果 YAML に出なかった。
そのため reviewer 側は「画像がある」というシグナルを受け取れず、別のプレビューや直接添付と誤認して調査時間を失う状態だった。
さらに保存名が固定に近く、同じプロセスや複数レビューで衝突・上書きが起きる構造だった。

## How

summary 画像の保存処理を、保存パスを捨てる処理から、名前付き保存して `ReviewResult.summary_images` に積む処理へ切り替えた。
保存名は `summary-<server_instance_id>-<submit_instance_id>-<index>.png` 形式にし、同一プロセス内の複数 submit でも同じ index が衝突しないようにした。
YAML 出力側には `summary_images:` ブロックを追加し、行コメント添付と同じように stdout から実ファイルへ到達できるようにした。

## What

- `v2/src/server/main.mbt`: summary 画像を `base64_to_named_file` で保存し、保存済み絶対パスを結果に渡すように変更。
- `v2/src/core/model.mbt`: `ReviewResult` に `summary_images` を追加。
- `v2/src/core/yaml.mbt`: 単一ファイル・複数ファイルの両方で `summary_images:` を YAML 出力。
- `v2/src/core/yaml_test.mbt`: `summary_images` YAML 出力の単体テストを追加。
- `v2/src/server/main_test.mbt`: summary 画像ファイル名と、同一 index の複数 submit が衝突しない回帰テストを追加。
- `v2/e2e/smoke.ts`: 1px PNG の `summaryImages` を実送信し、stdout YAML の絶対パス、実ファイル存在、保存名形式を検証。

## 検証

- `moon check`: 成功。既存警告のみ。
- `moon test`: `herdr run job-1783903894461-12018` で 186 passed / 0 failed。
- `v2/e2e/smoke.ts`: `herdr run job-1783913589469-28455` で 140 passed / 0 failed。`summary_images:`、絶対パス、実ファイル存在、`summary-...-0.png` 形式を確認。
- `v2/e2e/vim_keys.ts`: `herdr run job-1783913589533-28419` で 16 passed / 0 failed。先行の full `npm test` で出た submit modal timeout は単体再現しなかった。
- `npm run prepack`: `herdr run job-1783913645182-58419` で成功。`dist/server/server.js` と `dist/ui/ui.js` を生成。
- 生成済み `dist/server/server.js`: `summary_images` と `summary-` が含まれることを確認。
- `npm test`: `herdr run job-1783933798770-84947` で成功。
- バージョン確認: ローカル `yunomi` と `node dist/server/server.js --version` は `3.0.0-alpha.1`、public `npx --yes yunomi@latest --version` は `2.2.0`。
- `npx` キャッシュ整理: 古い `yunomi@2.0.0` のキャッシュを削除し、`npx` 側は `2.2.0` のみ残る状態を確認。

## レビュー観点

この修正で、summary 添付画像はレビュー結果 stdout の `summary_images` から必ず辿れる。
保存ファイル名にも server instance と submit instance が入るため、同一プロセスの multi-file / 複数 submit でも同じ `image_0.png` に潰れない。
