# yunomi 2.4.1 リリース

## 今回の依頼

> 「ええね！一旦これを出したいです。バージョンも上げてください。」

## Why

前回公開版2.4.0以降の修正はこの作業ツリーだけにあり、npm・MCPの自己申告版数と、この環境で実行されるグローバルCLIも2.4.0のままだった。リンクの別タブ化、過去コメントの再アンカーと単一表示、hot reload時の位置保持、レビュータブと通知、同一レポートの単一サーバー化を、検証済みの1つのpatch releaseとして固定する必要があった。

## How

- CLI/npm/MCPを2.4.1へ揃え、変更のないClaude Code pluginは独立版2.4.0のまま据え置いた。
- 版上げ後に全テストを実行した。初回はチャット開閉テストが500ms遅延のメディアサイドバー初期化と競合したため、固定時間待ちではなく実際のsidebar表示完了を待つように修正し、対象E2Eと全回帰を再実行した。
- npm公開物をdry-runし、その成果物をNode 22.22.0のグローバル環境へ再インストールした。

## What

- repo内CLI、生成CLI、MCP initializeは2.4.1を返す。
- npm dry-runは `yunomi@2.4.1`、6ファイル、214,056 bytesで成功した。
- この環境のグローバル `yunomi` は2.4.1へ置換済みで、repo/installedのserverとUIはSHA-256が一致する。
- npm registryのlatestはまだ2.4.0。`npm whoami` が `E401 Unauthorized` のため、npm publishは実行していない。

## 検証

- 版上げ後 `npm test`: MoonBit 190/190、external-links、inline-comments、RC2、全V2 E2Eが成功（job `job-1785548599131-61952-228`）。
- chat/sidebar競合の対象 `review_loop.ts`: 成功（job `job-1785548561856-61952-227`）。
- plugin独立版の対象 `feature_matrix_regression.ts`: 21 passed / 0 failed（job `job-1785549035830-61952-238`）。
- `npm pack --dry-run --json`: `yunomi@2.4.1`、entryCount 6、成功（job `job-1785549054293-61952-239`）。
- グローバル再インストール: 成功（job `job-1785549071501-61952-240`）。
- `yunomi --version` と `dist/server/server.js --version`: ともに `yunomi 2.4.1 (moonbit)`。
- repo/installed SHA-256: server `af4034f097e6525f503a194ec6f6aa3054e910d54363627430e96ad63d563eae`、UI `dc9b06ee6543dbb1d5a4df44200a3bc52d53d20ddbd1d3e1aed8d0924fd29d91` で一致。
- MCP E2E: initializeが公開名と2.4.1を返すことを確認。
- `git diff --check`: 成功。

## 公開状態

- GitHub commit/tag/push: この最終レビューの承認後に実行する。
- npm publish: 認証を証明できないため保留。認証が回復するまで実行しない。

---

## 以下はこのファイルに以前から残っていたレビュー内容

# レビュー本文のリンクを必ず外部タブで開く

## 今回の依頼

> 「リンクなのですが、必ず外部タブになるようにして。テストも書いておいて。」

## Why

Markdown本文の通常リンク・参照リンク・autolink・脚注と、HTMLプレビュー内のリンクは、レビュータブを置き換えたり、HTMLのコメントモードにクリックを奪われたりする経路が残っていた。raw HTMLは作者が `target="_self"` や `rel="opener"` を指定できたため、本文側の指定がレビュー継続とタブ分離を壊せた。

## How

