---
yunomi:
  questions:
    - id: q1-option
      question: この変更は採用してよいですか？
      context: |
        現行の質問ダイアログはユーザーの実体験フィードバックにより全面再設計した。
        1問1画面のステッパーUI・内部IDの非表示・回答の即時配信が争点。
      options:
        - 採用
        - 却下
    - id: q2-freetext
      question: AIエージェントへのコメント機能について自由にご記入ください
---

# Questions Answers Regression Fixture

This fixture exercises the yunomi frontmatter question flow end to end:
one option-based question (`q1-option`, with a multi-line `context:` block
scalar for the judgment material) and one free-text question
(`q2-freetext`) that receives a long (200+ character) Japanese answer
containing an emoji, to guard against the "answers gets truncated at
the last field" regression.
