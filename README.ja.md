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

## ロードマップ: The Review Loop 🔁

一杯で会話は終わりません。yunomiの次のメジャー進化は、1回のレビューを**多ラウンドのループ**へ変えること——AIネイティブレビューツールを定義するワークフローです：

- **ラウンド** — 修正依頼のあと、エージェントが直して `yunomi go` を実行すると、ブラウザに新しいラウンドが開き、**コメント以降に実際に何が変わったかのdiff**が表示される
- **消えないスレッド** — コメントはラウンドを跨いで行に張り付き続け、**あなたが解決するまで未解決のまま**。「直したつもり」でフィードバックが闇に消えることはもうできない
- **レビューファイル** — 判定は `.yunomi/reviews/` にブランチ単位で永続化。ターミナルが消えても、どのエージェント（Claude Code / Codex / Cursor / OpenCode…）でも翌日ループを再開できる
- **ライブアプリレビュー** — `yunomi live http://localhost:3000` がdevサーバーをプロキシし、動いているアプリの**DOM要素に直接ピンコメント**できる
- **レビュー中に話しかける** — 読み進めながらコメント1件だけをエージェントへ即送信し、返信がスレッドに届くのを眺められる
- **`yunomi install <agent>`** / **`yunomi mcp`** — 全エージェント環境へのワンコマンドskill配布と、MCPサーバーモード

