///|
/// Parse markdown source into MarkdownData with HTML and frontmatter
pub fn parse_markdown(input : String) -> MarkdownData {
  if input.length() == 0 {
    return { source: "", html: "", frontmatter: {}, questions: [] }
  }
  let lines = split_to_lines(input)
  let frontmatter : Map[String, String] = {}
  let mut content_start = 0
  // Parse YAML frontmatter
  if lines.length() > 0 && lines[0] == "---" {
    let mut end_idx = -1
    for i in 1..<lines.length() {
      if lines[i] == "---" {
        end_idx = i
        break
      }
    }
    if end_idx > 0 {
      // The `yunomi:` top-level key introduces a nested YAML block
      // (questions: - id/question/context/options...) that
      // parse_yunomi_questions() below already parses properly, structure
      // and all. This generic key:val scanner has no indentation/nesting
      // awareness at all — it happily reads "id:", "question:", "context:",
      // "- id:" etc. out of that nested block as if they were flat
      // top-level frontmatter keys, and since the SAME nested key repeats
      // once per question, each question's value silently overwrote the
      // previous one in the map. The net effect: the Document Metadata
      // table showed only the LAST question's id/context/etc, duplicating
      // (and mangling) content the questions modal already owns and
      // displays correctly. Fix: track whether we're inside the `yunomi:`
      // block by indentation (a line with zero leading spaces is a new
      // top-level key, ending the block) and skip every line inside it —
      // both the `yunomi:` key itself (its value is a block mapping, not
      // meaningful text) and everything nested under it.
      let mut in_yunomi_section = false
      for i in 1..<end_idx {
        let line = lines[i]
        if line.length() > 0 && leading_spaces(line) == 0 {
          // Top-level (unindented) line: (re)evaluate whether this starts
          // the yunomi block.
          let colon = index_of_char(line, ':')
          if colon >= 0 {
            let key = trim(safe_slice_range(line, 0, colon))
            if key == "yunomi" {
              in_yunomi_section = true
            } else {
              in_yunomi_section = false
              let val = trim(safe_slice(line, colon + 1))
              if key.length() > 0 {
                frontmatter[key] = val
              }
            }
          } else {
            in_yunomi_section = false
          }
        } else if leading_spaces(line) > 0 {
          // Indented line: part of whatever top-level block we're
          // currently in. Only skip it if that block is `yunomi:` —
          // preserve prior (naive but unrelated) behavior for any other
          // indented/nested frontmatter key, since only the yunomi section
          // was reported as duplicated/mangled.
          if !in_yunomi_section {
            let colon = index_of_char(line, ':')
            if colon >= 0 {
              let key = trim(safe_slice_range(line, 0, colon))
              let val = trim(safe_slice(line, colon + 1))
              if key.length() > 0 {
                frontmatter[key] = val
              }
            }
          }
        }
        // Blank line: leave in_yunomi_section untouched (may be inside a
        // `context: |` block scalar's own content).
      }
      content_start = end_idx + 1
    }
  }
  // Build content lines (skip frontmatter)
  let content_lines : Array[String] = []
  for i in content_start..<lines.length() {
    content_lines.push(lines[i])
  }
  let definitions = collect_markdown_definitions(content_lines)
  let html = render_markdown_lines(
      content_lines,
      references=definitions.0,
      footnotes=definitions.1,
    ) +
    render_footnotes(definitions.1, definitions.0)
  // Build source (content without frontmatter)
  let src_buf = StringBuilder::new()
  for i, line in content_lines {
    if i > 0 {
      src_buf.write_string("\n")
    }
    src_buf.write_string(line)
  }
  // Parse yunomi questions from frontmatter lines
  let questions = parse_yunomi_questions(
    lines,
    0,
    if content_start > 0 {
      content_start
    } else {
      0
    },
  )
  { source: src_buf.to_string(), html, frontmatter, questions }
}

///|
/// Find index of first occurrence of a char in string, -1 if not found
fn index_of_char(s : String, target : Char) -> Int {
  let chars = s.to_array()
  for i, ch in chars {
    if ch == target {
      return i
    }
  }
  -1
}

