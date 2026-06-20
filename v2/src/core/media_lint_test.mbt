///|
/// Tests for media embed discipline lint
test "plain media link is a violation" {
  let v = find_media_link_violations("see [demo](videos/demo.webm)")
  debug_inspect(v.length(), content="1")
  debug_inspect(v[0].line_no, content="1")
  debug_inspect(
    v[0].snippet,
    content=(
      #|"[demo](videos/demo.webm)"

    ),
  )
  debug_inspect(
    v[0].fixed,
    content=(
      #|"![demo](videos/demo.webm)"

    ),
  )
}

///|
test "image embed syntax is fine" {
  let v = find_media_link_violations("![demo](videos/demo.webm)\n![s](a/b.png)")
  debug_inspect(v.length(), content="0")
}

///|
test "image link is a violation" {
  let v = find_media_link_violations("[before](images/before.PNG)")
  debug_inspect(v.length(), content="1")
}

///|
test "non-media link is fine" {
  let v = find_media_link_violations(
    "[docs](https://example.com/page) and [md](README.md)",
  )
  debug_inspect(v.length(), content="0")
}

///|
test "link with query and fragment still detected" {
  let v = find_media_link_violations("[v](movie.mp4?t=10#frag)")
  debug_inspect(v.length(), content="1")
  debug_inspect(
    v[0].fixed,
    content=(
      #|"![v](movie.mp4?t=10#frag)"

    ),
  )
}

///|
test "link with title detected" {
  let v = find_media_link_violations("[v](shots/a.png \"title here\")")
  debug_inspect(v.length(), content="1")
}

///|
test "angle bracket target detected" {
  let v = find_media_link_violations("[v](<my shots/a 1.png>)")
  debug_inspect(v.length(), content="1")
}

///|
test "fenced code block is skipped" {
  let md = "```\n[v](demo.mp4)\n```\n[w](real.mp4)"
  let v = find_media_link_violations(md)
  debug_inspect(v.length(), content="1")
  debug_inspect(v[0].line_no, content="4")
}

///|
test "tilde fence is skipped" {
  let md = "~~~markdown\n[v](demo.mp4)\n~~~"
  let v = find_media_link_violations(md)
  debug_inspect(v.length(), content="0")
}

///|
test "inline code span is skipped" {
  let v = find_media_link_violations("use `[v](demo.mp4)` syntax")
  debug_inspect(v.length(), content="0")
}

///|
test "multiple violations on one line" {
  let v = find_media_link_violations("[a](x.png) and [b](y.mp4)")
  debug_inspect(v.length(), content="2")
}

///|
test "violations across lines report correct line numbers" {
  let md = "# title\n\n[a](x.png)\n\ntext\n[b](y.webm)"
  let v = find_media_link_violations(md)
  debug_inspect(v.length(), content="2")
  debug_inspect(v[0].line_no, content="3")
  debug_inspect(v[1].line_no, content="6")
}

///|
test "nested brackets in label" {
  let v = find_media_link_violations("[see [note]](shot.png)")
  debug_inspect(v.length(), content="1")
}

///|
test "remote media url link is a violation" {
  let v = find_media_link_violations("[cdn](https://cdn.example.com/clip.mov)")
  debug_inspect(v.length(), content="1")
}

///|
test "empty content" {
  let v = find_media_link_violations("")
  debug_inspect(v.length(), content="0")
}

///|
test "reference style link is ignored" {
  let v = find_media_link_violations("[demo][ref]\n\n[ref]: videos/demo.webm")
  debug_inspect(v.length(), content="0")
}
