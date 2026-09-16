<h1 align="center">どうぞ 🍵</h1>

<p align="center">
  <img src="https://raw.githubusercontent.com/kazuph/yunomi/main/assets/hero.png" alt="お茶をそっと差し出すボクセルロボットと、報告書を読むエンジニア" width="720">
</p>

<p align="center">
  <strong>レビューを、お茶のように差し出す。</strong><br>
  <strong>yunomi</strong>（湯のみ）— AIコーディングワークフローのためのHuman-in-the-loop承認ゲート
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/yunomi"><img src="https://img.shields.io/npm/v/yunomi.svg" alt="npm version"></a>
  <a href="https://github.com/kazuph/yunomi/blob/main/LICENSE"><img src="https://img.shields.io/npm/l/yunomi.svg" alt="license"></a>
  <a href="./README.md">English</a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/kazuph/yunomi/main/assets/demo.gif" alt="yunomiデモ: エージェントが報告書を差し出し、エビデンスを読み、コメントして承認するまで" width="960">
</p>

---

> **インストール手順はありません。** AIに *「`npx yunomi` を実行してね」* と言うだけ。あとはAIが分かってくれます。

**yunomi**（湯のみ）は、日本の暮らしのなかのあの器。取っ手も受け皿もなく、両手で包むと温かい。湯のみのお茶はいつも同じ出され方をします——そっと目の前に置かれて、小さな会釈と、ひとこと——「どうぞ」。

## ストーリー

yunomiは、人間が「やったものを見せろ」と要求するためのツールではありません。
その**逆の所作**のためのツールです。

AIエージェントは仕事を終えたとき、ただ「できました」と言うべきではありません。
報告書を淹れるべきです——何を変えたのか、なぜか、エビデンスとテスト結果——それを湯のみに注いで、あなたの前にそっと置く:

```bash
npx yunomi REPORT.md
```

「どうぞ🍵」

ブラウザが開きます。あなたは自分のペースで読み、コメントを残し、承認するか、突き返すか決めます。エージェントは良い給仕がそうするように、静かに待ちます——あなたが決めるまで。Submitするとyunomiは終了し、あなたの判断を構造化YAMLとしてエージェントへ返します。承認が出るまで、このループが続きます。

vibe codingの時代、人間はもうすべてのdiffを読みません。読むのは仕事そのもの——**意図・変更・証拠**です。yunomiは、AIの仕事と人間の判断のあいだの受け渡しの瞬間。毎回、礼儀正しく差し出されます。

## Review Loop 🔁

一杯で会話は終わりません。yunomi は、1回のレビューを**多ラウンドのループ**へ変えました——AIネイティブレビューツールを定義するワークフローです：

- **ラウンド** — 修正依頼のあと、エージェントが直して `yunomi go` を実行すると、ブラウザに新しいラウンドが開き、**コメント以降に実際に何が変わったかのdiff**が表示される
- **消えないスレッド** — コメントはラウンドを跨いで行に張り付き続け、**あなたが解決するまで未解決のまま**。「直したつもり」でフィードバックが闇に消えることはもうできない
- **レビューファイル** — 判定は `.yunomi/reviews/` にブランチ単位で永続化。ターミナルが消えても、どのエージェント（Claude Code / Codex / Cursor / OpenCode…）でも翌日ループを再開できる
- **変更ファイルレビュー** — `yunomi review [base-ref]` がGit・Jujutsu・Saplingの変更ファイルを検出し、Markdown・テキスト・表・diffを1つのレビューセッションで切り替えられる
- **ライブアプリレビュー** — `yunomi live http://localhost:3000` がdevサーバーをプロキシし、動いているアプリの**DOM要素に直接ピンコメント**できる
- **静的HTMLレビュー** — `yunomi page.html` が相対アセット付きのsandbox previewを開き、クリックした要素の文脈を記録する
- **コードレビュー** — diffファイルにはファイルツリー、Unified/Split切替、ファイル単位のReviewed状態がある
- **レビュー中に話しかける** — 読み進めながらコメント1件だけをエージェントへ即送信し、返信がスレッドに届くのを眺められる
- **読み取り専用共有** — `yunomi share REPORT.md` はコメント・Submitを隠した共有URLを作る。外部公開は明示的な `--public` のときだけ
- **GitHub PR同期** — `yunomi pull 123` でPRコメントを取り込み、`yunomi push <review-id> 123` で指定レビューの未同期コメントをGitHubへ送る
- **Vimキーレビュー** — `j/k` で対象移動、`c` でコメント、`n/N` でコメント移動、`r` で解決、`?` でヘルプを開く
- **レビュー管理** — `yunomi status` / `stats` / `cleanup` と `yunomi init --template` で進行状況、統計、掃除、REPORT雛形を扱う
- **`yunomi install <agent>`** / **`yunomi mcp`** — 全エージェント環境へのワンコマンドskill配布と、MCPサーバーモード

