///|
test "safe_slice normal" {
  debug_inspect(
    safe_slice("hello", 2),
    content=(
      #|"llo"

    ),
  )
}

///|
test "safe_slice from start" {
  debug_inspect(
    safe_slice("hello", 0),
    content=(
      #|"hello"

    ),
  )
}

///|
test "safe_slice out of range" {
  debug_inspect(safe_slice("hi", 10), content=(
    #|""
  ))
}

///|
test "safe_slice negative" {
  debug_inspect(safe_slice("hi", -1), content=(
    #|""
  ))
}

///|
test "safe_slice_range" {
  debug_inspect(
    safe_slice_range("hello world", 6, 11),
    content=(
      #|"world"

    ),
  )
}

///|
test "parse_int_safe normal" {
  debug_inspect(
    parse_int_safe("42"),
    content=(
      #|42
    ),
  )
}

///|
test "parse_int_safe empty" {
  debug_inspect(
    parse_int_safe(""),
    content=(
      #|0
    ),
  )
}

///|
test "parse_int_safe non-numeric" {
  debug_inspect(
    parse_int_safe("abc"),
    content=(
      #|0
    ),
  )
}

///|
test "split_to_lines" {
  let lines = split_to_lines("a\nb\nc")
  debug_inspect(
    lines.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    lines[0],
    content=(
      #|"a"

    ),
  )
  debug_inspect(
    lines[2],
    content=(
      #|"c"

    ),
  )
}

///|
test "quote_source_line basic" {
  let lines = ["# Title", "", "  Hello world  ", "last"]
  debug_inspect(
    quote_source_line(lines, 0),
    content=(
      #|"# Title"

    ),
  )
  debug_inspect(
    quote_source_line(lines, 2),
    content=(
      #|"Hello world"

    ),
  )
}

///|
test "quote_source_line empty line yields empty" {
  let lines = ["a", "", "\t \r"]
  debug_inspect(
    quote_source_line(lines, 1),
    content=(
      #|""

    ),
  )
  debug_inspect(
    quote_source_line(lines, 2),
    content=(
      #|""

    ),
  )
}

///|
test "quote_source_line out of range" {
  let lines = ["only"]
  debug_inspect(
    quote_source_line(lines, -1),
    content=(
      #|""

    ),
  )
  debug_inspect(
    quote_source_line(lines, 1),
    content=(
      #|""

    ),
  )
}

///|
test "quote_source_line truncates at 300 chars" {
  let buf = StringBuilder::new()
  for i = 0; i < 350; i = i + 1 {
    buf.write_char('x')
  }
  let lines = [buf.to_string()]
  let quoted = quote_source_line(lines, 0)
  debug_inspect(
    quoted.length(),
    content=(
      #|303
    ),
  )
  debug_inspect(
    quoted.has_suffix("..."),
    content=(
      #|true
    ),
  )
}
