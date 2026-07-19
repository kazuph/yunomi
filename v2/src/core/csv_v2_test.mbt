///| Tests for cli.cjs-compatible CSV parser behavior

///| Mirrors parsers.test.js test cases at the MoonBit level

///|
/// parse_csv returns Array[Array[String]] (flat 2D array)
test "csv compat: simple csv returns flat 2d array" {
  // parsers.test.js: result has length 3, result[0] = ['a','b','c']
  let result = parse_csv("a,b,c\n1,2,3\n4,5,6", ',')
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[0],
    content=(
      #|["a", "b", "c"]
    ),
  )
  debug_inspect(
    result[1],
    content=(
      #|["1", "2", "3"]
    ),
  )
  debug_inspect(
    result[2],
    content=(
      #|["4", "5", "6"]
    ),
  )
}

///|
test "csv compat: quoted fields" {
  let result = parse_csv(
    "name,description\n\"John Doe\",\"A simple description\"\n\"Jane\",\"Another one\"",
    ',',
  )
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[1][0],
    content=(
      #|"John Doe"
    ),
  )
  debug_inspect(
    result[1][1],
    content=(
      #|"A simple description"
    ),
  )
}

///|
test "csv compat: escaped quotes rfc4180" {
  let result = parse_csv(
    "text\n\"He said \"\"Hello\"\"\"\n\"Normal text\"", ',',
  )
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[1][0],
    content=(
      #|"He said \"Hello\""
    ),
  )
  debug_inspect(
    result[2][0],
    content=(
      #|"Normal text"
    ),
  )
}

///|
test "csv compat: tsv format" {
  let result = parse_csv("a\tb\tc\n1\t2\t3\n4\t5\t6", '\t')
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[0],
    content=(
      #|["a", "b", "c"]
    ),
  )
  debug_inspect(
    result[1],
    content=(
      #|["1", "2", "3"]
    ),
  )
}

///|
test "csv compat: empty fields" {
  let result = parse_csv("a,,c\n,b,\n1,2,3", ',')
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[0],
    content=(
      #|["a", "", "c"]
    ),
  )
  debug_inspect(
    result[1],
    content=(
      #|["", "b", ""]
    ),
  )
}

///|
test "csv compat: newlines in quoted fields" {
  let result = parse_csv(
    "name,address\n\"John\",\"123 Main St\nApt 4\"\n\"Jane\",\"456 Oak Ave\"", ',',
  )
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[1][1],
    content=(
      #|"123 Main St\nApt 4"
    ),
  )
  debug_inspect(
    result[2][1],
    content=(
      #|"456 Oak Ave"
    ),
  )
}

///|
test "csv compat: crlf line endings" {
  let result = parse_csv("a,b,c\r\n1,2,3\r\n4,5,6", ',')
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[0],
    content=(
      #|["a", "b", "c"]
    ),
  )
  debug_inspect(
    result[1],
    content=(
      #|["1", "2", "3"]
    ),
  )
  debug_inspect(
    result[2],
    content=(
      #|["4", "5", "6"]
    ),
  )
}

///|
test "csv compat: empty input returns empty array" {
  // parsers.test.js: parseCsv('') → length 0
  let result = parse_csv("", ',')
  debug_inspect(
    result.length(),
    content=(
      #|0
    ),
  )
}

///|
test "csv compat: single field" {
  let result = parse_csv("single", ',')
  debug_inspect(
    result.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    result[0],
    content=(
      #|["single"]
    ),
  )
}

///|
test "csv compat: single row multiple fields" {
  let result = parse_csv("a,b,c,d", ',')
  debug_inspect(
    result.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    result[0],
    content=(
      #|["a", "b", "c", "d"]
    ),
  )
}

///|
test "csv compat: comma in quoted field" {
  let result = parse_csv(
    "name,value\n\"Smith, John\",100\n\"Doe, Jane\",200", ',',
  )
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[1][0],
    content=(
      #|"Smith, John"
    ),
  )
  debug_inspect(
    result[2][0],
    content=(
      #|"Doe, Jane"
    ),
  )
}

///|
test "csv compat: mixed quoted and unquoted" {
  let result = parse_csv("a,\"b\",c\n\"1\",2,\"3\"\n4,\"5\",6", ',')
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[0],
    content=(
      #|["a", "b", "c"]
    ),
  )
  debug_inspect(
    result[1],
    content=(
      #|["1", "2", "3"]
    ),
  )
  debug_inspect(
    result[2],
    content=(
      #|["4", "5", "6"]
    ),
  )
}

///|
test "csv compat: japanese characters" {
  let result = parse_csv("名前,価格\nりんご,100\nみかん,150", ',')
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[0],
    content=(
      #|["名前", "価格"]
    ),
  )
  debug_inspect(
    result[1],
    content=(
      #|["りんご", "100"]
    ),
  )
  debug_inspect(
    result[2],
    content=(
      #|["みかん", "150"]
    ),
  )
}

///|
test "csv compat: trailing newline no empty row" {
  let result = parse_csv("a,b,c\n1,2,3\n", ',')
  debug_inspect(
    result.length(),
    content=(
      #|2
    ),
  )
  debug_inspect(
    result[0],
    content=(
      #|["a", "b", "c"]
    ),
  )
  debug_inspect(
    result[1],
    content=(
      #|["1", "2", "3"]
    ),
  )
}

///|
test "csv compat: complex escaped quotes" {
  let result = parse_csv(
    "text\n\"He said \"\"Hello\"\" and then \"\"Goodbye\"\"\"", ',',
  )
  debug_inspect(
    result.length(),
    content=(
      #|2
    ),
  )
  debug_inspect(
    result[1][0],
    content=(
      #|"He said \"Hello\" and then \"Goodbye\""
    ),
  )
}

///|
test "csv compat: tab separator with quoted fields" {
  let result = parse_csv(
    "name\tdescription\n\"John Doe\"\t\"A\ttab\tin\ttext\"\nSimple\tValue", '\t',
  )
  debug_inspect(
    result.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    result[1][0],
    content=(
      #|"John Doe"
    ),
  )
  debug_inspect(
    result[1][1],
    content=(
      #|"A\ttab\tin\ttext"
    ),
  )
  debug_inspect(
    result[2],
    content=(
      #|["Simple", "Value"]
    ),
  )
}
