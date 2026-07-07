///|
test "parse markdown headings" {
  let md = parse_markdown("# Hello\n\nSome text\n\n## World")
  debug_inspect(
    md.source.length() > 0,
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("<h1 "),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("<h2 "),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown paragraphs" {
  let md = parse_markdown("Hello world\n\nSecond paragraph")
  debug_inspect(
    md.html.contains(
      "<p data-source-start-line=\"1\" data-source-end-line=\"1\">Hello world</p>",
    ),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains(
      "<p data-source-start-line=\"3\" data-source-end-line=\"3\">Second paragraph</p>",
    ),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown bold and italic" {
  let md = parse_markdown("**bold** and *italic*")
  debug_inspect(
    md.html.contains("<strong>bold</strong>"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("<em>italic</em>"),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown code block" {
  let md = parse_markdown("```js\nconst x = 1;\n```")
  debug_inspect(
    md.html.contains(
      "<pre data-source-start-line=\"1\" data-source-end-line=\"3\"><code class=\"language-js\">",
    ),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("const x = 1;"),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown inline code" {
  let md = parse_markdown("use `hello()` function")
  debug_inspect(
    md.html.contains("<code>hello()</code>"),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown unordered list" {
  let md = parse_markdown("- item 1\n- item 2\n- item 3")
  debug_inspect(
    md.html.contains("<ul>"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("<li data-source-line=\"1\">item 1</li>"),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown ordered list" {
  let md = parse_markdown("1. first\n2. second")
  debug_inspect(
    md.html.contains("<ol>"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("<li data-source-line=\"1\">first</li>"),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown links" {
  let md = parse_markdown("[click here](https://example.com)")
  debug_inspect(
    md.html.contains("<a href=\"https://example.com\">click here</a>"),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown images" {
  let md = parse_markdown("![alt text](image.png)")
  debug_inspect(
    md.html.contains("<img"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("src=\"image.png\""),
    content=(
      #|true
    ),
  )
}

///|
test "empty image target stays literal text (no ghost img)" {
  // Quoting the ![]() syntax itself must not produce <img src="">
  let md = parse_markdown("use ![]() syntax for media")
  debug_inspect(
    md.html.contains("<img"),
    content=(
      #|false
    ),
  )
  debug_inspect(
    md.html.contains("![]()"),
    content=(
      #|true
    ),
  )
}

///|
test "whitespace-only image target stays literal text" {
  let md = parse_markdown("broken ![alt](  ) embed")
  debug_inspect(
    md.html.contains("<img"),
    content=(
      #|false
    ),
  )
}

///|
test "parse markdown blockquote" {
  let md = parse_markdown("> quoted text")
  debug_inspect(
    md.html.contains(
      "<blockquote data-source-start-line=\"1\" data-source-end-line=\"1\">",
    ),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown horizontal rule" {
  let md = parse_markdown("above\n\n---\n\nbelow")
  debug_inspect(
    md.html.contains("<hr"),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown table" {
  let md = parse_markdown("| a | b |\n|---|---|\n| 1 | 2 |")
  debug_inspect(
    md.html.contains("<table>"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains(
      "<th data-source-line=\"1\" data-row=\"0\" data-col=\"1\">",
    ),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains(
      "<th data-source-line=\"1\" data-row=\"0\" data-col=\"2\">",
    ),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains(
      "<td data-source-line=\"3\" data-row=\"2\" data-col=\"1\">",
    ),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains(
      "<td data-source-line=\"3\" data-row=\"2\" data-col=\"2\">",
    ),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown frontmatter" {
  let md = parse_markdown("---\ntitle: Hello\nauthor: Alice\n---\n\n# Content")
  debug_inspect(
    md.frontmatter.get("title"),
    content=(
      #|Some("Hello")
    ),
  )
  debug_inspect(
    md.frontmatter.get("author"),
    content=(
      #|Some("Alice")
    ),
  )
  debug_inspect(
    md.html.contains("<h1 "),
    content=(
      #|true
    ),
  )
  // frontmatter should not appear in html body (only in rendered md)
  debug_inspect(
    md.html.contains("title:"),
    content=(
      #|false
    ),
  )
}

///|
test "parse markdown empty" {
  let md = parse_markdown("")
  debug_inspect(
    md.html,
    content=(
      #|""
    ),
  )
  debug_inspect(
    md.source,
    content=(
      #|""
    ),
  )
  debug_inspect(md.questions.length(), content="0")
}

///|
test "parse markdown with yunomi questions" {
  let input = "---\ntitle: Test\nyunomi:\n  questions:\n    - id: q1\n      question: What do you think?\n      resolved: false\n    - id: q2\n      question: Is this OK?\n      resolved: true\n      answer: Yes\n---\n\n# Content"
  let md = parse_markdown(input)
  debug_inspect(md.questions.length(), content="2")
  debug_inspect(
    md.questions[0].id,
    content=(
      #|"q1"
    ),
  )
  debug_inspect(
    md.questions[0].question,
    content=(
      #|"What do you think?"
    ),
  )
  debug_inspect(md.questions[0].resolved, content="false")
  debug_inspect(
    md.questions[1].id,
    content=(
      #|"q2"
    ),
  )
  debug_inspect(md.questions[1].resolved, content="true")
  debug_inspect(
    md.questions[1].answer,
    content=(
      #|"Yes"
    ),
  )
}

///|
test "parse markdown questions with options" {
  let input = "---\nyunomi:\n  questions:\n    - id: rating\n      question: How would you rate?\n      options:\n        - Good\n        - Bad\n        - Neutral\n---\n\nText"
  let md = parse_markdown(input)
  debug_inspect(md.questions.length(), content="1")
  debug_inspect(md.questions[0].options.length(), content="3")
  debug_inspect(
    md.questions[0].options[0],
    content=(
      #|"Good"
    ),
  )
  debug_inspect(
    md.questions[0].options[1],
    content=(
      #|"Bad"
    ),
  )
  debug_inspect(
    md.questions[0].options[2],
    content=(
      #|"Neutral"
    ),
  )
}

///|
test "parse markdown no questions" {
  let md = parse_markdown("---\ntitle: Hello\n---\n\n# Content")
  debug_inspect(md.questions.length(), content="0")
}

///|
test "parse markdown questions with single-line context" {
  let input = "---\nyunomi:\n  questions:\n    - id: q1\n      question: Ship it?\n      context: Fail-open was chosen over fail-closed for latency.\n---\n\nText"
  let md = parse_markdown(input)
  debug_inspect(md.questions.length(), content="1")
  debug_inspect(
    md.questions[0].context,
    content=(
      #|"Fail-open was chosen over fail-closed for latency."
    ),
  )
}

///|
test "parse markdown questions with block-scalar context" {
  let input = "---\nyunomi:\n  questions:\n    - id: q1\n      question: Ship it?\n      context: |\n        Line one of the judgment material.\n        Line two, still part of context.\n      options:\n        - Yes\n        - No\n---\n\nText"
  let md = parse_markdown(input)
  debug_inspect(md.questions.length(), content="1")
  debug_inspect(
    md.questions[0].context,
    content=(
      #|"Line one of the judgment material.\nLine two, still part of context."
    ),
  )
  // The block scalar must not swallow the following `options:` key.
  debug_inspect(md.questions[0].options.length(), content="2")
  debug_inspect(
    md.questions[0].options[0],
    content=(
      #|"Yes"
    ),
  )
}

///|
test "parse markdown questions without context stay backward compatible" {
  let input = "---\nyunomi:\n  questions:\n    - id: q1\n      question: Ship it?\n      resolved: false\n---\n\nText"
  let md = parse_markdown(input)
  debug_inspect(md.questions.length(), content="1")
  debug_inspect(
    md.questions[0].context,
    content=(
      #|""
    ),
  )
  debug_inspect(
    md.questions[0].id,
    content=(
      #|"q1"
    ),
  )
}

///|
/// task #17: the Document Metadata table's generic frontmatter scanner has
/// no YAML nesting/indentation awareness — it used to read "id:",
/// "question:", "context:", "resolved:" etc. straight out of the nested
/// `yunomi: questions:` block as if they were flat top-level keys, and
/// since the SAME nested key repeats once per question, the LAST
/// question's value silently overwrote every earlier one in the map. A
/// real REPORT.md with 3 questions showed only the 3rd question's
/// id/context in Document Metadata, duplicating (and mangling) content the
/// questions modal already owns. Fix: skip every line inside the `yunomi:`
/// block by indentation, while still parsing real sibling top-level keys
/// normally.
test "parse markdown frontmatter excludes nested yunomi keys" {
  let input =
    #|---
    #|title: Wave 0 Report
    #|author: Alice
    #|yunomi:
    #|  questions:
    #|    - id: q-first
    #|      question: First question?
    #|      context: |
    #|        Some judgment material.
    #|      resolved: false
    #|    - id: q-second
    #|      question: Second question?
    #|      resolved: true
    #|      answer: Yes
    #|---
    #|
    #|# Content
  let md = parse_markdown(input)
  // Real top-level sibling keys are unaffected.
  debug_inspect(
    md.frontmatter.get("title"),
    content=(
      #|Some("Wave 0 Report")
    ),
  )
  debug_inspect(
    md.frontmatter.get("author"),
    content=(
      #|Some("Alice")
    ),
  )
  // The yunomi key itself, and every nested key under it, must not leak
  // into the generic frontmatter map at all (not even the LAST question's
  // value) — the questions modal is the sole owner of this data.
  debug_inspect(
    md.frontmatter.get("yunomi"),
    content=(
      #|None
    ),
  )
  debug_inspect(
    md.frontmatter.get("questions"),
    content=(
      #|None
    ),
  )
  debug_inspect(
    md.frontmatter.get("id"),
    content=(
      #|None
    ),
  )
  debug_inspect(
    md.frontmatter.get("question"),
    content=(
      #|None
    ),
  )
  debug_inspect(
    md.frontmatter.get("context"),
    content=(
      #|None
    ),
  )
  debug_inspect(
    md.frontmatter.get("resolved"),
    content=(
      #|None
    ),
  )
  debug_inspect(
    md.frontmatter.get("answer"),
    content=(
      #|None
    ),
  )
  // parse_yunomi_questions() (a separate, indentation-aware parser) still
  // correctly sees both questions — only the generic flat scanner changed.
  debug_inspect(md.questions.length(), content="2")
  debug_inspect(
    md.questions[0].id,
    content=(
      #|"q-first"
    ),
  )
  debug_inspect(
    md.questions[1].id,
    content=(
      #|"q-second"
    ),
  )
}

///|
test "parse markdown link url escaped" {
  let md = parse_markdown("[click](http://example.com/a\"b)")
  debug_inspect(
    md.html.contains("href=\"http://example.com/a&quot;b\""),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown blocks javascript links" {
  let md = parse_markdown("[evil](javascript:alert(1))")
  debug_inspect(
    md.html.contains("href"),
    content=(
      #|false
    ),
  )
  debug_inspect(
    md.html.contains("evil"),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown image src escaped" {
  let md = parse_markdown("![alt](img\"bad.png)")
  debug_inspect(
    md.html.contains("src=\"img&quot;bad.png\""),
    content=(
      #|true
    ),
  )
}

///|
test "parse markdown table wrapped in table-container" {
  let md = parse_markdown("| a | b |\n|---|---|\n| 1 | 2 |")
  debug_inspect(
    md.html.contains("<div class=\"table-container\">"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("</table>\n</div>"),
    content=(
      #|true
    ),
  )
}

///|
test "html block: p with align renders as html" {
  let md = parse_markdown(
    "<p align=\"center\">\n  <img src=\"hero.png\" alt=\"hero\" width=\"720\">\n</p>\n\nAfter text",
  )
  debug_inspect(
    md.html.contains("<p align=\"center\">"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("<img src=\"hero.png\""),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("&lt;p"),
    content=(
      #|false
    ),
  )
  debug_inspect(
    md.html.contains("After text"),
    content=(
      #|true
    ),
  )
}

///|
test "html block: single-line p does not swallow following markdown" {
  let md = parse_markdown("<p align=\"center\">hello</p>\n\n# Heading After")
  debug_inspect(
    md.html.contains("hello"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("Heading After"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("<h1"),
    content=(
      #|true
    ),
  )
}

///|
test "html block: script inside is stripped" {
  let md = parse_markdown(
    "<p align=\"center\"><script>alert(1)</script>safe</p>",
  )
  debug_inspect(
    md.html.contains("<script"),
    content=(
      #|false
    ),
  )
  debug_inspect(
    md.html.contains("safe"),
    content=(
      #|true
    ),
  )
}

///|
test "html block: anchor with badge img keeps href and src" {
  let md = parse_markdown(
    "<p align=\"center\">\n  <a href=\"https://www.npmjs.com/package/yunomi\"><img src=\"https://img.shields.io/npm/v/yunomi.svg\" alt=\"npm version\"></a>\n</p>",
  )
  debug_inspect(
    md.html.contains("<a href=\"https://www.npmjs.com/package/yunomi\""),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("img.shields.io"),
    content=(
      #|true
    ),
  )
}

///|
test "html block: h1 align center (actual README header) renders as html" {
  let md = parse_markdown(
    "<h1 align=\"center\">どうぞ 🍵</h1>\n\n<p align=\"center\">\n  <img src=\"hero.png\" alt=\"hero\" width=\"720\">\n</p>\n\nBody text",
  )
  debug_inspect(
    md.html.contains("<h1 align=\"center\">どうぞ 🍵</h1>"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    md.html.contains("&lt;h1"),
    content=(
      #|false
    ),
  )
  debug_inspect(
    md.html.contains("Body text"),
    content=(
      #|true
    ),
  )
}
