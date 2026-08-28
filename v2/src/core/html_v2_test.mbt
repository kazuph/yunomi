///| Tests for cli.cjs-compatible HTML output

///| Verifies that HTML templates use selectors expected by E2E tests

///| Plan G3: HTML selector incompatibilities that must be resolved

///| These tests call existing functions but check for NEW selector patterns

///|
/// They will FAIL at runtime until html.mbt is updated (TDD red phase)
test "html compat: csv uses header tag not div toolbar" {
  // csv.test.js expects `header h1` selector
  let data : CsvData = { headers: ["a", "b"], rows: [["1", "2"]] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("<header"),
    content=(
      #|true
    ),
  )
}

///|
test "html compat: csv table has id csv-table" {
  // csv.test.js:58 expects `#csv-table`
  let data : CsvData = { headers: ["name", "age"], rows: [["Alice", "30"]] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("id=\"csv-table\""),
    content=(
      #|true
    ),
  )
}

///|
test "html compat: csv tbody has id tbody" {
  // csv.test.js expects `#tbody`
  let data : CsvData = { headers: ["a"], rows: [["1"]] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("id=\"tbody\""),
    content=(
      #|true
    ),
  )
}

///|
test "html compat: inline editor is not a floating static element" {
  let data : CsvData = { headers: ["a"], rows: [] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("id=\"comment-input\""),
    content=(
      #|false
    ),
  )
}

///|
test "html compat: floating comment card is absent" {
  let data : CsvData = { headers: ["a"], rows: [] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("comment-card"),
    content=(
      #|false
    ),
  )
}

///|
test "html compat: submit button has id send-and-exit" {
  // csv.test.js expects `#send-and-exit` (not #submit-btn)
  let data : CsvData = { headers: ["a"], rows: [] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("id=\"send-and-exit\""),
    content=(
      #|true
    ),
  )
}

///|
test "html compat: submit modal has id submit-modal" {
  // submit-exit.test.js expects `#submit-modal`
  let data : CsvData = { headers: ["a"], rows: [] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("id=\"submit-modal\""),
    content=(
      #|true
    ),
  )
}

///|
test "html compat: modal summary has id modal-summary" {
  // submit-exit.test.js expects `#modal-summary` (not #comment-list)
  let data : CsvData = { headers: ["a"], rows: [] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("id=\"modal-summary\""),
    content=(
      #|true
    ),
  )
}

///|
test "html compat: global comment has id global-comment" {
  // submit-exit.test.js expects `#global-comment` (not #summary-text)
  let data : CsvData = { headers: ["a"], rows: [] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("id=\"global-comment\""),
    content=(
      #|true
    ),
  )
}

///|
test "html compat: filter menu exists" {
  // csv.test.js:84-97 expects `#filter-menu`
  let data : CsvData = { headers: ["a", "b"], rows: [] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("id=\"filter-menu\""),
    content=(
      #|true
    ),
  )
}

///|
test "html compat: th has data-col and th-inner" {
  // csv.test.js expects `th[data-col] .th-inner`
  let data : CsvData = { headers: ["name", "age"], rows: [] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("data-col="),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("th-inner"),
    content=(
      #|true
    ),
  )
}

///|
test "html compat: has-comment class for commented cells" {
  // csv.test.js expects `.has-comment` (not `.commented`)
  let data : CsvData = { headers: ["a"], rows: [] }
  let html = build_csv_html(data, "test.csv", 4989)
  // CSS should define .has-comment, not .commented
  debug_inspect(
    html.contains("has-comment"),
    content=(
      #|true
    ),
  )
}

///|
test "html compat: no recovery modal (drafts restore silently)" {
  let data : CsvData = { headers: ["a"], rows: [] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("id=\"recovery-modal\""),
    content=(
      #|false
    ),
  )
  debug_inspect(
    html.contains("id=\"recovery-restore\""),
    content=(
      #|false
    ),
  )
}

///|
test "html compat: data injection via script variable" {
  // Plan G4: empty tbody + DATA variable injection
  let data : CsvData = { headers: ["a", "b"], rows: [["1", "2"]] }
  let html = build_csv_html(data, "test.csv", 4989)
  debug_inspect(
    html.contains("const DATA"),
    content=(
      #|true
    ),
  )
}
