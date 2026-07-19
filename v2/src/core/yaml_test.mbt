///|
test "review to yaml single file" {
  let result : ReviewResult = {
    file: "data.csv",
    mode: Csv,
    comments: [
      {
        file: Some("data.csv"),
        row: 1,
        col: 2,
        end_row: Some(1),
        end_col: Some(2),
        text: "needs review",
        value: "150",
        snippet: Some("150"),
        context_before: "",
        context_after: "",
        selector: None,
        bounds: None,
        element_text: None,
        attachments: None,
        image_path: "",
      },
    ],
    summary: "looks good",
    summary_images: [],
    answers: "",
    mermaid_errors: [],
    decision: None,
    action: Some(FinalApprove),
  }
  debug_inspect(
    review_to_yaml(result),
    content=(
      #|"action: final_approve\nfile: data.csv\nmode: csv\ncomments:\n  - file: data.csv\n    row: 1\n    col: 2\n    end_row: 1\n    end_col: 2\n    text: needs review\n    value: 150\n    snippet: 150\n    context_before: \n    context_after: \n    selector: \n    bounds: \n    element_text: \n    attachments: []\nsummary: looks good\n"
    ),
  )
}

///|
test "review to yaml escapes special chars" {
  let result : ReviewResult = {
    file: "test.csv",
    mode: Csv,
    comments: [
      {
        file: Some("test.csv"),
        row: 0,
        col: 0,
        end_row: Some(0),
        end_col: Some(0),
        text: "has: colon and #hash",
        value: "",
        snippet: Some(""),
        context_before: "",
        context_after: "",
        selector: None,
        bounds: None,
        element_text: None,
        attachments: None,
        image_path: "",
      },
    ],
    summary: "it's fine",
    summary_images: [],
    answers: "",
    mermaid_errors: [],
    decision: None,
    action: Some(FinalApprove),
  }
  debug_inspect(
    review_to_yaml(result),
    content=(
      #|"action: final_approve\nfile: test.csv\nmode: csv\ncomments:\n  - file: test.csv\n    row: 0\n    col: 0\n    end_row: 0\n    end_col: 0\n    text: 'has: colon and #hash'\n    snippet: \n    context_before: \n    context_after: \n    selector: \n    bounds: \n    element_text: \n    attachments: []\nsummary: 'it''s fine'\n"
    ),
  )
}

///|
test "reviews to yaml multiple files" {
  let results = [
    ReviewResult::{
      file: "a.csv",
      mode: Csv,
      comments: [],
      summary: "ok",
      summary_images: [],
      answers: "",
      mermaid_errors: [],
      decision: None,
      action: Some(FinalApprove),
    },
    {
      file: "b.md",
      mode: Markdown,
      comments: [],
      summary: "ok",
      summary_images: [],
      answers: "",
      mermaid_errors: [],
      decision: None,
      action: Some(FinalApprove),
    },
  ]
  debug_inspect(
    reviews_to_yaml(results),
    content=(
      #|"action: final_approve\nfiles:\n  - file: a.csv\n    mode: csv\n    comments:\n    summary: ok\n  - file: b.md\n    mode: markdown\n    comments:\n    summary: ok\n"
    ),
  )
}

///|
test "yaml escape empty value omitted" {
  let result : ReviewResult = {
    file: "f.csv",
    mode: Csv,
    comments: [
      {
        file: None,
        row: 0,
        col: 0,
        end_row: None,
        end_col: None,
        text: "note",
        value: "",
        snippet: None,
        context_before: "",
        context_after: "",
        selector: None,
        bounds: None,
        element_text: None,
        attachments: None,
        image_path: "",
      },
    ],
    summary: "done",
    summary_images: [],
    answers: "",
    mermaid_errors: [],
    decision: None,
    action: Some(FinalApprove),
  }
  let yaml = review_to_yaml(result)
  // value should not appear when empty
  debug_inspect(
    yaml.contains("value:"),
    content=(
      #|false
    ),
  )
}

///|
test "review to yaml includes structured context and image path" {
  let result : ReviewResult = {
    file: "test.md",
    mode: Markdown,
    comments: [
      {
        file: Some("test.md"),
        row: 2,
        col: 1,
        end_row: Some(2),
        end_col: Some(1),
        text: "needs context",
        value: "target line",
        snippet: Some("before line\ntarget line\nafter line"),
        context_before: "before line",
        context_after: "after line",
        selector: Some("#target"),
        bounds: Some("{\"x\":1,\"y\":2,\"width\":3,\"height\":4}"),
        element_text: Some("target line"),
        attachments: Some(["./comment-attachments/c-1-1.png"]),
        image_path: "/tmp/yunomi/image_0.png",
      },
    ],
    summary: "done",
    summary_images: [],
    answers: "",
    mermaid_errors: [],
    decision: None,
    action: Some(FinalRequestChanges),
  }
  debug_inspect(
    review_to_yaml(result),
    content=(
      #|"action: final_request_changes\nfile: test.md\nmode: markdown\ncomments:\n  - file: test.md\n    row: 2\n    col: 1\n    end_row: 2\n    end_col: 1\n    text: needs context\n    value: target line\n    snippet: 'before line\ntarget line\nafter line'\n    context_before: before line\n    context_after: after line\n    selector: '#target'\n    bounds: '{\"x\":1,\"y\":2,\"width\":3,\"height\":4}'\n    element_text: target line\n    attachments:\n      - ./comment-attachments/c-1-1.png\n    image_path: /tmp/yunomi/image_0.png\nsummary: done\n"
    ),
  )
}

