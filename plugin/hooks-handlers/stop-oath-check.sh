#!/usr/bin/env bash
# TEMPORARY: disabled to break infinite loop
exit 0
# Stop hook - 完了割合チェックシステム
#
# フロー:
#   1. 「完了割合: X/3」が含まれていれば → スルー
#   2. 実装/修正キーワードがあれば → 完了割合を問う
#   3. それ以外（調査・相談など）→ スルー

INPUT=$(cat)

# jqの場所を特定
JQ=/usr/bin/jq
if [ ! -x "$JQ" ]; then
  JQ=/opt/homebrew/bin/jq
fi
if [ ! -x "$JQ" ]; then
  exit 0
fi

TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | "$JQ" -r '.transcript_path // empty' 2>/dev/null || true)

# transcriptがなければスキップ
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# 最近のtranscriptエントリを取得（最後200行）
RECENT=$(tail -200 "$TRANSCRIPT_PATH" 2>/dev/null || true)

if [ -z "$RECENT" ]; then
  exit 0
fi

# 最新のassistantメッセージのテキスト内容を取得
LATEST_ASSISTANT_TEXT=$(printf '%s' "$RECENT" | "$JQ" -rs '
  [.[] | select(.type == "assistant")] | last |
  .message.content[]? | select(.type == "text") | .text // empty
' 2>/dev/null || true)

if [ -z "$LATEST_ASSISTANT_TEXT" ]; then
  exit 0
fi

# 完了割合パターン（既に回答済みならスルー）
COMPLETION_PATTERN="完了割合:[[:space:]]*[0-3]/3"
if printf '%s' "$LATEST_ASSISTANT_TEXT" | grep -qE "$COMPLETION_PATTERN"; then
  exit 0
fi

# JSON出力用関数（AIにだけ見えるブロック）
block_with_reason() {
  local reason="$1"
  "$JQ" -n --arg reason "$reason" '{"decision": "block", "reason": $reason}'
  exit 0
}

# 実装/修正キーワードパターン
IMPL_KEYWORDS="実装しました|実装した|実装完了|修正しました|修正した|修正完了|追加しました|追加した|変更しました|変更した|作成しました|作成した|更新しました|更新した|完了しました|完了した|対応しました|対応した"

# 実装/修正キーワードが含まれているかチェック
if printf '%s' "$LATEST_ASSISTANT_TEXT" | grep -qE "$IMPL_KEYWORDS"; then
  block_with_reason '[yunomi-plugin] 実装/修正の報告を検知しました。

完了の定義を確認してください：

□ 実装完了 (1/3)
  → ビルドが成功したか？（npm run build / pnpm build）
  → 型エラー・lintエラーがないか？

□ 検証完了 (2/3)
  → dev serverを起動して実際にテストしたか？
  → webapp-testing skillで確認したか？

□ レビュー完了 (3/3)
  → .artifacts/<feature>/にエビデンス（スクショ/動画）があるか？
  → artifact-proof skillでレポートを作成したか？
  → /doneスキルを実行したか？
  → yunomiをフォアグラウンドで起動してレビューを受けたか？
  → ユーザーから承認を得たか？

【回答形式】
返答の末尾に以下を追記してください：

---
完了割合: X/3（Xは0〜3の数字）

※まだ完了していない項目があれば、次に何をすべきか明記してください。'
fi

# 実装/修正キーワードがなければスルー（調査・相談など）
exit 0