[crit](https://crit.md/) などとのギャップ分析を含む機能単位の完全な計画は [PLAN.md](./PLAN.md) にあります。中心にあるのは変わらずEvidence-firstの報告文化——yunomiはこれからも**diffではなく、仕事そのもの**をレビューします。

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
reason: button
at: '2025-11-26T12:00:00.000Z'
comments:
  - row: 2
    col: 3
    text: This value needs review
    value: '150'
summary: Overall the data looks good, minor issues noted above.
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

### `npx skills` でスキルを入れる

Codex、OpenCode、Cursor など、`npx skills` 対応エージェントで yunomi のタスクスキルを使いたい場合はこちらを使います。Claude Code は上のプラグイン導線を使ってください。

```bash
# まず検出されるスキルを確認
npx skills add https://github.com/kazuph/yunomi --list

# Codex 向けに全スキルをグローバルインストール
npx skills add https://github.com/kazuph/yunomi -g -a codex -s '*' --copy -y

# Codex と OpenCode へまとめてグローバルインストール
npx skills add https://github.com/kazuph/yunomi -g -a codex -a opencode -s '*' --copy -y
```

`npx skills` が配るのは `plugin/skills/` 配下のスキル群です。`-a codex -g --copy` を付けると、Codex のグローバルスキル置き場である `~/.agents/skills/` にコピーされます。`~/.agents/skills` が symlink の場合は、そのリンク先に実体が置かれます。

Claude Code のプラグイン command や hooks はこの経路では入らず、上の Claude Code プラグイン導線でインストールします。

### プラグインディレクトリ構成

```
plugin/
├── .claude-plugin/
│   └── plugin.json          # プラグインメタデータ（名前、バージョン、説明）
├── agents/
│   ├── report-builder.md     # レポート生成エージェント
│   ├── e2e-health-reviewer.md    # E2Eテスト健全性チェック
│   ├── review-code-quality.md    # コード品質レビュー
│   ├── review-security.md        # セキュリティ監査
│   ├── review-a11y-ux.md         # アクセシビリティ & UX
│   ├── review-figma-fidelity.md  # デザイン忠実度
│   ├── review-copy-consistency.md # テキスト整合性
│   └── review-e2e-integrity.md   # E2Eテスト整合性
├── skills/
│   ├── ask/
│   │   └── SKILL.md          # 要件ヒアリングスキル
│   ├── bucho/
│   │   └── SKILL.md          # 部長オーケストレーションスキル
│   ├── do/
│   │   └── SKILL.md          # タスク開始スキル
│   ├── done/
│   │   └── SKILL.md          # タスク完了スキル
│   ├── exit-notifier/
│   │   ├── SKILL.md          # background task 終了通知スキル
│   │   └── scripts/
│   │       └── watch-exit-notify.sh
│   ├── tiny-do/
│   │   └── SKILL.md          # 軽量タスク開始スキル
│   ├── tiny-done/
│   │   └── SKILL.md          # 軽量タスク完了スキル
│   ├── validate-report/
│   │   └── SKILL.md          # REPORT.md検証の内部 helper
│   ├── artifact-proof/
│   │   └── SKILL.md          # エビデンス収集スキル
│   └── webapp-testing/
│       ├── SKILL.md          # Webテストスキル
│       ├── scripts/          # ヘルパースクリプト
│       └── examples/         # 使用例
├── hooks/
│   └── hooks.json            # フック定義
├── hooks-handlers/
│   └── completion-checklist.sh  # UserPromptSubmitハンドラ
└── README.md
```

### コンポーネント概要

| 種類 | 名前 | 説明 |
|------|------|------|
| **タスクスキル** | `/yunomi:do` | タスク開始 - git wtでworktree作成、計画、todo登録 |
| **タスクスキル** | `/yunomi:done` | 完了チェックリスト - 7レビューエージェント実行、エビデンス収集、レビュー開始 |
| **タスクスキル** | `/yunomi:tiny-do` | 小タスク向けの軽量開始フロー |
| **タスクスキル** | `/yunomi:tiny-done` | 小タスク向けの軽量完了フロー |
| **タスクスキル** | `/yunomi:bucho` | Claude Code と Codex を束ねる部長モード |
| **エージェント** | `report-builder` | ユーザーレビュー用レポート準備 |
| **エージェント** | `review-code-quality` | コード品質: 可読性、DRY、型安全性、エラーハンドリング |
| **エージェント** | `review-security` | セキュリティ: XSS、インジェクション、OWASP Top 10、秘密情報検出 |
| **エージェント** | `review-a11y-ux` | アクセシビリティ: WCAG 2.2 AA、キーボード操作、UXフロー |
| **エージェント** | `review-figma-fidelity` | デザイン: トークン準拠、視覚的一貫性 |
| **エージェント** | `review-copy-consistency` | コピー: テキスト整合性、トーン&マナー、i18n |
| **エージェント** | `review-e2e-integrity` | E2E: ユーザーフロー再現、モック汚染検出 |
| **エージェント** | `e2e-health-reviewer` | E2E: goto制限、レコードアサーション、ハードコード検出 |
| **スキル** | `artifact-proof` | エビデンス収集（スクリーンショット、動画、ログ） |
| **スキル** | `exit-notifier` | background task の終了と stdout/stderr を現在の tmux / Herdr pane に通知 |
| **スキル** | `webapp-testing` | Playwrightによるブラウザ自動化と検証 |
| **フック** | PreToolUse | git commit/push前にレビューを促すリマインダー |
| **フック** | UserPromptSubmit | AI コンテキストに完了チェックリストを注入 |

---

### タスクスキル

#### 同梱タスクスキル一覧

| スキル | 用途 |
|------|------|
| `ask` | 実装前に要求・スコープ・制約・成功条件を明確化する |
| `bucho` | Claude Code と Codex を tmux 経由で束ねてチーム開発フローを回す |
| `check-yourself` | 推測を禁止し、実際の検証を強制する |
| `commit-and-push` | コミットメッセージ生成、commit、push、最終状態確認まで実行する |
| `do` | worktree 作成、計画策定、レビュー準備を含むフルの開始フローを実行する |
| `done` | エビデンス収集と yunomi レビューを含むフルの完了フローを実行する |
| `exit-notifier` | background task の終了結果と stdout/stderr を現在の tmux / Herdr pane に返す |
| `open` | ファイル、成果物、URL を macOS の `open` で開く |
| `tiny-do` | 小さなタスク向けの軽量開始フローで実装へ入る |
| `tiny-done` | 小さなタスク向けの軽量完了フローで検証と確認を行う |
| `validate-report` | `done` から呼ばれる内部 helper として `REPORT.md` を検証する |

#### `/yunomi:do <タスク説明>`

適切な環境セットアップで新しいタスクを開始します。

**処理内容:**
1. git wtを使用して分離開発用のgit worktreeを作成（`feature/<name>`、`fix/<name>`など）
2. エビデンス用の`.artifacts/<feature>/`ディレクトリをセットアップ
3. 計画とTODOチェックリスト付きの`REPORT.md`を作成
4. 進捗追跡用にTodoWriteにtodoを登録

**作成されるディレクトリ構成:**
```
<worktree>/                   # 例: .worktree/feature-auth/
└── .artifacts/
    └── <feature>/            # 例: auth（feature/authから）
        ├── REPORT.md         # 計画、進捗、エビデンスリンク
        ├── images/           # スクリーンショット
        └── videos/           # 動画録画
```

**タスク再開:** セッション開始時またはコンテキスト圧縮後、スキルは既存のworktreeを確認（`git wt`）し、`REPORT.md`から再開します。

#### `/yunomi:done`

タスク完了を許可する前に完了基準を検証します。

**適用されるチェックリスト:**
- [ ] ビルド成功（型/lintエラーなし）
- [ ] 開発サーバー起動・動作
- [ ] `webapp-testing`スキルで検証
- [ ] `.artifacts/<feature>/`にエビデンス収集
- [ ] `artifact-proof`スキルでレポート作成
- [ ] yunomiでレビュー（フォアグラウンドモード）
- [ ] ユーザー承認取得

**禁止事項:**
- 検証なしに「実装完了」と言う
- yunomiレビュー前にコミット/プッシュ
- エビデンスなしのレポート

---

### エージェント

#### `report-builder`

レビュー資料準備専門エージェント。

**役割:**
- 実装を構造化レポートに整理
- エビデンス（スクリーンショット、動画）を収集・配置
- yunomiレビュー用に`REPORT.md`を準備
- yunomiフィードバックを解析してtodoに登録

**呼び出し:**
```
Task tool with subagent_type: "report-builder"
```

**自動読み込みスキル:** `artifact-proof`

---

### スキル

#### `artifact-proof`

ビジュアルリグレッションとPRドキュメント用のエビデンス収集を管理。

**機能:**
- `.artifacts/<feature>/`配下にスクリーンショットと動画
- 自動キャプチャ用Playwright統合
- 動画ファイル用Git LFSセットアップ
- コミットハッシュ付きPR画像URL（ブランチ削除後も永続）

**yunomi統合:**
```bash
# yunomiでレポートを開く（フォアグラウンド必須）
npx yunomi .artifacts/<feature>/REPORT.md

# 動画プレビュー付き
open .artifacts/<feature>/videos/demo.webm
npx yunomi .artifacts/<feature>/REPORT.md
```

#### `webapp-testing`

Playwrightを使用したブラウザ自動化ツールキット。

**機能:**
- TypeScript Playwright Test (`@playwright/test`)
- webServerサポート付きPlaywright設定
- スクリーンショットと動画キャプチャ
- コンソールログとネットワークリクエスト監視
- 高度なデバッグ用CDP統合

**クイック検証:**
```bash
node -e "const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('http://localhost:3000', { waitUntil: 'networkidle' });
  await page.screenshot({ path: '/tmp/webapp.png', fullPage: true });
  await browser.close();
})();"
```

---

### フック

#### PreToolUse（Bashマッチャー）

`git commit`または`git push`検出時にトリガー。

**メッセージ:** コミット前に`/yunomi:done`を実行してyunomiでレビューするよう促す。

#### UserPromptSubmit

すべてのAI応答コンテキストに完了チェックリストを注入。

**目的:** 適切な検証なしの「実装完了」主張を防止。チェックリストは常にAIに見え、完了基準の一貫した適用を保証。

---

### ワークフロー

```
/yunomi:do <タスク説明>
    ↓
Worktree作成 + 計画 + TodoWrite
    ↓
実装（サブエージェント経由）
    ↓
ビルド & 検証（webapp-testing）
    ↓
/yunomi:done
    ↓
エビデンス収集（artifact-proof）
    ↓
npx yunomiでレポートを開く（フォアグラウンド）
    ↓
ユーザーコメント → Submit & Exit
    ↓
フィードバックをTodoに登録
    ↓
修正 → 承認まで再レビュー
    ↓
コミット & PR（承認後のみ）
```

### 完了基準

| ステージ | 内容 | ステータス |
|----------|------|----------|
| 1/3 | 実装完了 | まだ報告しない |
| 2/3 | ビルド、起動、検証完了 | まだ報告しない |
| 3/3 | yunomiでレビュー → ユーザー承認 | 完了 |

### 設計思想

プラグインは**Human-in-the-loop**開発を強制します:

1. **ショートカットなし:** モック、バイパス、検証スキップは禁止
2. **エビデンス必須:** すべての完了主張にはスクリーンショット/動画が必要
3. **ユーザー承認:** ユーザーのみがタスクを完了としてマークできる
4. **コンテキスト保持:** 重い操作はサブエージェントで実行してコンテキスト枯渇を防止

### `.artifacts`ディレクトリポリシー

`.artifacts/`ディレクトリは開発中に生成されたスクリーンショット、動画、レポートを保存します。**デフォルトでは、このディレクトリは`.gitignore`に追加すべきです**。大きなメディアファイルによるリポジトリ肥大化を防ぎます。

```bash
# .gitignoreに追加（推奨）
echo ".artifacts" >> .gitignore
```

**デフォルトで除外する理由:**
- スクリーンショットと動画は大きくなる可能性がある（特に画面録画）
- エビデンスは主にレビュープロセス用で、永続的なドキュメントではない
- リポジトリサイズを管理可能に保つ

**特定のエビデンスをコミットしたい場合:**

`git add --force`で明示的にファイルを追加:

```bash
# 特定のエビデンスファイルを強制追加
git add --force .artifacts/feature/images/final-screenshot.png
git add --force .artifacts/feature/REPORT.md

# または機能全体のエビデンスを強制追加
git add --force .artifacts/feature/
```

**動画ファイル**の場合、リポジトリ肥大化を避けるためGit LFSを使用:

```bash
git lfs track "*.mp4" "*.webm" "*.mov"
git add .gitattributes
git add --force .artifacts/feature/videos/demo.mp4
```

このアプローチで完全なコントロールが可能: デフォルトで除外、必要なものだけをコミット。

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
