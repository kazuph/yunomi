///|
test "parse simple csv" {
  let result = parse_csv("name,age,city\nAlice,30,Tokyo\nBob,25,Osaka", ',')
  debug_inspect(
    result[0],
    content=(
      #|["name", "age", "city"]
    ),
  )
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[1],
    content=(
      #|["Alice", "30", "Tokyo"]
    ),
  )
}

///|
test "parse csv with quoted fields" {
  let result = parse_csv("name,desc\n\"Alice\",\"hello, world\"", ',')
  debug_inspect(
    result[0],
    content=(
      #|["name", "desc"]
    ),
  )
  debug_inspect(
    result[1],
    content=(
      #|["Alice", "hello, world"]
    ),
  )
}

///|
test "parse csv with escaped quotes" {
  let result = parse_csv("val\n\"she said \"\"hi\"\"\"", ',')
  debug_inspect(
    result[1][0],
    content=(
      #|"she said \"hi\""
    ),
  )
}

///|
test "parse csv with newline in quoted field" {
  let result = parse_csv("val\n\"line1\nline2\"", ',')
  debug_inspect(
    result[1][0],
    content=(
      #|"line1\nline2"
    ),
  )
}

///|
test "parse tsv" {
  let result = parse_csv("a\tb\n1\t2", '\t')
  debug_inspect(
    result[0],
    content=(
      #|["a", "b"]
    ),
  )
  debug_inspect(
    result[1],
    content=(
      #|["1", "2"]
    ),
  )
}

///|
test "parse csv with crlf" {
  let result = parse_csv("a,b\r\n1,2\r\n3,4", ',')
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[1],
    content=(
      #|["1", "2"]
    ),
  )
}

///|
test "parse csv empty input returns empty" {
  let result = parse_csv("", ',')
  debug_inspect(
    result.length(),
    content=(
      #|0
    ),
  )
}