- Markdownが生成する全リンクとsanitize済みraw HTMLリンクへ、`target="_blank" rel="noopener noreferrer"` を強制する。raw HTML由来の `target` / `rel` は破棄してから安全な値を付け直す。
- HTMLプレビューは読込時とクリック時に同じ属性を強制し、リンククリックだけはコメントカード生成から除外する。iframe sandboxはユーザー操作によるpopupだけを追加許可した。
- 永続E2Eは、[Playwrightの新規ページ監視](https://playwright.dev/docs/pages)を使い、新規タブ数・対象URLへのnavigation request・元レビューURL不変を別々に検証する。

## What

- レビュー対象のMarkdown/HTML本文リンクは、リンク種別や本文側の属性指定に関係なく別タブで開く。
- 元のyunomiレビュータブは同じURLのまま残る。
- `noopener noreferrer` により、開いたページからレビュータブの `window.opener` とreferrerを利用できない。
- yunomi自身のブランドリンクと複数ファイル切替リンクは今回の対象外で、既存の同一タブ操作を維持する。

## 検証

- MoonBit単体: 190 passed / 0 failed（job `job-1785534090831-61952-190`）。
- MarkdownリンクE2E: 通常・参照・autolink・raw HTML・脚注の属性、新規タブ1枚、対象navigation request、元タブ不変を確認（job `job-1785534499392-61952-202`）。
- HTMLプレビューE2E: 相対リンクの別タブ表示、元shell URL不変、`window.opener === null`、既存Submit/コメントを含む38 passed / 0 failed（job `job-1785534142670-61952-193`）。
- `npm test`: リンクE2E、inline-comments、RC2、MoonBit 190件、全V2 E2Eが成功（job `job-1785534510234-61952-203`）。
- グローバル `yunomi 2.4.0` をNode 22.22.0環境へ再インストール（job `job-1785534706723-61952-204`）。repo/実行版SHA-256はserver `73c925ac...06ac`、UI `d8973696...5e91` で一致。
- `git diff --check`: 成功。

---

## 以下はこのファイルに以前から残っていたレビュー内容

# 過去コメントの再アンカー・単一表示・ホットリロード位置保持

## 今回の依頼

> 「過去のインラインコメントが次の更新時にデタラメな場所に出ることがあります。順番すら違う時があります。この辺ですが、みっちりテストしてバグを潰してください。」
>
> 「ホットリロードするときにスクロール位置が変わらないようになってないならなるようにして。これ以降は常にビルドしてこの環境のyunomiを置き換えて。」
>
> 「コメントした場所と、コメントダイアログが出る場所が上下に別に存在して、同じことが2つかかれちえるようなことがないようにして。」

## Why

次ラウンド開始時の保存済みコメントは、複数行snippetを現在ファイルの単一行と比較していたため、行挿入・移動・同文重複で古い座標や先頭の同文へ誤着地していた。同じ保存済みコメントをpreviewとsourceの両方へ描画していたため、本文や編集欄が上下・別surfaceに重複していた。ホットリロード前には実際のスクロール位置を保存していなかった。

## How

- unresolvedコメントをquoteと前後contextで候補採点し、一意な最大候補だけへ `row`・`line`・`end_row` をまとめて更新する。同点・削除済み・表の列欠落は無関係な旧座標へ置かず、明示的な未配置欄へ1件だけ出す。
- DOMはサーバー確定済み座標を優先し、文書順と保存順を安定化した。同一targetへの複数コメントは保存順を維持する。
- 保存済みローカルコメントと編集中UIはcanonical targetへ1つだけ描画する。表はクリックした `td/th` 内、画像は不正な `<p>` 内blockを避けて対象blockの有効な兄弟へ置く。
- hot reloadとround reloadの直前にpreview/source（および存在するwindow）の位置を保存し、DOM・コメント復元後にclampして戻す。復元中だけscroll syncを抑止し、復元後の通常syncは再開する。
- 実Chromeでインラインtextareaのキーボード入力を消していた `font: inherit` を除去した。

## What

- 行挿入・削除・段落移動・同文重複・同一target複数件・表の同文別セルでも、過去コメントは一意な対象へ1回だけ表示される。
- 対象を一意に証明できないコメントは本文の別位置へ捏造配置されず、「Not shown in document」に残る。
- preview/sourceの非0スクロール位置はファイル更新後も維持され、復元後も手動scroll syncが動く。
- 通常画面は `body { height: 100vh; overflow: hidden }` でwindow自体がスクロールしないため、windowの非0値は通常fixtureでは発生しない。実際にスクロールするpreview/sourceの保持はE2Eで実証した。

## 検証

- MoonBit単体: 190 passed / 0 failed。
- `npm run test:v2`: 全E2E成功（job `job-1785512009011-61952-125`）。
- `npm test`: inline-comments・RC2・V2の全テスト成功（job `job-1785512365385-61952-131`）。
- 重点E2E: 画像・表セル・動画タイムラインの実入力（job `job-1785511705716-61952-115`）、再アンカー・順序・未配置・round scroll（job `job-1785511981015-61952-124`）。
- 実Chrome: 右画像セルと表 `R107 C3` の内部にエディタが各1つだけ出て、実キーボード入力を保持。レビュー面の⌘EnterでSubmitを開き、Submit内の⌘EnterでRequest Changesを送信。`verdict ... request_changes` と `tab closed ... active=0` の通知を確認。
- 最終prepack成功（job `job-1785512772691-61952-137`）。グローバル `yunomi 2.4.0` を置換（job `job-1785512785474-61952-138`）。repo/installedのSHA-256はserver `277bd99f...ba1c`、UI `d8973696...5e91` で一致。
- read-only reviewer再監査: 重大ブロッカー・契約矛盾なし。`git diff --check` 成功。

---

## 以下はこのファイルに以前から残っていたレビュー内容

# yunomi の書込み可能レビューを対話可能な起動へ統一

## 今回の依頼

> 「Skillも見直して。基本的に対話ができるオプションを使うようにSkillやグローバルルールを修正して。Claudeのルールもです。」
>
> 「このリポジトリのSkillもherdrやtmuxがある時に適切な起動方法になるようにして。」

## 未達・制約

- Gist同期はローカルの承認guardが2回とも更新を止めたため未達。dotfiles本体とObsidian Vaultは同一SHAへ同期済み。
- yunomi CLI自体は、通知なしの書込み可能起動をまだ拒否しない。今回はSkill・Codexグローバルルール・Claudeグローバルルール・repoルール・生成Skillの起動契約を統一した。
- tmux単独環境では、raw `tmux send-keys` が作業中入力を壊すため自動fallbackを追加していない。安全なキュー配送と到達性を事前検証済みの `YUNOMI_NOTIFY_CMD` がある場合だけ許可し、それ以外はfail closedにした。

## 修正後の起動契約

Herdrが使える書込み可能レビューは、実行時にJSONからpane IDを抽出し、実在検証してから起動する。

```bash
PANE_ID="$(herdr pane current | jq -er '.result.pane.pane_id')" || exit 1
herdr pane get "$PANE_ID" >/dev/null || exit 1
herdr run --label yunomi --cwd /absolute/path/to/repo -- \
  npx yunomi REPORT.md --loop --notify-pane "$PANE_ID"
```

Claude Codeは同じpane検証後、`npx yunomi REPORT.md --loop --notify-pane "$PANE_ID"` を `run_in_background: true` で起動する。
`yunomi share` だけはread-only例外。

## 変更箇所

- `~/dotfiles/claude/skills/yunomi/SKILL.md`: JSON全体をpane IDとしていた誤りを修正。Herdr優先、`--loop --notify-pane`、tmux安全境界、share例外を明記。
- `~/dotfiles/.codex/AGENTS.md`: Codexの唯一の書込み可能起動を、検証済みpane付きの `herdr run` に統一。
- `~/dotfiles/claude/CLAUDE.md`: Claudeは `run_in_background` を使いつつ、ライブ対話用Herdr paneを必ず検証する契約へ修正。
- `CLAUDE.md`: このrepoの開発・確認起動にも同じ契約を追加。
- `v2/src/server/main.mbt`: `yunomi --skill` が出力する生成Skillへ同じ契約を反映。
- `v2/e2e/instant_skill.ts`: Herdr専用pane、tmux adapter、share例外を生成Skillの必須文面として固定。

## 検証

- `npm run prepack`: 最終再実行も成功（job `job-1785491357716-74745-32`）。
- `v2/e2e/instant_skill.ts`: 33 passed / 0 failed（job `job-1785491372766-74745-33`）。
- Skill frontmatter: Ruby YAML parserで読取り成功。271行で500行未満。
- `git diff --check`: repo対象・dotfiles対象とも成功。

---

## 以下はこのファイルに以前から残っていたレビュー内容

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