///|
/// Trim leading and trailing whitespace
fn trim(s : String) -> String {
  let chars = s.to_array()
  let len = chars.length()
  if len == 0 {
    return ""
  }
  let mut start = 0
  while start < len && is_whitespace(chars[start]) {
    start = start + 1
  }
  let mut end = len - 1
  while end >= start && is_whitespace(chars[end]) {
    end = end - 1
  }
  if start > end {
    return ""
  }
  let buf = StringBuilder::new()
  for i in start..<=end {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
/// Check if char is whitespace
fn is_whitespace(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
}

///|
/// Counter for heading keys
let heading_counter : Ref[Int] = Ref(0)

///|
/// Count heading level (number of # at start)
fn count_heading_level(line : String) -> Int {
  let chars = line.to_array()
  let mut count = 0
  while count < chars.length() && chars[count] == '#' {
    count = count + 1
  }
  // Must have space after #s
  if count > 0 && count < chars.length() && chars[count] == ' ' {
    count
  } else {
    0
  }
}

///|
/// Make heading key for localStorage (slug + counter for uniqueness)
fn make_heading_key(text : String, counter : Int) -> String {
  let chars = text.to_array()
  let buf = StringBuilder::new()
  for ch in chars {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      buf.write_char(ch)
    } else if ch >= 'A' && ch <= 'Z' {
      // Convert uppercase to lowercase: add 32 to ASCII code
      let lower = (ch.to_int() + 32).unsafe_to_char()
      buf.write_char(lower)
    } else if ch == ' ' || ch == '-' {
      buf.write_char('-')
    }
  }
  buf.write_char('-')
  buf.write_string(counter.to_string())
  buf.to_string()
}

///|
/// Collect document-level Markdown reference and footnote definitions.
fn collect_markdown_definitions(
  lines : Array[String],
) -> (Map[String, String], Map[String, String]) {
  let references : Map[String, String] = {}
  let footnotes : Map[String, String] = {}
  for line in lines {
    let trimmed = trim(line)
    let chars = trimmed.to_array()
    if chars.length() < 4 || chars[0] != '[' {
      continue
    }
    let mut close = -1
    for i in 1..<chars.length() {
      if chars[i] == ']' {
        close = i
        break
      }
    }
    if close < 2 || close + 1 >= chars.length() || chars[close + 1] != ':' {
      continue
    }
    let is_footnote = chars[1] == '^'
    let key_start = if is_footnote { 2 } else { 1 }
    if close <= key_start {
      continue
    }
    let key = safe_slice_range(trimmed, key_start, close)
    let value = trim(safe_slice(trimmed, close + 2))
    if key.length() == 0 || value.length() == 0 {
      continue
    }
    if is_footnote {
      footnotes[key] = value
    } else {
      references[key] = value
    }
  }
  (references, footnotes)
}

///|
fn is_markdown_definition(line : String) -> Bool {
  let chars = trim(line).to_array()
  if chars.length() < 4 || chars[0] != '[' {
    return false
  }
  for i in 1..<chars.length() {
    if chars[i] == ']' {
      return i + 1 < chars.length() && chars[i + 1] == ':'
    }
  }
  false
}

///|
fn render_footnotes(
  footnotes : Map[String, String],
  references : Map[String, String],
) -> String {
  let buf = StringBuilder::new()
  let mut has_footnotes = false
  footnotes.each(fn(id, content) {
    if !has_footnotes {
      has_footnotes = true
      buf.write_string(
        "<section class=\"footnotes\" aria-label=\"Footnotes\"><ol>",
      )
    }
    buf.write_string("<li id=\"footnote-")
    buf.write_string(escape_html(id))
    buf.write_string("\">")
    buf.write_string(render_inline(content, references~, footnotes~))
    buf.write_string(" <a href=\"#footnote-ref-")
    buf.write_string(escape_html(id))
    buf.write_string(
      "\" target=\"_blank\" rel=\"noopener noreferrer\" aria-label=\"Back to reference\">↩</a></li>",
    )
  })
  if has_footnotes {
    buf.write_string("</ol></section>")
  }
  buf.to_string()
}

///|
/// Render markdown lines to HTML
///
/// `line_offset` is the 0-indexed absolute position (within the full,
/// frontmatter-stripped source) of `lines[0]`. It is 0 for the top-level
/// call and non-zero when recursing into a `<details>` block's inner
/// content, so that data-source-line/data-row attributes stay accurate
/// against the real source instead of restarting from 0 for every nested
/// block (which used to desync them from `comment.row`/`.md-right`).
fn render_markdown_lines(
  lines : Array[String],
  line_offset? : Int = 0,
  references? : Map[String, String] = {},
  footnotes? : Map[String, String] = {},
) -> String {
  heading_counter.val = 0
  let buf = StringBuilder::new()
  let mut i = 0
  let len = lines.length()
  while i < len {
    let line = lines[i]
    // Skip empty lines
    if trim(line).length() == 0 {
      i = i + 1
      continue
    }
    if is_markdown_definition(line) {
      i = i + 1
      continue
    }
    // HTML block pass-through (e.g., <details>, <div>, etc.)
    if line.has_prefix("<") && is_html_block_start(line) {
      let tag_name = extract_html_tag_name(line)
      if tag_name == "details" {
        // Special handling: parse markdown inside <details> (except <summary>)
        let details_start_line = i + 1 + line_offset
        let details_attrs = "data-source-start-line=\"" +
          details_start_line.to_string() +
          "\" data-source-line=\"" +
          details_start_line.to_string() +
          "\""
        buf.write_string(
          inject_attrs_into_open_tag(sanitize_html(line), details_attrs),
        )
        buf.write_string("\n")
        i = i + 1
        // Collect summary line if present
        while i < len {
          let current = trim(lines[i])
          if current.has_prefix("<summary") {
            let summary_attrs = "data-source-line=\"" +
              (i + 1 + line_offset).to_string() +
              "\""
            buf.write_string(
              inject_attrs_into_open_tag(sanitize_html(lines[i]), summary_attrs),
            )
            buf.write_string("\n")
            i = i + 1
            break
          } else if current.has_prefix("</details>") {
            break
          }
          i = i + 1
        }
        // Collect inner content lines (between summary and </details>)
        // `i` right now points at the first inner line, so this is its
        // absolute (offset-adjusted) 0-indexed position in the real source.
        let inner_start_line = i + line_offset
        let inner_lines : Array[String] = []
        let mut depth = 1
        while i < len && depth > 0 {
          let current = lines[i]
          if current.contains("</details>") {
            depth = depth - 1
            if depth == 0 {
              i = i + 1
              break
            }
          }
          if current.contains("<details") {
            depth = depth + 1
          }
          inner_lines.push(current)
          i = i + 1
        }
        // Render inner content as markdown, preserving true source line
        // numbers so data-row/data-col/data-source-line stay in sync with
        // comment.row (computed against the full frontmatter-stripped source).
        if inner_lines.length() > 0 {
          let inner_html = render_markdown_lines(
            inner_lines,
            line_offset=inner_start_line,
            references~,
            footnotes~,
          )
          buf.write_string(inner_html)
          buf.write_string("\n")
        }
        buf.write_string("</details>\n")
      } else {
        // Generic HTML block: pass through as-is
        let html_buf = StringBuilder::new()
        let html_start_line = i + 1 + line_offset
        // Void tags and one-liners that already close on the start line
        // must not swallow the following markdown
        let mut depth = if is_void_tag(tag_name) ||
          line.contains("</" + tag_name + ">") {
          0
        } else {
          1
        }
        html_buf.write_string(line)
        html_buf.write_string("\n")
        i = i + 1
        while i < len && depth > 0 {
          let current = lines[i]
          if current.contains("<" + tag_name) {
            depth = depth + 1
          }
          if current.contains("</" + tag_name + ">") {
            depth = depth - 1
          }
          html_buf.write_string(current)
          html_buf.write_string("\n")
          i = i + 1
        }
        buf.write_string(
          "<div class=\"markdown-html-block\" data-source-start-line=\"",
        )
        buf.write_string(html_start_line.to_string())
        buf.write_string("\" data-source-end-line=\"")
        buf.write_string((i + line_offset).to_string())
        buf.write_string("\" data-source-line=\"")
        buf.write_string(html_start_line.to_string())
        buf.write_string("\">")
        buf.write_string(sanitize_html(html_buf.to_string()))
        buf.write_string("</div>\n")
      }
      continue
    }
    // Heading
    if line.has_prefix("#") {
      let level = count_heading_level(line)
      if level >= 1 && level <= 6 {
        let content = trim(safe_slice(line, level + 1))
        let heading_key = make_heading_key(content, heading_counter.val)
        heading_counter.val = heading_counter.val + 1
        buf.write_string("<h")
        buf.write_string(level.to_string())
        buf.write_string(" class=\"md-heading-toggle\" data-heading-key=\"")
        buf.write_string(escape_html(heading_key))
        buf.write_string("\" data-heading-level=\"")
        buf.write_string(level.to_string())
        buf.write_string("\" data-source-line=\"")
        buf.write_string((i + 1 + line_offset).to_string())
        buf.write_string(
          "\"><span class=\"heading-toggle-icon\">\u{25BC}</span>",
        )
        buf.write_string(
          render_inline(
            content,
            source_line=i + 1 + line_offset,
            references~,
            footnotes~,
          ),
        )
        buf.write_string("</h")
        buf.write_string(level.to_string())
        buf.write_string(">\n")
        i = i + 1
        continue
      }
    }
    // Horizontal rule
    if is_horizontal_rule(line) {
      buf.write_string("<hr data-source-line=\"")
      buf.write_string((i + 1 + line_offset).to_string())
      buf.write_string("\" />\n")
      i = i + 1
      continue
    }
    // Code block
    if line.has_prefix("```") || line.has_prefix("~~~") {
      let fence = if line.has_prefix("~~~") { "~~~" } else { "```" }
      let lang = trim(safe_slice(line, 3))
      let code_block_start_line = i + 1 + line_offset // 1-indexed line number of ```mermaid
      i = i + 1
      let code_buf = StringBuilder::new()
      let mut code_first = true
      while i < len && !lines[i].has_prefix(fence) {
        if !code_first {
          code_buf.write_string("\n")
        }
        code_first = false
        code_buf.write_string(lines[i])
        i = i + 1
      }
      let code_block_end_line = if i < len {
        i + 1 + line_offset
      } else {
        len + line_offset
      }
      if i < len {
        i = i + 1 // skip closing ```
      }
      let code_text = code_buf.to_string()
      if lang == "mermaid" || is_mermaid_content(code_text) {
        // Mermaid diagram: render as mermaid container for client-side rendering
        buf.write_string(
          "<div class=\"mermaid-container\" data-source-start-line=\"",
        )
        buf.write_string(code_block_start_line.to_string())
        buf.write_string("\" data-source-end-line=\"")
        buf.write_string(code_block_end_line.to_string())
        buf.write_string("\"><div class=\"mermaid\" data-source=\"")
        buf.write_string(escape_html(code_text))
        buf.write_string("\" data-source-line=\"")
        buf.write_string(code_block_start_line.to_string())
        buf.write_string("\">")
        buf.write_string(escape_html(code_text))
        buf.write_string("</div></div>\n")
      } else {
        buf.write_string("<pre data-source-start-line=\"")
        buf.write_string(code_block_start_line.to_string())
        buf.write_string("\" data-source-end-line=\"")
        buf.write_string(code_block_end_line.to_string())
        buf.write_string("\"><code")
        if lang.length() > 0 {
          buf.write_string(" class=\"language-")
          buf.write_string(escape_html(lang))
          buf.write_string("\"")
        }
        buf.write_string(">")
        buf.write_string(escape_html(code_text))
        buf.write_string("</code></pre>\n")
      }
      continue
    }
    // Blockquote
    if line.has_prefix(">") {
      let quote_lines : Array[String] = []
      let quote_start_line = i + 1 + line_offset
      while i < len && lines[i].has_prefix(">") {
        let content = trim(safe_slice(lines[i], 1))
        quote_lines.push(content)
        i = i + 1
      }
      buf.write_string("<blockquote data-source-line=\"")
      buf.write_string(quote_start_line.to_string())
      buf.write_string("\" data-source-start-line=\"")
      buf.write_string(quote_start_line.to_string())
      buf.write_string("\" data-source-end-line=\"")
      buf.write_string((i + line_offset).to_string())
      buf.write_string("\">")
      buf.write_string(
        render_markdown_lines(
          quote_lines,
          line_offset=quote_start_line - 1,
          references~,
          footnotes~,
        ),
      )
      buf.write_string("</blockquote>\n")
      continue
    }
    // Lists, including nested and multi-line items.
    let list_kind = markdown_list_kind(line)
    if list_kind > 0 && leading_spaces(line) == 0 {
      let rendered = render_markdown_list(
        lines,
        i,
        line_offset,
        0,
        list_kind,
        references~,
        footnotes~,
      )
      buf.write_string(rendered.0)
      i = rendered.1
      continue
    }
    // Table
    if i + 1 < len && is_table_separator(lines[i + 1]) {
      let header_line = i + 1 + line_offset
      buf.write_string("<div class=\"table-container\" data-source-line=\"")
      buf.write_string(header_line.to_string())
      buf.write_string("\">\n<table data-source-line=\"")
      buf.write_string(header_line.to_string())
      buf.write_string("\">\n<thead>\n<tr data-source-line=\"")
      buf.write_string(header_line.to_string())
      buf.write_string("\">\n")
      let headers = parse_table_row(line)
      for col_idx, h in headers {
        buf.write_string("<th data-source-line=\"")
        buf.write_string(header_line.to_string())
        buf.write_string("\" data-row=\"")
        buf.write_string((header_line - 1).to_string())
        buf.write_string("\" data-col=\"")
        buf.write_string((col_idx + 1).to_string())
        buf.write_string("\">")
        buf.write_string(
          render_inline(
            trim(h),
            source_line=header_line,
            references~,
            footnotes~,
          ),
        )
        buf.write_string("</th>\n")
      }
      buf.write_string("</tr>\n</thead>\n<tbody>\n")
      i = i + 2 // skip header + separator
      while i < len && lines[i].contains("|") {
        let row_line = i + 1 + line_offset
        let cells = parse_table_row(lines[i])
        buf.write_string("<tr data-source-line=\"")
        buf.write_string(row_line.to_string())
        buf.write_string("\">\n")
        for col_idx, cell in cells {
          buf.write_string("<td data-source-line=\"")
          buf.write_string(row_line.to_string())
          buf.write_string("\" data-row=\"")
          buf.write_string((row_line - 1).to_string())
          buf.write_string("\" data-col=\"")
          buf.write_string((col_idx + 1).to_string())
          buf.write_string("\">")
          buf.write_string(
            render_inline(
              trim(cell),
              source_line=row_line,
              references~,
              footnotes~,
            ),
          )
          buf.write_string("</td>\n")
        }
        buf.write_string("</tr>\n")
        i = i + 1
      }
      buf.write_string("</tbody>\n</table>\n</div>\n")
      continue
    }
    // Paragraph (collect contiguous non-empty, non-block lines)
    let para_buf = StringBuilder::new()
    let mut para_first = true
    let para_start_line = i + 1 + line_offset
    while i < len && trim(lines[i]).length() > 0 && !is_block_start(lines[i]) {
      if !para_first {
        para_buf.write_string(" ")
      }
      para_first = false
      para_buf.write_string(lines[i])
      i = i + 1
    }
    let para_text = para_buf.to_string()
    if para_text.length() > 0 {
      buf.write_string("<p data-source-start-line=\"")
      buf.write_string(para_start_line.to_string())
      buf.write_string("\" data-source-end-line=\"")
      buf.write_string((i + line_offset).to_string())
      buf.write_string("\">")
      buf.write_string(
        render_inline(
          para_text,
          source_line=para_start_line,
          references~,
          footnotes~,
        ),
      )
      buf.write_string("</p>\n")
    }
  }
  trim(buf.to_string())
}

///|
/// Return 1 for unordered items, 2 for ordered items, or 0 otherwise.
fn markdown_list_kind(line : String) -> Int {
  let content = trim(line)
  if content.has_prefix("- ") || content.has_prefix("* ") {
    1
  } else if is_ordered_list_item(content) {
    2
  } else {
    0
  }
}

///|
fn markdown_list_item_text(line : String, kind : Int) -> String {
  let content = trim(line)
  if kind == 1 {
    safe_slice(content, 2)
  } else {
    extract_ordered_list_content(content)
  }
}

///|
/// Render one indentation level and recurse for nested list items. The
/// returned index is the first source line not consumed by this list.
fn render_markdown_list(
  lines : Array[String],
  start : Int,
  line_offset : Int,
  indent : Int,
  kind : Int,
  references? : Map[String, String] = {},
  footnotes? : Map[String, String] = {},
) -> (String, Int) {
  let buf = StringBuilder::new()
  let tag = if kind == 1 { "ul" } else { "ol" }
  let first_line = start + 1 + line_offset
  buf.write_string("<")
  buf.write_string(tag)
  buf.write_string(" data-source-line=\"")
  buf.write_string(first_line.to_string())
  buf.write_string("\">\n")
  let mut i = start
  while i < lines.length() &&
        leading_spaces(lines[i]) == indent &&
        markdown_list_kind(lines[i]) == kind {
    let item_line = i + 1 + line_offset
    let item_text = markdown_list_item_text(lines[i], kind)
    let task_open = item_text.has_prefix("[ ] ")
    let task_done = item_text.has_prefix("[x] ") || item_text.has_prefix("[X] ")
    let decision_done = item_text.has_prefix("✅️ ")
    if task_open || task_done {
      buf.write_string("<li class=\"task-list-item\" data-source-line=\"")
    } else if decision_done {
      buf.write_string("<li class=\"decision-done\" data-source-line=\"")
    } else {
      buf.write_string("<li data-source-line=\"")
    }
    buf.write_string(item_line.to_string())
    buf.write_string("\">")
    if task_open || task_done {
      let task_text = safe_slice(item_text, 4)
      buf.write_string(
        "<input class=\"task-decision-checkbox\" type=\"checkbox\"",
      )
      if task_done {
        buf.write_string(" checked")
      }
      buf.write_string(" data-source-line=\"")
      buf.write_string(item_line.to_string())
      buf.write_string("\" data-decision-text=\"")
      buf.write_string(escape_html(task_text))
      buf.write_string("\" /> ")
      buf.write_string(
        render_inline(task_text, source_line=item_line, references~, footnotes~),
      )
    } else if decision_done {
      buf.write_string(
        render_inline(
          safe_slice(item_text, 3),
          source_line=item_line,
          references~,
          footnotes~,
        ),
      )
    } else {
      buf.write_string(
        render_inline(item_text, source_line=item_line, references~, footnotes~),
      )
    }
    i = i + 1
    while i < lines.length() {
      if trim(lines[i]).length() == 0 {
        if i + 1 < lines.length() && leading_spaces(lines[i + 1]) > indent {
          i = i + 1
          continue
        }
        break
      }
      if leading_spaces(lines[i]) <= indent {
        break
      }
      let child_kind = markdown_list_kind(lines[i])
      let child_line = trim(lines[i])
      if child_line.has_prefix("```") || child_line.has_prefix("~~~") {
        let fence = if child_line.has_prefix("~~~") { "~~~" } else { "```" }
        let code_start = i
        let fence_indent = leading_spaces(lines[i])
        let nested_code : Array[String] = []
        nested_code.push(child_line)
        i = i + 1
        while i < lines.length() {
          let raw_code_line = lines[i]
          let code_line = if leading_spaces(raw_code_line) >= fence_indent {
            safe_slice(raw_code_line, fence_indent)
          } else {
            raw_code_line
          }
          nested_code.push(code_line)
          i = i + 1
          if trim(code_line).has_prefix(fence) {
            break
          }
        }
        buf.write_string("\n")
        buf.write_string(
          render_markdown_lines(
            nested_code,
            line_offset=code_start + line_offset,
            references~,
            footnotes~,
          ),
        )
      } else if child_kind > 0 {
        let child = render_markdown_list(
          lines,
          i,
          line_offset,
          leading_spaces(lines[i]),
          child_kind,
          references~,
          footnotes~,
        )
        buf.write_string("\n")
        buf.write_string(child.0)
        i = child.1
      } else {
        buf.write_string("<br />")
        buf.write_string(
          render_inline(
            trim(lines[i]),
            source_line=i + 1 + line_offset,
            references~,
            footnotes~,
          ),
        )
        i = i + 1
      }
    }
    buf.write_string("</li>\n")
  }
  buf.write_string("</")
  buf.write_string(tag)
  buf.write_string(">\n")
  (buf.to_string(), i)
}

///|
/// Check if line starts a block element
fn is_block_start(line : String) -> Bool {
  line.has_prefix("#") ||
  line.has_prefix("```") ||
  line.has_prefix("~~~") ||
  line.has_prefix(">") ||
  line.has_prefix("- ") ||
  line.has_prefix("* ") ||
  is_ordered_list_item(line) ||
  is_horizontal_rule(line) ||
  (line.has_prefix("<") && is_html_block_start(line))
}

///|
/// Check if line is a horizontal rule (---, ***, ___)
fn is_horizontal_rule(line : String) -> Bool {
  let t = trim(line)
  if t.length() < 3 {
    return false
  }
  let chars = t.to_array()
  let first = chars[0]
  if first != '-' && first != '*' && first != '_' {
    return false
  }
  for ch in chars {
    if ch != first && ch != ' ' {
      return false
    }
  }
  true
}

///|
/// Check if line is an ordered list item (e.g., "1. text")
fn is_ordered_list_item(line : String) -> Bool {
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
    i = i + 1
  }
  if i == 0 {
    return false
  }
  i < chars.length() - 1 && chars[i] == '.' && chars[i + 1] == ' '
}