///|
test "review to yaml includes summary image paths" {
  let result : ReviewResult = {
    file: "test.md",
    mode: Markdown,
    comments: [],
    summary: "see attached",
    summary_images: [
      "/Users/example/.yunomi/outputs/summary-srv-123-0.png", "/Users/example/.yunomi/outputs/summary-srv-123-1.jpg",
    ],
    answers: "",
    mermaid_errors: [],
    decision: None,
    action: Some(FinalRequestChanges),
  }
  debug_inspect(
    review_to_yaml(result),
    content=(
      #|"action: final_request_changes\nfile: test.md\nmode: markdown\ncomments:\nsummary: see attached\nsummary_images:\n  - /Users/example/.yunomi/outputs/summary-srv-123-0.png\n  - /Users/example/.yunomi/outputs/summary-srv-123-1.jpg\n"
    ),
  )
}

///|
/// Regression for the "answers gets truncated / corrupted" bug: the answers
/// field carries a JSON string (as produced by json_parse_json_field on the
/// client-submitted body) containing Japanese text, an emoji, and a
/// JSON-escaped quote + newline. yaml_escape_string must pass every
/// character through untouched (only doubling literal single quotes) so the
/// full JSON text survives the trip into the verdict YAML byte-for-byte.
test "review to yaml preserves unicode answers (japanese + emoji + escapes)" {
  let answers =
    #|{"q1-help-overlay":"採用","q4-agent-comment":"エージェントへのコメント機能は非常に重要な体験改善だと思います。長文の日本語フィードバックが途中で切れずに反映されることを確認したいです。絵文字も安全か確認します🎉。\"引用\"や改行(\n)を含む文章でも壊れないこと。"}
  let result : ReviewResult = {
    file: "test.md",
    mode: Markdown,
    comments: [],
    summary: "ok",
    summary_images: [],
    answers,
    mermaid_errors: [],
    decision: None,
    action: None,
  }
  let yaml = review_to_yaml(result)
  // The full JSON text (with its escaped quote and escaped newline intact)
  // must appear verbatim inside the single-quoted YAML scalar — nothing
  // truncated, nothing mangled.
  debug_inspect(yaml.contains(answers), content="true")
  debug_inspect(
    yaml.contains("エージェントへのコメント機能"),
    content="true",
  )
  debug_inspect(yaml.contains("🎉"), content="true")
  // Answer text must not be cut short anywhere before its final character.
  debug_inspect(yaml.contains("壊れないこと。\"}'"), content="true")
}

///|
/// Same guarantee on the multi-file YAML path (reviews_to_yaml), which has
/// its own independent answers-serialization branch.
test "reviews to yaml preserves unicode answers across multiple files" {
  let answers =
    #|{"q2-multifile":"これって何の意味ある？moonbitのモダン化ならやっていいよ。","q3-plan-hook":"これ体験してないので、わからない。"}
  let results = [
    ReviewResult::{
      file: "a.md",
      mode: Markdown,
      comments: [],
      summary: "ok",
      summary_images: [],
      answers,
      mermaid_errors: [],
      decision: None,
      action: None,
    },
  ]
  let yaml = reviews_to_yaml(results)
  debug_inspect(yaml.contains(answers), content="true")
  debug_inspect(
    yaml.contains("これって何の意味ある？"),
    content="true",
  )
}

///|
/// Undo the single-quote-doubling performed by yaml_escape_string, given the
/// inner content of a single-quoted YAML scalar (outer quotes stripped).
fn undouble_single_quotes(s : String) -> String {
  let chars = s.to_array()
  let len = chars.length()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    if chars[i] == '\'' && i + 1 < len && chars[i + 1] == '\'' {
      buf.write_char('\'')
      i = i + 2
    } else {
      buf.write_char(chars[i])
      i = i + 1
    }
  }
  buf.to_string()
}

///|
/// Property check on the escaping primitive itself: for any string built
/// from Japanese text, an emoji (surrogate pair in UTF-16, single code point
/// in MoonBit's Char), embedded double quotes, a backslash, and an
/// escaped-newline sequence, unescaping yaml_escape_string's output (strip
/// outer quotes, undouble '') must reconstruct the exact original — no
/// char is ever silently dropped or split.
test "yaml_escape_string round-trips unicode without loss" {
  let original =
    #|エージェント🎉テスト "quoted" back\slash and \n escaped-newline, comma, colon: value
  let escaped = yaml_escape_string(original)
  let chars = escaped.to_array()
  // Must be wrapped in single quotes since it contains ':' etc.
  debug_inspect(chars[0] == '\'', content="true")
  debug_inspect(chars[chars.length() - 1] == '\'', content="true")
  let inner = safe_slice_range(escaped, 1, chars.length() - 1)
  let restored = undouble_single_quotes(inner)
  debug_inspect(restored == original, content="true")
}

///|
test "review to yaml with mermaid errors" {
  let result : ReviewResult = {
    file: "test.md",
    mode: Markdown,
    comments: [],
    summary: "no comments",
    summary_images: [],
    answers: "",
    mermaid_errors: [
      { line: 12, message: "Parse error on line 2" },
      { line: 25, message: "Expecting 'TXT', got 'NEWLINE'" },
    ],
    decision: None,
    action: Some(FinalApprove),
  }
  debug_inspect(
    review_to_yaml(result),
    content=(
      #|"action: final_approve\nfile: test.md\nmode: markdown\ncomments:\nsummary: no comments\nmermaid_errors:\n  - line: 12\n    error: Parse error on line 2\n  - line: 25\n    error: 'Expecting ''TXT'', got ''NEWLINE'''\n"
    ),
  )
}
