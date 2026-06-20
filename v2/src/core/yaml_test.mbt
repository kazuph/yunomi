///|
test "review to yaml single file" {
  let result : ReviewResult = {
    file: "data.csv",
    mode: Csv,
    comments: [{ row: 1, col: 2, text: "needs review", value: "150" }],
    summary: "looks good",
    answers: "",
    mermaid_errors: [],
    decision: None,
    action: Some(FinalApprove),
  }
  debug_inspect(
    review_to_yaml(result),
    content=(
      #|"action: final_approve\nfile: data.csv\nmode: csv\ncomments:\n  - row: 1\n    col: 2\n    text: needs review\n    value: 150\nsummary: looks good\n"

    ),
  )
}

///|
test "review to yaml escapes special chars" {
  let result : ReviewResult = {
    file: "test.csv",
    mode: Csv,
    comments: [{ row: 0, col: 0, text: "has: colon and #hash", value: "" }],
    summary: "it's fine",
    answers: "",
    mermaid_errors: [],
    decision: None,
    action: Some(FinalApprove),
  }
  debug_inspect(
    review_to_yaml(result),
    content=(
      #|"action: final_approve\nfile: test.csv\nmode: csv\ncomments:\n  - row: 0\n    col: 0\n    text: 'has: colon and #hash'\nsummary: 'it''s fine'\n"

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
    comments: [{ row: 0, col: 0, text: "note", value: "" }],
    summary: "done",
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
test "review to yaml with mermaid errors" {
  let result : ReviewResult = {
    file: "test.md",
    mode: Markdown,
    comments: [],
    summary: "no comments",
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