///|
/// Extract content after "N. " in ordered list
fn extract_ordered_list_content(line : String) -> String {
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
    i = i + 1
  }
  // skip ". "
  safe_slice(line, i + 2)
}

///|
/// Check if line is a table separator (|---|---|)
fn is_table_separator(line : String) -> Bool {
  let t = trim(line)
  if !t.contains("|") || !t.contains("-") {
    return false
  }
  let chars = t.to_array()
  for ch in chars {
    if ch != '|' && ch != '-' && ch != ':' && ch != ' ' {
      return false
    }
  }
  true
}

///|
/// Parse a table row into cells
fn parse_table_row(line : String) -> Array[String] {
  let result : Array[String] = []
  let t = trim(line)
  // Remove leading and trailing |
  let inner = if t.has_prefix("|") && t.has_suffix("|") {
    safe_slice_range(t, 1, t.length() - 1)
  } else if t.has_prefix("|") {
    safe_slice(t, 1)
  } else {
    t
  }
  for part in inner.split("|") {
    result.push(part.to_owned())
  }
  result
}

///|
/// Render inline markdown (bold, italic, code, links, images)
fn render_inline(
  text : String,
  source_line? : Int = 0,
  references? : Map[String, String] = {},
  footnotes? : Map[String, String] = {},
) -> String {
  let chars = text.to_array()
  let len = chars.length()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    // Image: ![alt](src)
    if i + 1 < len && chars[i] == '!' && chars[i + 1] == '[' {
      let alt_start = i + 2
      let mut alt_end = -1
      let mut j = alt_start
      while j < len {
        if chars[j] == ']' {
          alt_end = j
          break
        }
        j = j + 1
      }
      if alt_end > 0 && alt_end + 1 < len && chars[alt_end + 1] == '(' {
        let url_start = alt_end + 2
        let mut url_end = -1
        j = url_start
        while j < len {
          if chars[j] == ')' {
            url_end = j
            break
          }
          j = j + 1
        }
        if url_end > 0 {
          let alt = safe_slice_range(text, alt_start, alt_end)
          let src = safe_slice_range(text, url_start, url_end)
          // ![alt]() with an empty target renders as a ghost <img> that
          // swallows the literal text (e.g. when quoting the syntax itself)
          // and pollutes the media sidebar — keep it as plain text instead.
          if is_blank_url(src) {
            buf.write_string(
              escape_html(safe_slice_range(text, i, url_end + 1)),
            )
            i = url_end + 1
            continue
          }
          let escaped_src = escape_html(src)
          if is_video_url(src) {
            buf.write_string(
              "<video class=\"video-preview\" controls preload=\"metadata\" src=\"",
            )
            buf.write_string(escaped_src)
            buf.write_string("\" title=\"")
            buf.write_string(escape_html(alt))
            if source_line > 0 {
              buf.write_string("\" data-source-line=\"")
              buf.write_string(source_line.to_string())
            }
            buf.write_string("\"></video>")
          } else {
            buf.write_string("<img src=\"")
            buf.write_string(escaped_src)
            buf.write_string("\" alt=\"")
            buf.write_string(escape_html(alt))
            if source_line > 0 {
              buf.write_string("\" data-source-line=\"")
              buf.write_string(source_line.to_string())
            }
            buf.write_string(
              "\" loading=\"lazy\" style=\"max-width:100%;height:auto;\" />",
            )
          }
          i = url_end + 1
          continue
        }
      }
    }
    // Footnote reference: [^id]
    if i + 2 < len && chars[i] == '[' && chars[i + 1] == '^' {
      let mut footnote_end = -1
      let mut j = i + 2
      while j < len {
        if chars[j] == ']' {
          footnote_end = j
          break
        }
        j = j + 1
      }
      if footnote_end > i + 2 {
        let id = safe_slice_range(text, i + 2, footnote_end)
        match footnotes.get(id) {
          Some(_) => {
            buf.write_string(
              "<sup class=\"footnote-ref\"><a id=\"footnote-ref-",
            )
            buf.write_string(escape_html(id))
            buf.write_string("\" href=\"#footnote-")
            buf.write_string(escape_html(id))
            buf.write_string("\" target=\"_blank\" rel=\"noopener noreferrer\">[")
            buf.write_string(escape_html(id))
            buf.write_string("]</a></sup>")
            i = footnote_end + 1
            continue
          }
          None => ()
        }
      }
    }
    // Link: [text](url) or [text][reference]
    if chars[i] == '[' {
      let text_start = i + 1
      let mut text_end = -1
      let mut j = text_start
      while j < len {
        if chars[j] == ']' {
          text_end = j
          break
        }
        j = j + 1
      }
      if text_end > 0 && text_end + 1 < len && chars[text_end + 1] == '(' {
        let url_start = text_end + 2
        let mut url_end = -1
        j = url_start
        while j < len {
          if chars[j] == ')' {
            url_end = j
            break
          }
          j = j + 1
        }
        if url_end > 0 {
          let link_text = safe_slice_range(text, text_start, text_end)
          let link_url = safe_slice_range(text, url_start, url_end)
          // Block javascript: scheme to prevent XSS
          let lower_url = link_url.to_lower()
          if lower_url.has_prefix("javascript:") {
            buf.write_string(
              render_inline(link_text, source_line~, references~, footnotes~),
            )
          } else {
            buf.write_string("<a href=\"")
            buf.write_string(escape_html(link_url))
            buf.write_string("\" target=\"_blank\" rel=\"noopener noreferrer\">")
            buf.write_string(
              render_inline(link_text, source_line~, references~, footnotes~),
            )
            buf.write_string("</a>")
          }
          i = url_end + 1
          continue
        }
      }
      if text_end > 0 && text_end + 1 < len && chars[text_end + 1] == '[' {
        let reference_start = text_end + 2
        let mut reference_end = -1
        j = reference_start
        while j < len {
          if chars[j] == ']' {
            reference_end = j
            break
          }
          j = j + 1
        }
        if reference_end > reference_start {
          let reference_id = safe_slice_range(
            text, reference_start, reference_end,
          )
          match references.get(reference_id) {
            Some(reference_url) => {
              let lower_url = reference_url.to_lower()
              let link_text = safe_slice_range(text, text_start, text_end)
              if lower_url.has_prefix("javascript:") {
                buf.write_string(
                  render_inline(
                    link_text,
                    source_line~,
                    references~,
                    footnotes~,
                  ),
                )
              } else {
                buf.write_string("<a href=\"")
                buf.write_string(escape_html(reference_url))
                buf.write_string(
                  "\" target=\"_blank\" rel=\"noopener noreferrer\">",
                )
                buf.write_string(
                  render_inline(
                    link_text,
                    source_line~,
                    references~,
                    footnotes~,
                  ),
                )
                buf.write_string("</a>")
              }
              i = reference_end + 1
              continue
            }
            None => ()
          }
        }
      }
    }
    // Inline code: `code`
    if chars[i] == '`' {
      let code_start = i + 1
      let mut code_end = -1
      let mut j = code_start
      while j < len {
        if chars[j] == '`' {
          code_end = j
          break
        }
        j = j + 1
      }
      if code_end > 0 {
        buf.write_string("<code>")
        buf.write_string(
          escape_html(safe_slice_range(text, code_start, code_end)),
        )
        buf.write_string("</code>")
        i = code_end + 1
        continue
      }
    }
    // Strikethrough: ~~text~~
    if i + 1 < len && chars[i] == '~' && chars[i + 1] == '~' {
      let del_start = i + 2
      let mut del_end = -1
      let mut j = del_start
      while j + 1 < len {
        if chars[j] == '~' && chars[j + 1] == '~' {
          del_end = j
          break
        }
        j = j + 1
      }
      if del_end > 0 {
        buf.write_string("<del>")
        buf.write_string(
          render_inline(
            safe_slice_range(text, del_start, del_end),
            source_line~,
          ),
        )
        buf.write_string("</del>")
        i = del_end + 2
        continue
      }
    }
    // Bold: **text**
    if i + 1 < len && chars[i] == '*' && chars[i + 1] == '*' {
      let bold_start = i + 2
      // Find closing **
      let mut bold_end = -1
      let mut j = bold_start
      while j + 1 < len {
        if chars[j] == '*' && chars[j + 1] == '*' {
          bold_end = j
          break
        }
        j = j + 1
      }
      if bold_end > 0 {
        buf.write_string("<strong>")
        buf.write_string(
          render_inline(
            safe_slice_range(text, bold_start, bold_end),
            source_line~,
          ),
        )
        buf.write_string("</strong>")
        i = bold_end + 2
        continue
      }
    }
    // Italic: *text*
    if chars[i] == '*' {
      let em_start = i + 1
      let mut em_end = -1
      let mut j = em_start
      while j < len {
        if chars[j] == '*' {
          em_end = j
          break
        }
        j = j + 1
      }
      if em_end > 0 {
        buf.write_string("<em>")
        buf.write_string(
          render_inline(safe_slice_range(text, em_start, em_end), source_line~),
        )
        buf.write_string("</em>")
        i = em_end + 1
        continue
      }
    }
    // Autolink: <https://example.com> or <mailto:user@example.com>
    if chars[i] == '<' {
      let mut auto_end = -1
      let mut j = i + 1
      while j < len {
        if chars[j] == '>' {
          auto_end = j
          break
        }
        j = j + 1
      }
      if auto_end > i + 1 {
        let url = safe_slice_range(text, i + 1, auto_end)
        let lower = url.to_lower()
        if lower.has_prefix("https://") ||
          lower.has_prefix("http://") ||
          lower.has_prefix("mailto:") {
          buf.write_string("<a href=\"")
          buf.write_string(escape_html(url))
          buf.write_string("\" target=\"_blank\" rel=\"noopener noreferrer\">")
          buf.write_string(escape_html(url))
          buf.write_string("</a>")
          i = auto_end + 1
          continue
        }
      }
    }
    // Regular character — escape HTML-significant chars to prevent XSS
    match chars[i] {
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      '&' => buf.write_string("&amp;")
      '"' => buf.write_string("&quot;")
      ch => buf.write_char(ch)
    }
    i = i + 1
  }
  buf.to_string()
}

