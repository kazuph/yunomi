///|
test "parse simple unified diff" {
  let input =
    #|--- a/hello.txt
    #|+++ b/hello.txt
    #|@@ -1,3 +1,3 @@
    #| line1
    #|-old line
    #|+new line
    #| line3
  let data = parse_diff(input)
  debug_inspect(
    data.files.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[0].old_path,
    content=(
      #|"hello.txt"
    ),
  )
  debug_inspect(
    data.files[0].new_path,
    content=(
      #|"hello.txt"
    ),
  )
  debug_inspect(
    data.files[0].hunks.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].old_start,
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].lines.length(),
    content=(
      #|4
    ),
  )
}

///|
test "diff line kinds" {
  let input =
    #|--- a/f.txt
    #|+++ b/f.txt
    #|@@ -1,2 +1,2 @@
    #|-removed
    #|+added
  let data = parse_diff(input)
  let lines = data.files[0].hunks[0].lines
  debug_inspect(
    lines[0].kind,
    content=(
      #|Deletion
    ),
  )
  debug_inspect(
    lines[0].content,
    content=(
      #|"removed"
    ),
  )
  debug_inspect(
    lines[1].kind,
    content=(
      #|Addition
    ),
  )
  debug_inspect(
    lines[1].content,
    content=(
      #|"added"
    ),
  )
}

///|
test "parse diff with git prefix" {
  let input =
    #|diff --git a/src/main.rs b/src/main.rs
    #|--- a/src/main.rs
    #|+++ b/src/main.rs
    #|@@ -10,3 +10,4 @@
    #| context
    #|+added
    #| context2
  let data = parse_diff(input)
  debug_inspect(
    data.files[0].new_path,
    content=(
      #|"src/main.rs"
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].new_start,
    content=(
      #|10
    ),
  )
}

///|
test "parse diff multiple files" {
  let input =
    #|--- a/a.txt
    #|+++ b/a.txt
    #|@@ -1 +1 @@
    #|-old
    #|+new
    #|--- a/b.txt
    #|+++ b/b.txt
    #|@@ -1 +1 @@
    #|-foo
    #|+bar
  let data = parse_diff(input)
  debug_inspect(
    data.files.length(),
    content=(
      #|2
    ),
  )
}

///|
test "hunk header single line" {
  let input =
    #|--- a/f.txt
    #|+++ b/f.txt
    #|@@ -5 +5 @@
    #|-old
    #|+new
  let data = parse_diff(input)
  let hunk = data.files[0].hunks[0]
  debug_inspect(
    hunk.old_start,
    content=(
      #|5
    ),
  )
  debug_inspect(
    hunk.old_count,
    content=(
      #|1
    ),
  )
  debug_inspect(
    hunk.new_count,
    content=(
      #|1
    ),
  )
}