[crit](https://crit.md/) などとのギャップ分析を含む機能単位の完全な計画は [PLAN.md](./PLAN.md) にあります。中心にあるのは変わらずEvidence-firstの報告文化——yunomiは**diffではなく、仕事そのもの**をレビューします。

## はじめかた（手順はこれだけ）

AIエージェントにこう言ってください:

> 「これから、仕事が終わったら `npx yunomi` を実行してね」

以上です。エージェントが引数なしで `npx yunomi` を実行すると、スキル文書が出力され、エージェントはすべてを理解します——良い報告書の書き方、差し出し方、あなたの判断の受け取り方、承認まで続くループの回し方。続けてエージェントが「yunomiを永続スキルとしてインストールしますか？」と提案するので、一度YESと答えれば、以降は二度と言う必要はありません。

グローバルインストール不要。プラグイン設定不要。設定ファイル不要。**お茶は勝手に出てきます。**

---

yunomi（旧名 **reviw**）は、Markdown報告書・表形式データ・テキスト・diffファイルをレビュー・注釈するための軽量ブラウザベースツール。[MoonBit](https://www.moonbitlang.com/)で書かれており、手書きJavaScriptはゼロ。CSV、TSV、プレーンテキスト、Markdown、unified diff形式をサポート。コメントはYAML形式で標準出力に出力されます。

## 機能

### ファイル形式サポート
- **CSV/TSV**: スティッキーヘッダー、カラム固定、フィルタリング、カラムリサイズ付きで表形式データを表示
- **Markdown**: 同期スクロール付きサイドバイサイドプレビュー、プレビューからクリックでコメント
- **Diff/Patch**: シンタックスハイライト付きGitHubスタイルdiffビュー、500行以上の大きなファイルは折りたたみ可能、バイナリファイルは末尾にソート
- **テキスト**: プレーンテキストファイルの行ごとコメント

### Mermaid.jsダイアグラム
- MarkdownファイルのMermaidダイアグラムを自動検出・レンダリング
- ダイアグラムをクリックでミニマップ付きフルスクリーンビューアを開く
- マウスホイールでズーム（カーソル位置を中心に、最大10倍）
- マウスドラッグでパン
- トラックパッドのピンチズーム・タッチジェスチャー対応
- Windows向けShift+スクロールズーム対応
- ダークモードでのサムネイル表示対応
- フルスクリーン終了時にソース行をハイライト
- 構文エラーはトースト通知で表示

### メディアサイドバー
- 左サイドバーに画像・動画のサムネイルギャラリーを表示
- サムネイルクリックで対応するメディアにスクロール＆ハイライト
- ↑↓キーで前後のメディアへジャンプ、Escapeで選択解除
- 番号バッジ付きで素早く識別

### メディア埋め込み規律チェック（AIフレンドリー）
- メディアファイルが `![alt](path)` 埋め込みではなく `[text](path)` リンクで書かれている場合、`yunomi file.md` はエラー（exit 1）で起動を拒否
- 行番号とそのまま適用できる修正案を全件表示するので、AIエージェントが自動修正してリトライできる

### メディアフルスクリーン
- Markdownプレビューの画像をクリックでフルスクリーンビューアを開く
- 動画をクリックでYouTube風キーボードショートカット付きフルスクリーン再生（Space/K、J/L、矢印キー、0-9）
- 画像/動画自体を含む任意の場所をクリックでフルスクリーンオーバーレイを閉じる
- メディアをクリックするとMarkdownパネルの対応するソース行が自動ハイライト
- 動画タイムライン設定（シーン検出感度の調整）

### UI機能
- **テーマ切り替え**: ライト/ダークモードの切り替え
- **プレビューオンリーモード**: ソースパネルを非表示にしてプレビューをワイド表示
- **見出し折りたたみ**: 見出しの▼をクリックでセクションを折りたたみ/展開
- **印刷 / PDF保存**: ソース・コメント・レビュー操作を除外し、折りたたみ本文を欠落させずMarkdown報告書を印刷・PDF保存
- **複数ファイルサポート**: 複数ファイルを別々のポートで同時に開く
- **ドラッグ選択**: 矩形領域または複数行を選択してバッチコメント
- **リアルタイム更新**: SSE経由でファイル変更時にホットリロード
- **コメント永続化**: localStorageにコメントを自動保存、リカバリーモーダル付き
- **画像添付**: コメントダイアログとSubmitモーダルで画像添付（Cmd/Ctrl+Vで貼り付け）
- **選択行コピー**: コメントダイアログの📋ボタンで選択行テキストをコピー
- **キーボードショートカット**: Cmd/Ctrl+Enterで送信モーダルを開く
- **マルチタブ同期**: 1つのタブでSubmitすると同じファイルの他のタブも連動して閉じる
- **サーバー検出**: 既存サーバーを再利用（ロックファイルで管理）
- **タブアクティベーション（macOS）**: AppleScript経由で既存ブラウザタブを自動アクティブ化
- **レビュー履歴**: ファイルベースの永続的なレビュー履歴
- **details/summary対応**: HTML details/summaryタグを折りたたみセクションとして表示

### 出力
- file、mode、row、col、value、コメントテキストを含むYAML形式
- レビューノート用のサマリーフィールド
- 画像添付はbase64データとして含む

## インストール

基本的に不要です——[はじめかた](#はじめかた手順はこれだけ)を見てください。グローバルコマンドが欲しい場合は:

```bash
npm install -g yunomi
```

またはnpxで直接実行:

```bash
npx yunomi <file>
```

## 使い方

```bash
# 引数なし: AIエージェント向けスキル文書を出力
yunomi

# 単一ファイル
yunomi <file> [--port 4989] [--encoding utf8|shift_jis|...]

# 複数ファイル（各ファイルは連続するポートで開く）
yunomi file1.csv file2.md file3.tsv --port 4989

# 標準入力からのdiff
git diff HEAD | yunomi

# diffファイル
yunomi changes.diff
```

### オプション
- `--port <number>`: 開始ポートを指定（デフォルト: 4989）
- `--encoding <encoding>`: エンコーディングを強制指定（デフォルトは自動検出）
- `--no-open`: ブラウザの自動起動を無効化
- `--skill`: AIエージェント向けスキル文書を出力
- `--help, -h`: ヘルプメッセージを表示
- `--version, -v`: バージョン番号を表示

### ワークフロー
1. ブラウザが自動的に開く（macOS: `open` / Linux: `xdg-open` / Windows: `start`）
2. セル/行をクリックしてコメント追加、またはドラッグで複数選択
3. Cmd/Ctrl+Enterまたは「Submit & Exit」クリックでコメントを出力
4. コメントはYAML形式で標準出力に出力

## スクリーンショット

### Markdownビュー（メディアサイドバー付き）
![Markdown View with Media Sidebar](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-media-sidebar.png)

### プレビューオンリーモード
![Preview-only Mode](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-preview-only.png)

### 見出し折りたたみ
![Heading Toggle](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-heading-toggle.png)

### コメントダイアログ（画像添付対応）
![Comment Dialog](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-comment-dialog.png)

### 動画フルスクリーン（タイムラインサムネイル付き）
![Video Fullscreen](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-video-thumbnails.png)

### Mermaidフルスクリーン（ミニマップ付き）
![Mermaid Fullscreen](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-mermaid-fullscreen.png)

### レビュー送信ダイアログ（画像添付対応）
![Submit Review Dialog](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-submit-modal.png)

### CSVビュー
![CSV View](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-csv.png)

### Diffビュー
![Diff View](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-diff.png)

## 出力例

```yaml
file: data.csv
mode: csv
comments:
  - file: data.csv
    row: 2
    col: 3
    end_row: 2
    end_col: 3
    quote: '150'
    text: This value needs review
    value: '150'
    snippet: 'alpha,ready,150'
    context_before: 'name,status,total'
    context_after: ''
    selector: ''
    bounds: ''
    element_text: ''
    attachments: []
summary: Overall the data looks good, minor issues noted above.
decision: request_changes
```

## Claude Codeプラグイン

このリポジトリはClaude Codeプラグインマーケットプレイスとしても機能します。プラグインはタスク管理とレビュー自動化でyunomiをClaude Codeワークフローに統合します。

> 注: プラグインは v2.0.0 で `reviw-plugin` から `yunomi-plugin` に改名されました。旧プラグインを入れている場合は削除のうえ `yunomi-plugin@yunomi-plugins` を入れ直してください。

### インストール

```bash
# Claude Codeで
/plugin marketplace add kazuph/yunomi
/plugin install yunomi-plugin@yunomi-plugins
```

### 開発ワークフロー

原本は `plugin/skills/do/`・`done/`・`bucho/` です。個人環境へコピーする場合も同じ本文を配布し、配布先で別の手順を保守しません。`tiny-do`・`tiny-done` は統合され、作業規模による品質水準の選択はありません。

| 入口 | 担当する工程 |
|---|---|
| `/do` | 要求確認、**種類に合う手順ファイルを読む**、現行機能と全呼び出し元の調査、再利用の検討、データ・状態・責任範囲の設計、設計助言、ネストした git wt、TDD、検証できる単位での実装から `/done` まで。 |
| `/done` | 新要件と既存動作の回帰確認、動作を保持した deslop、ビルドと実動作検証、専門レビュー、説明図・スクリーンショット・動画・報告の検証、人間の承認と指摘修正。 |
| `/bucho` | 同じ `/do` → `/done` の全成果を、承認済みのHerdr実装責任者へ委譲。部長は判断記録と実際の差分・証拠を確認して完遂まで責任を持つ。 |

名前空間付きの呼び出し名はエージェントのスキル一覧で確認してください。本文の実行手順は [do](plugin/skills/do/SKILL.md)、[done](plugin/skills/done/SKILL.md)、[bucho](plugin/skills/bucho/SKILL.md) にあります。

### 取り込んだ行動

P-Stackから、依頼の種類に合う手順（調査・不具合・新機能など、`/do` 配下のネストした Markdown）を選ぶこと、実際の処理の理解、データと責任範囲のモデル化、観測による技術的な不明点の解消、前提を検証してから次へ進む作業順序、判断理由と証拠の記録を取り込みます。Ponytailからは、理解した要求を満たす既存コード → 標準機能 → プラットフォーム機能 → 導入済み依存 → 新しいコードの順で検討し、全呼び出し元から共通原因を直す行動を取り込みます。

既存の必須レビュー・テスト・承認は保持します。deslopでも信頼境界の検証、データ保護、セキュリティ、アクセシビリティ、必要なテストを削りません。第三者のスクリプト・ライブラリ・モデル設定は取り込みません。

### 同梱するレビューと実装の指示

| 指示ファイル（`plugin/agents/`） | 保持する責任 |
|---|---|
| `review-code-security.md` | 設計助言と最終コード・セキュリティレビュー。型、エラー処理、重複、インジェクション、認証認可、秘密情報、暗号化。 |
| `review-e2e.md` | 全プロジェクト種別の実際のフロー、アサーション、永続状態、モック・迂回、待機、テスト環境の確認。 |
| `review-ui-ux.md` | 該当UIのWCAG 2.2 AA、キーボード・フォーカス、デザイン、文言・国際化。 |
| `report-builder.md` / `report-validator.md` | 元の依頼と指摘、判断理由、図と証拠の埋め込み、リンク、報告形式の確認。 |
| `webapp-impl.md` / `backend-impl.md` / `mobile-impl.md` | Web・バックエンド・モバイルの実装と実動作検証。 |
| `dogfooding.md` / `review-video.md` | 実操作と動画の確認。 |

現在の環境で承認された独立レビューの起動方法・モデル・権限を使います。固定数のエージェント起動や退役済みモデルの利用は要求しません。重大な指摘（Critical/High）は修正・再検証・再レビューしてから人間へ提出します。

### Markdownだけを既存環境へ配布する

信頼済みのローカルYunomiチェックアウトから、`plugin/skills/{do,done,bucho}/` を既存のスキル配置先へコピーします。まず配布先の独自変更を確認し、3つを同じ改訂へそろえます。`/do` 配下の `playbooks/` と `why.md` も含めます。追加インストーラーや第三者スクリプトは必要ありません。Claude Codeプラグインのインストールとは別の操作で、hooksは有効化しません。

専門レビューの指示は同じチェックアウトの `plugin/agents/` を参照できます。既存環境の `yunomi`、`artifact-proof`、`validate-report`、該当するテストスキル、Web UIの `frontend-design`、委譲する場合の `herdr-pane-commander` も引き続き使用します。これらの補助スキルはこの3スキルの同梱物ではありません。参照先が見つからないときに検証を省略したり、外部スクリプトを取得したりしてはいけません。

### 証拠・レビュー・再開

- 元のcheckoutは既定ブランチのまま保持し、その配下の `git wt` ワークツリーで開発します。
- Webは実ブラウザ、バックエンドは実テストフレームワーク・DBまたは許可済みローカルエミュレーター・カバレッジ、モバイルはMaestroのアサーションと各段階の証拠を使います。Fullstackは両側と通信経路を検証します。
- 説明図、スクリーンショット、動画を報告の表に埋め込みます。比較では既存と新フローを並べ、維持・追加・変更・明示的廃止を色と文字で区別します。提出前にファイルと埋め込み、起動後にブラウザで画像の読み込みを確認します。
- REPORT.md、証拠、判断記録には合意済みの保存先を使い、圧縮や再起動後も同じ記録から再開します。`.artifacts/` の新設・移動はユーザーの許可が必要です。証跡はコミットせず、PR添付は既存の添付手段を使います。
- `yunomi` スキルの現行プロトコルで、検証済みHerdrまたはtmux通知先と `--loop` を指定します。指摘は原文のTODOにして実装・再検証し、同じ承認ループを継続します。人間の承認をAIが代行しません。
- 完了状態は、実装、ビルド・実動作・証拠の検証、人間の承認、許可済みの配布を区別します。

### 既存のフック

`plugin/hooks/` と `plugin/hooks-handlers/` は、commit/push前のレビュー確認、完了チェックリスト、worktreeとテストの保護を提供します。今回の3スキル統合は新しいフックや外部実行依存を追加しません。スキルだけの配布でフックを有効化しません。

## 開発

yunomiは[MoonBit](https://www.moonbitlang.com/)で書かれており、JavaScriptにコンパイルされます。

```bash
# ビルド
cd v2 && moon build --target js --release

# テスト実行
cd v2 && moon test --target js

# npmパッケージング（MoonBitビルド + dist/にコピー）
npm run prepack
```

- ソース: `v2/src/`（MoonBit）
- ビルド出力: `dist/server/server.js`、`dist/ui/ui.js`
- プラグイン: `plugin/`ディレクトリ

## ライセンス

MIT