///|
/// Add renderer-owned source metadata without discarding safe author
/// attributes such as `<details open>` or inline markup inside `<summary>`.
fn inject_attrs_into_open_tag(html : String, attrs : String) -> String {
  let chars = html.to_array()
  let buf = StringBuilder::new()
  let mut injected = false
  for ch in chars {
    if !injected && ch == '>' {
      buf.write_char(' ')
      buf.write_string(attrs)
      injected = true
    }
    buf.write_char(ch)
  }
  buf.to_string()
}

///|
/// Check if line starts an HTML block element
fn is_html_block_start(line : String) -> Bool {
  let t = trim(line)
  t.has_prefix("<details") ||
  t.has_prefix("<div") ||
  t.has_prefix("<section") ||
  t.has_prefix("<article") ||
  t.has_prefix("<aside") ||
  t.has_prefix("<nav") ||
  t.has_prefix("<header") ||
  t.has_prefix("<footer") ||
  t.has_prefix("<p") ||
  t.has_prefix("<table") ||
  t.has_prefix("<figure") ||
  t.has_prefix("<center") ||
  t.has_prefix("<blockquote") ||
  t.has_prefix("<img") ||
  t.has_prefix("<video") ||
  t.has_prefix("<h1") ||
  t.has_prefix("<h2") ||
  t.has_prefix("<h3") ||
  t.has_prefix("<h4") ||
  t.has_prefix("<h5") ||
  t.has_prefix("<h6") ||
  t.has_prefix("<hr") ||
  t.has_prefix("<ul") ||
  t.has_prefix("<ol") ||
  t.has_prefix("<dl") ||
  t.has_prefix("<span") ||
  t.has_prefix("<a ")
}

