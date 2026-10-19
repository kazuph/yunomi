///|
test "cell display preserves selection and ignores non-table columns" {
  let source = "| alpha | ok | note |"
  let cell = "Markdown table cell: source line 7, column 3: note | source: " + source
  assert_eq(comment_display_quote(source, cell, ""), "note")
  assert_eq(comment_display_quote(source, "", cell), "note")
  assert_eq(comment_display_quote("ot", cell, ""), "ot")
  assert_eq(comment_display_quote("source text", "ordinary column value", ""), "source text")
  let image = "Markdown table cell: source line 7, column 3, image \"cat\": Image alt=\"cat\" src=\"cat.png\" | source: " + source
  assert_eq(comment_display_quote(source, image, ""), "画像「cat」")
  assert_eq(comment_display_quote("selected image text", "", image), "selected image text")
}

///|
test "final yaml displays table cell while keeping stored comment source quote" {
  let source = "| alpha | ok | note |"
  let descriptor = "Markdown table cell: source line 7, column 3: note | source: " + source
  let comment : Comment = {
    file: Some("r.md"), row: 6, col: 3, end_row: Some(6), end_col: Some(3),
    text: "fix", quote: Some(source), value: "", snippet: Some(source),
    context_before: "", context_after: "", selector: None, bounds: None,
    element_text: Some(descriptor), attachments: None, image_path: "",
  }
  let result : ReviewResult = {
    file: "r.md", mode: Markdown, comments: [comment], summary: "", summary_images: [],
    answers: "", mermaid_errors: [], decision: None, action: Some(FinalRequestChanges),
  }
  let yaml = review_to_yaml(result)
  assert_true(yaml.contains("col: 3"))
  assert_true(yaml.contains("quote: note\n"))
  assert_eq(comment.quote, Some(source))
}

///|
test "comment Markdown keeps frontmatter-like text while document frontmatter is unchanged" {
  let source = "---\ntitle: retained instruction\n---\nTail"
  assert_true(parse_comment_markdown(source).contains("retained instruction"))
  assert_false(parse_markdown(source).html.contains("retained instruction"))
  assert_true(parse_comment_markdown("---\nKeep unclosed").contains("Keep unclosed"))
}

///|
test "cell display also recognizes the existing stored source-quote length limit" {
  let long = "| " + "x".repeat(400) + " | tail |"
  let descriptor = "Markdown table cell: source line 5, column 2: tail | source: " + long
  assert_eq(comment_display_quote(quote_source_line([long], 0), descriptor, ""), "tail")
}
