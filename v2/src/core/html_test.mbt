///|
test "escape html special chars" {
  debug_inspect(
    escape_html("<script>alert('xss')</script>"),
    content=(
      #|"&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
    ),
  )
}

///|
test "escape html ampersand" {
  debug_inspect(
    escape_html("a & b"),
    content=(
      #|"a &amp; b"
    ),
  )
}

///|
test "escape html quotes" {
  debug_inspect(
    escape_html("say \"hello\""),
    content=(
      #|"say &quot;hello&quot;"
    ),
  )
}

///|
test "build csv html contains table" {
  let data : CsvData = { headers: ["name", "age"], rows: [["Alice", "30"]] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("<table"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("Alice"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("test.csv | yunomi"),
    content=(
      #|true
    ),
  )
}

///|
test "build csv html escapes cell content" {
  let data : CsvData = { headers: ["val"], rows: [["<b>bold</b>"]] }
  let html = build_csv_html(data, "t.csv", 4989)
  debug_inspect(
    html.contains("&lt;b&gt;bold&lt;/b&gt;"),
    content=(
      #|true
    ),
  )
}

///|
test "build text html line numbers" {
  let lines = ["hello", "world"]
  let html = build_text_html(lines, "test.txt", 4989)
  debug_inspect(
    html.contains("line-num"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("hello"),
    content=(
      #|true
    ),
  )
}

///|
test "build page includes highlight.js CDN" {
  let data : CsvData = { headers: ["a"], rows: [["1"]] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("id=\"hljs-theme-dark\""),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("id=\"hljs-theme-light\""),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("highlight.min.js"),
    content=(
      #|true
    ),
  )
}

///|
test "build diff html shows additions and deletions" {
  let data : DiffData = {
    files: [
      {
        old_path: "a.txt",
        new_path: "a.txt",
        is_new: false,
        is_deleted: false,
        is_binary: false,
        hunks: [
          {
            old_start: 1,
            old_count: 1,
            new_start: 1,
            new_count: 1,
            context: "",
            lines: [
              { kind: Deletion, content: "old" },
              { kind: Addition, content: "new" },
            ],
          },
        ],
      },
    ],
  }
  let html = build_diff_html(data, "test.diff", 4989)
  debug_inspect(
    html.contains("addition"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("deletion"),
    content=(
      #|true
    ),
  )
}