///| Void tags never get a closing tag, so an HTML block starting with one

///|
/// ends on the same line
fn is_void_tag(tag : String) -> Bool {
  match tag {
    "img" | "br" | "hr" | "source" => true
    _ => false
  }
}

///|
/// Extract tag name from HTML opening tag
fn extract_html_tag_name(line : String) -> String {
  let chars = line.to_array()
  let len = chars.length()
  let mut start = 0
  // Find '<'
  while start < len && chars[start] != '<' {
    start = start + 1
  }
  start = start + 1 // skip '<'
  let mut end = start
  while end < len && chars[end] != ' ' && chars[end] != '>' && chars[end] != '/' {
    end = end + 1
  }
  safe_slice_range(line, start, end)
}

///|
/// Check if a URL is safe (blocks javascript: and data:text/html)
pub fn is_safe_url(url : String) -> Bool {
  let lower = url.to_lower()
  let trimmed = trim(lower)
  if trimmed.has_prefix("javascript:") {
    return false
  }
  if trimmed.has_prefix("data:text/html") {
    return false
  }
  true
}

///|
/// Allowlisted HTML tags for sanitization
fn is_allowed_tag(tag : String) -> Bool {
  match tag {
    "b"
    | "i"
    | "em"
    | "strong"
    | "mark"
    | "code"
    | "br"
    | "a"
    | "img"
    | "span"
    | "div"
    | "p"
    | "ul"
    | "ol"
    | "li"
    | "table"
    | "tr"
    | "td"
    | "th"
    | "thead"
    | "tbody"
    | "del"
    | "sup"
    | "sub"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "blockquote"
    | "pre"
    | "hr"
    | "details"
    | "summary"
    | "section"
    | "article"
    | "aside"
    | "nav"
    | "header"
    | "footer"
    | "video"
    | "source"
    | "figure"
    | "figcaption"
    | "center"
    | "picture" => true
    _ => false
  }
}

