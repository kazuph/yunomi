---
title: Rebrand Green Check
status: draft
tags: [rebrand, green, matcha]
reviewer: kazuph
---

# 湯呑みグリーン化チェック

このファイルは Phase1（緑リブランド）の目視確認用サンプルです。

## 見出しと本文

段落テキストのリンクは [こちら](https://example.com) のようにアクセントカラーで表示されます。

## テーブル（狭い列を含む）

| 名前 | ステータス | 詳細 |
|------|:----------:|------|
| Alice | ✅ OK | 長めの説明文を入れて折返しの見た目を確認する |
| Bob | ⚠️ Warn | もう一つの説明文 |
| Carol | ❌ NG | さらに説明文 |

## Mermaid 図

```mermaid
flowchart LR
    A[開始] --> B{判定}
    B -->|Yes| C[緑化完了]
    B -->|No| D[再修正]
```

## 質問プレビュー

<div class="yunomi-questions-preview">
  <div class="yunomi-q-card resolved">
    <div class="yunomi-q-header"><strong>Q1</strong></div>
    <div class="yunomi-q-question">この配色でOKですか？</div>
    <div class="yunomi-q-answer">はい、OKです</div>
  </div>
</div>