///|
/// Dangerous tags that should be removed entirely
fn is_dangerous_tag(tag : String) -> Bool {
  match tag {
    "script" | "iframe" | "object" | "embed" | "form" | "input" => true
    _ => false
  }
}

///|
/// Allowed attributes for sanitization
fn is_allowed_attr(name : String) -> Bool {
  match name {
    "class"
    | "id"
    | "style"
    | "href"
    | "src"
    | "alt"
    | "title"
    | "width"
    | "height"
    | "colspan"
    | "rowspan"
    | "target"
    | "rel"
    | "controls"
    | "preload"
    | "open"
    | "align"
    | "valign"
    | "loading" => true
    _ => false
  }
}

///|
/// Check if CSS value contains dangerous expressions
fn is_dangerous_css(value : String) -> Bool {
  let lower = value.to_lower()
  lower.contains("expression(") ||
  lower.contains("url(") ||
  lower.contains("-moz-binding") ||
  lower.contains("behavior:") ||
  lower.contains("behaviour:") ||
  lower.contains("javascript:") ||
  lower.contains("vbscript:") ||
  lower.contains("@import")
}

///|
/// Check if attribute name is an event handler (on*)
fn is_event_handler_attr(name : String) -> Bool {
  name.has_prefix("on")
}

///|
/// Sanitize HTML string: remove dangerous tags, event handlers, dangerous URLs
pub fn sanitize_html(input : String) -> String {
  let chars = input.to_array()
  let len = chars.length()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    if chars[i] == '<' {
      // Parse tag
      let tag_start = i
      i = i + 1
      let is_closing = i < len && chars[i] == '/'
      if is_closing {
        i = i + 1
      }
      // Extract tag name
      let name_buf = StringBuilder::new()
      while i < len && chars[i] != ' ' && chars[i] != '>' && chars[i] != '/' {
        name_buf.write_char(chars[i])
        i = i + 1
      }
      let tag_name = name_buf.to_string().to_lower()
      // Find end of tag
      let mut tag_end = i
      while tag_end < len && chars[tag_end] != '>' {
        tag_end = tag_end + 1
      }
      if tag_end < len {
        tag_end = tag_end + 1
      }
      if is_dangerous_tag(tag_name) {
        // Skip dangerous tags entirely (including content for non-closing)
        if !is_closing {
          // Skip until closing tag
          let close_tag = "</" + tag_name + ">"
          let mut j = tag_end
          while j + close_tag.length() <= len {
            let close_chars = close_tag.to_array()
            let close_len = close_chars.length()
            let mut match_ = true
            for k = 0; k < close_len; k = k + 1 {
              if j + k >= len {
                match_ = false
                break
              }
              let ch_lower = if chars[j + k] >= 'A' && chars[j + k] <= 'Z' {
                (chars[j + k].to_int() + 32).unsafe_to_char()
              } else {
                chars[j + k]
              }
              if ch_lower != close_chars[k] {
                match_ = false
                break
              }
            }
            if match_ {
              i = j + close_len
              break
            }
            j = j + 1
          }
          if j + close_tag.length() > len {
            i = tag_end
          }
        } else {
          i = tag_end
        }
        continue
      }
      if !is_allowed_tag(tag_name) && tag_name.length() > 0 {
        // Unknown tag: pass through escaped
        buf.write_string("&lt;")
        let tag_content = safe_slice_range(input, tag_start + 1, tag_end)
        let trimmed_content = if tag_content.has_suffix(">") {
          safe_slice_range(tag_content, 0, tag_content.length() - 1)
        } else {
          tag_content
        }
        buf.write_string(escape_html(trimmed_content))
        buf.write_string("&gt;")
        i = tag_end
        continue
      }
      // Allowed tag: rebuild with filtered attributes
      buf.write_char('<')
      if is_closing {
        buf.write_char('/')
      }
      buf.write_string(tag_name)
      // Parse and filter attributes
      let attr_region = safe_slice_range(
        input,
        i,
        if tag_end > 0 {
          tag_end - 1
        } else {
          i
        },
      )
      let filtered = filter_attributes(attr_region, tag_name)
      if filtered.length() > 0 {
        buf.write_string(filtered)
      }
      if !is_closing && tag_name == "a" {
        buf.write_string(" target=\"_blank\" rel=\"noopener noreferrer\"")
      }
      // Self-closing check
      if tag_end > 1 && chars[tag_end - 2] == '/' {
        buf.write_string(" /")
      }
      buf.write_char('>')
      i = tag_end
    } else {
      buf.write_char(chars[i])
      i = i + 1
    }
  }
  buf.to_string()
}

///|
/// Filter HTML attributes, removing event handlers and dangerous URLs
fn filter_attributes(attr_str : String, tag_name : String) -> String {
  let chars = attr_str.to_array()
  let len = chars.length()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    // Skip whitespace
    while i < len && is_whitespace(chars[i]) {
      i = i + 1
    }
    if i >= len {
      break
    }
    // Parse attribute name
    let name_buf = StringBuilder::new()
    while i < len &&
          chars[i] != '=' &&
          chars[i] != ' ' &&
          chars[i] != '>' &&
          chars[i] != '/' {
      name_buf.write_char(chars[i])
      i = i + 1
    }
    let attr_name = name_buf.to_string().to_lower()
    if attr_name.length() == 0 {
      break
    }
    // Parse value if present
    let mut attr_value = ""
    if i < len && chars[i] == '=' {
      i = i + 1 // skip =
      if i < len && (chars[i] == '"' || chars[i] == '\'') {
        let quote = chars[i]
        i = i + 1
        let val_buf = StringBuilder::new()
        while i < len && chars[i] != quote {
          val_buf.write_char(chars[i])
          i = i + 1
        }
        if i < len {
          i = i + 1
        } // skip closing quote
        attr_value = val_buf.to_string()
      } else {
        // Unquoted value
        let val_buf = StringBuilder::new()
        while i < len && chars[i] != ' ' && chars[i] != '>' {
          val_buf.write_char(chars[i])
          i = i + 1
        }
        attr_value = val_buf.to_string()
      }
    }
    // Filter: skip event handlers
    if is_event_handler_attr(attr_name) {
      continue
    }
    // Filter: skip disallowed attributes
    if !is_allowed_attr(attr_name) {
      continue
    }
    // Link navigation is controlled by yunomi so reviewed documents cannot
    // replace the review tab or retain access to it through window.opener.
    if tag_name == "a" && (attr_name == "target" || attr_name == "rel") {
      continue
    }
    // Filter: check URLs in href/src
    if (attr_name == "href" || attr_name == "src") && !is_safe_url(attr_value) {
      continue
    }
    // Filter: sanitize dangerous CSS values in style attribute
    if attr_name == "style" && is_dangerous_css(attr_value) {
      continue
    }
    // Emit attribute
    buf.write_char(' ')
    buf.write_string(attr_name)
    buf.write_string("=\"")
    buf.write_string(escape_html(attr_value))
    buf.write_char('"')
  }
  buf.to_string()
}

///|
/// Check if code content looks like mermaid diagram
fn is_mermaid_content(text : String) -> Bool {
  let t = trim(text)
  t.has_prefix("graph ") ||
  t.has_prefix("flowchart ") ||
  t.has_prefix("sequenceDiagram") ||
  t.has_prefix("classDiagram") ||
  t.has_prefix("stateDiagram") ||
  t.has_prefix("erDiagram") ||
  t.has_prefix("journey") ||
  t.has_prefix("gantt") ||
  t.has_prefix("pie") ||
  t.has_prefix("gitGraph") ||
  t.has_prefix("mindmap") ||
  t.has_prefix("timeline")
}

///|
/// Is the image/link target empty or whitespace-only?
fn is_blank_url(url : String) -> Bool {
  trim(url) == ""
}

///|
/// Check if URL points to a video file
fn is_video_url(url : String) -> Bool {
  let lower = url.to_lower()
  lower.has_suffix(".mp4") ||
  lower.has_suffix(".webm") ||
  lower.has_suffix(".mov") ||
  lower.has_suffix(".avi") ||
  lower.has_suffix(".mkv") ||
  lower.has_suffix(".m4v") ||
  lower.has_suffix(".ogv")
}

///|
/// Parse yunomi questions from frontmatter lines
fn parse_yunomi_questions(
  lines : Array[String],
  start : Int,
  end : Int,
) -> Array[YunomiQuestion] {
  let questions : Array[YunomiQuestion] = []
  let mut i = start
  while i < end {
    let line = lines[i]
    if trim(line) == "yunomi:" {
      i = i + 1
      while i < end {
        let ql = lines[i]
        let tql = trim(ql)
        if tql == "questions:" || tql == "questions:" + " " {
          i = i + 1
          // Parse question items
          while i < end {
            let item_line = lines[i]
            let trimmed = trim(item_line)
            if trimmed.has_prefix("- ") {
              let q = parse_single_question(lines, i, end)
              questions.push(q.0)
              i = q.1
            } else if trimmed.length() == 0 || !item_line.has_prefix("  ") {
              break
            } else {
              i = i + 1
            }
          }
          break
        }
        i = i + 1
      }
      break
    }
    i = i + 1
  }
  questions
}

///|
/// Count leading space characters (used to find a YAML block scalar's own
/// indentation, which is not fixed — it's whatever the first content line
/// under `context: |` happens to use)
fn leading_spaces(s : String) -> Int {
  let chars = s.to_array()
  let mut n = 0
  while n < chars.length() && chars[n] == ' ' {
    n = n + 1
  }
  n
}

///|
/// Parse a single question item starting at line i, returns (question, next_line_idx)
fn parse_single_question(
  lines : Array[String],
  start : Int,
  end : Int,
) -> (YunomiQuestion, Int) {
  let mut id = ""
  let mut question = ""
  let mut context = ""
  let mut resolved = false
  let mut answer = ""
  let options : Array[String] = []
  // First line: "    - id: xxx" or "    - question: xxx"
  let first = trim(lines[start])
  // Remove "- " prefix
  let first_content = safe_slice(first, 2)
  let colon = index_of_char(first_content, ':')
  if colon >= 0 {
    let key = trim(safe_slice_range(first_content, 0, colon))
    let val = trim(safe_slice(first_content, colon + 1))
    if key == "id" {
      id = val
    }
    if key == "question" {
      question = val
    }
    if key == "resolved" {
      resolved = val == "true"
    }
    if key == "answer" {
      answer = val
    }
  }
  let mut i = start + 1
  while i < end {
    let line = lines[i]
    let trimmed = trim(line)
    // Next question item or end of block
    if trimmed.has_prefix("- ") && line.has_prefix("    -") {
      break
    }
    if trimmed.length() == 0 ||
      (!line.has_prefix("      ") && !line.has_prefix("    ")) {
      break
    }
    let content_colon = index_of_char(trimmed, ':')
    if content_colon >= 0 {
      let key = trim(safe_slice_range(trimmed, 0, content_colon))
      let val = trim(safe_slice(trimmed, content_colon + 1))
      if key == "id" {
        id = val
      }
      if key == "question" {
        question = val
      }
      if key == "resolved" {
        resolved = val == "true"
      }
      if key == "answer" {
        answer = val
      }
      if key == "context" {
        let is_block_scalar = val == "|" ||
          val == ">" ||
          val == "|-" ||
          val == ">-" ||
          val == "|+" ||
          val == ">+"
        if is_block_scalar {
          i = i + 1
          let block_lines : Array[String] = []
          let mut block_indent = -1
          while i < end {
            let bline = lines[i]
            if trim(bline).length() == 0 {
              block_lines.push("")
              i = i + 1
              continue
            }
            let indent = leading_spaces(bline)
            if block_indent < 0 {
              block_indent = indent
            }
            if indent < block_indent {
              break
            }
            block_lines.push(safe_slice(bline, block_indent))
            i = i + 1
          }
          let block_buf = StringBuilder::new()
          for bi, bl in block_lines {
            if bi > 0 {
              block_buf.write_char('\n')
            }
            block_buf.write_string(bl)
          }
          context = trim(block_buf.to_string())
          continue
        } else {
          context = val
        }
      }
      if key == "options" {
        i = i + 1
        while i < end {
          let opt_line = lines[i]
          let opt_trimmed = trim(opt_line)
          if opt_trimmed.has_prefix("- ") && opt_line.has_prefix("        ") {
            options.push(trim(safe_slice(opt_trimmed, 2)))
            i = i + 1
          } else {
            break
          }
        }
        continue
      }
    }
    i = i + 1
  }
  ({ id, question, context, resolved, answer, options }, i)
}

///|
fn build_mermaid_fullscreen(buf : StringBuilder) -> Unit {
  buf.write_string(
    "<div class=\"fullscreen-overlay\" id=\"mermaid-fullscreen\">",
  )
  buf.write_string("<div class=\"fullscreen-header\"><h3>Mermaid Diagram</h3>")
  buf.write_string("<div class=\"fullscreen-controls\">")
  buf.write_string("<button id=\"fs-zoom-out\">&minus;</button>")
  buf.write_string("<span class=\"zoom-info\" id=\"fs-zoom-info\">100%</span>")
  buf.write_string("<button id=\"fs-zoom-in\">+</button>")
  buf.write_string("<button id=\"fs-reset\">Reset</button>")
  buf.write_string("<button id=\"fs-close\">Close (ESC)</button>")
  buf.write_string("</div></div>")
  buf.write_string(
    "<div class=\"fullscreen-content\" id=\"fs-content\" style=\"overflow:hidden;position:relative;cursor:grab;flex:1;\">",
  )
  buf.write_string(
    "<div id=\"fs-wrapper\" style=\"position:absolute;left:0;top:0;transform-origin:0 0;\"></div>",
  )
  buf.write_string("</div>")
  buf.write_string("<div class=\"minimap\" id=\"fs-minimap\">")
  buf.write_string(
    "<div class=\"minimap-content\" id=\"fs-minimap-content\"></div>",
  )
  buf.write_string(
    "<div class=\"minimap-viewport\" id=\"fs-minimap-viewport\"></div>",
  )
  buf.write_string("</div>")
  buf.write_string("</div>")
}

///|
fn build_image_fullscreen(buf : StringBuilder) -> Unit {
  buf.write_string("<div class=\"fullscreen-overlay\" id=\"image-fullscreen\">")
  buf.write_string("<div class=\"fullscreen-header\"><h3>Image</h3>")
  buf.write_string("<div class=\"fullscreen-controls\">")
  buf.write_string("<button id=\"img-fs-zoom-out\">&minus;</button>")
  buf.write_string(
    "<span class=\"zoom-info\" id=\"img-fs-zoom-info\">100%</span>",
  )
  buf.write_string("<button id=\"img-fs-zoom-in\">+</button>")
  buf.write_string(
    "<span id=\"img-fs-counter\" style=\"margin:0 8px;font-size:12px;color:var(--muted);\"></span>",
  )
  buf.write_string(
    "<button id=\"img-fs-prev\" title=\"Previous\">&larr;</button>",
  )
  buf.write_string("<button id=\"img-fs-next\" title=\"Next\">&rarr;</button>")
  buf.write_string("<button id=\"img-fs-reset\">Reset</button>")
  buf.write_string("<button id=\"img-fs-close\">Close (ESC)</button>")
  buf.write_string("</div></div>")
  buf.write_string(
    "<div class=\"fullscreen-content\" id=\"image-fs-content\" style=\"overflow:hidden;position:relative;cursor:grab;flex:1;\">",
  )
  buf.write_string(
    "<div id=\"image-fs-wrapper\" style=\"position:absolute;left:0;top:0;transform-origin:0 0;\"></div>",
  )
  buf.write_string("</div>")
  buf.write_string("<div class=\"minimap\" id=\"image-fs-minimap\">")
  buf.write_string(
    "<div class=\"minimap-content\" id=\"image-fs-minimap-content\"></div>",
  )
  buf.write_string(
    "<div class=\"minimap-viewport\" id=\"image-fs-minimap-viewport\"></div>",
  )
  buf.write_string("</div>")
  buf.write_string("</div>")
}

///|
/// Build media sidebar HTML structure
fn build_media_sidebar(buf : StringBuilder) -> Unit {
  // Toggle button is in header .actions (html.mbt build_header), matching cli.cjs:4885
  // Sidebar container
  buf.write_string("<div class=\"media-sidebar hidden\" id=\"media-sidebar\">")
  buf.write_string(
    "<div class=\"media-sidebar-thumbs\" id=\"media-sidebar-thumbs\"></div>",
  )
  buf.write_string("</div>")
}

///|
/// Build video fullscreen overlay HTML
fn build_video_fullscreen(buf : StringBuilder) -> Unit {
  buf.write_string(
    "<div class=\"video-fullscreen-overlay\" id=\"video-fullscreen\">",
  )
  buf.write_string(
    "<button class=\"video-close-btn\" id=\"video-close\" aria-label=\"Close video\" title=\"Close (ESC)\">&#10005;</button>",
  )
  buf.write_string(
    "<button class=\"video-settings-btn\" id=\"video-settings-btn\" aria-label=\"Timeline settings\" title=\"Timeline settings\">&#9881;</button>",
  )
  buf.write_string(
    "<div class=\"video-settings-panel\" id=\"video-settings-panel\">",
  )
  buf.write_string("<h4>Timeline settings</h4>")
  buf.write_string(
    "<p class=\"video-settings-desc\">Scene sensitivity: visual change threshold</p>",
  )
  buf.write_string(
    "<div class=\"video-settings-buttons\" id=\"scene-buttons\">",
  )
  buf.write_string("<button data-scene=\"0.3\">Fewer</button>")
  buf.write_string("<button data-scene=\"0.1\">Slightly fewer</button>")
  buf.write_string(
    "<button data-scene=\"0.01\" class=\"selected\">Standard</button>",
  )
  buf.write_string("<button data-scene=\"0.003\">Slightly more</button>")
  buf.write_string("<button data-scene=\"0.001\">More</button>")
  buf.write_string("</div>")
  buf.write_string(
    "<p class=\"video-settings-desc\">Grouping: seconds used to merge consecutive changes</p>",
  )
  buf.write_string("<div class=\"video-settings-buttons\" id=\"stab-buttons\">")
  buf.write_string("<button data-stab=\"0.5\">0.5s</button>")
  buf.write_string("<button data-stab=\"0.3\">0.3s</button>")
  buf.write_string("<button data-stab=\"0.1\" class=\"selected\">0.1s</button>")
  buf.write_string("<button data-stab=\"0.05\">0.05s</button>")
  buf.write_string("<button data-stab=\"0.02\">0.02s</button>")
  buf.write_string("</div>")
  buf.write_string("</div>")
  buf.write_string("<div class=\"video-container\" id=\"video-container\">")
  buf.write_string(
    "<span id=\"vid-fs-counter\" style=\"position:absolute;bottom:100px;left:50%;transform:translateX(-50%);color:#fff;background:rgba(0,0,0,0.6);padding:8px 16px;border-radius:20px;font-size:14px;z-index:10;\"></span>",
  )
  buf.write_string("</div>")
  buf.write_string("</div>")
}

///|
/// Build HTML page for markdown viewer (cli.cjs-compatible structure)
pub fn build_markdown_html(
  md : MarkdownData,
  filename : String,
  port : Int,
  file_path? : String = "",
  tab_title? : String = "",
  server_instance_id? : String = "",
) -> String {
  let buf = StringBuilder::new()
  build_page_start(buf, filename, file_path~, tab_title~)
  // History panel (must be after header, before wrap)
  build_history_panel(buf)
  // Main content wrap
  buf.write_string("<div class=\"wrap\">")
  // Side-by-side layout: preview + source + review sidebar + media thumbs
  buf.write_string("<div class=\"md-layout\">")
  // Left panel: rendered markdown preview
  buf.write_string("<div class=\"md-left\">")
  buf.write_string("<div class=\"md-preview\" id=\"md-preview\">")
  // Document Metadata table (frontmatter)
  if md.frontmatter.length() > 0 {
    buf.write_string(
      "<div class=\"frontmatter-header\">Document Metadata</div>",
    )
    buf.write_string(
      "<table class=\"frontmatter-table\" data-source-line=\"1\"><tbody data-source-line=\"1\">",
    )
    md.frontmatter.each(fn(key, value) {
      // Skip yunomi: questions from metadata display
      if key == "yunomi" {
        return
      }
      buf.write_string("<tr data-source-line=\"1\"><th data-source-line=\"1\">")
      buf.write_string(escape_html(key))
      buf.write_string("</th><td data-source-line=\"1\">")
      buf.write_string(escape_html(value))
      buf.write_string("</td></tr>")
    })
    // Show questions preview in metadata if present
    if md.questions.length() > 0 {
      buf.write_string("<tr><th>yunomi questions</th><td>")
      buf.write_string(md.questions.length().to_string())
      buf.write_string(" question(s)</td></tr>")
    }
    buf.write_string("</tbody></table>")
  }
  buf.write_string(md.html)
  buf.write_string("</div></div>")
  // Right panel: source as table (mirrors #csv-table structure for click events)
  buf.write_string("<div class=\"md-right\"><div class=\"table-box\">")
  buf.write_string(
    "<table id=\"csv-table\"><colgroup id=\"colgroup\"></colgroup>",
  )
  buf.write_string("<thead><tr><th aria-label=\"row/col corner\"></th>")
  buf.write_string(
    "<th data-col=\"1\"><div class=\"th-inner\">Text<span class=\"resizer\" data-col=\"1\"></span></div></th>",
  )
  buf.write_string("</tr></thead>")
  buf.write_string("<tbody id=\"tbody\">")
  let source_lines = split_to_lines(md.source)
  for i, line in source_lines {
    buf.write_string("<tr data-row=\"")
    buf.write_string(i.to_string())
    buf.write_string("\"><th>")
    buf.write_string((i + 1).to_string())
    buf.write_string("</th><td data-row=\"")
    buf.write_string(i.to_string())
    buf.write_string("\" data-col=\"1\">")
    buf.write_string(escape_html(line))
    buf.write_string("</td></tr>")
  }
  buf.write_string("</tbody></table>")
  buf.write_string("</div></div>")
  build_review_loop_mount(buf)
  build_media_sidebar(buf)
  buf.write_string("</div>")
  // Close .wrap
  buf.write_string("</div>")
  build_comment_list_aside(buf)
  build_submit_modal(buf)
  build_recovery_modal(buf)
  build_mermaid_fullscreen(buf)
  build_image_fullscreen(buf)
  build_video_fullscreen(buf)
  build_questions_modal(buf, md.questions)
  build_questions_notice(buf, md.questions)
  // Inject DATA variable (source lines array for preview-to-source mapping)
  buf.write_string("<script>window.__DATA__=")
  buf.write_string(serialize_source_lines_json(source_lines))
  buf.write_string(";</script>")
  // Inject questions data
  if md.questions.length() > 0 {
    buf.write_string("<script>window.__YUNOMI_QUESTIONS__=")
    buf.write_string(serialize_questions_json(md.questions))
    buf.write_string(";</script>")
  }
  build_script_footer(buf, port, "markdown", filename, server_instance_id~)
  buf.to_string()
}
