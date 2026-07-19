///| Tests for cli.cjs-compatible diff parser behavior

///| Mirrors parsers.test.js test cases at the MoonBit level

///|
/// New fields referenced: DiffFile.{is_new, is_deleted, is_binary}, DiffHunk.context
test "diff compat: simple unified diff with all metadata" {
  let input =
    #|diff --git a/file.txt b/file.txt
    #|index 1234567..abcdefg 100644
    #|--- a/file.txt
    #|+++ b/file.txt
    #|@@ -1,3 +1,4 @@
    #| line1
    #|-old line
    #|+new line
    #|+added line
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
      #|"file.txt"
    ),
  )
  debug_inspect(
    data.files[0].new_path,
    content=(
      #|"file.txt"
    ),
  )
  debug_inspect(
    data.files[0].is_new,
    content=(
      #|false
    ),
  )
  debug_inspect(
    data.files[0].is_deleted,
    content=(
      #|false
    ),
  )
  debug_inspect(
    data.files[0].is_binary,
    content=(
      #|false
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
    data.files[0].hunks[0].new_start,
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].lines.length(),
    content=(
      #|5
    ),
  )
}

///|
test "diff compat: new file detection" {
  let input =
    #|diff --git a/newfile.txt b/newfile.txt
    #|new file mode 100644
    #|index 0000000..abcdefg
    #|--- /dev/null
    #|+++ b/newfile.txt
    #|@@ -0,0 +1,3 @@
    #|+line1
    #|+line2
    #|+line3
  let data = parse_diff(input)
  debug_inspect(
    data.files.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[0].new_path,
    content=(
      #|"newfile.txt"
    ),
  )
  debug_inspect(
    data.files[0].is_new,
    content=(
      #|true
    ),
  )
  debug_inspect(
    data.files[0].is_deleted,
    content=(
      #|false
    ),
  )
  debug_inspect(
    data.files[0].hunks.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].lines.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].lines[0].kind,
    content=(
      #|Addition
    ),
  )
}

///|
test "diff compat: deleted file detection" {
  let input =
    #|diff --git a/deleted.txt b/deleted.txt
    #|deleted file mode 100644
    #|index abcdefg..0000000
    #|--- a/deleted.txt
    #|+++ /dev/null
    #|@@ -1,2 +0,0 @@
    #|-line1
    #|-line2
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
      #|"deleted.txt"
    ),
  )
  debug_inspect(
    data.files[0].is_new,
    content=(
      #|false
    ),
  )
  debug_inspect(
    data.files[0].is_deleted,
    content=(
      #|true
    ),
  )
  debug_inspect(
    data.files[0].hunks.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].lines.length(),
    content=(
      #|2
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].lines[0].kind,
    content=(
      #|Deletion
    ),
  )
}

///|
test "diff compat: hunk context extraction" {
  let input =
    #|diff --git a/file.js b/file.js
    #|index 1234567..abcdefg 100644
    #|--- a/file.js
    #|+++ b/file.js
    #|@@ -10,5 +10,6 @@ function example() {
    #| context line
    #|-removed
    #|+added
    #| context
  let data = parse_diff(input)
  debug_inspect(
    data.files[0].hunks[0].old_start,
    content=(
      #|10
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].new_start,
    content=(
      #|10
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].context,
    content=(
      #|" function example() {"
    ),
  )
}

///|
test "diff compat: binary file detection" {
  let input =
    #|diff --git a/image.png b/image.png
    #|new file mode 100644
    #|index 0000000..abcdefg
    #|Binary files /dev/null and b/image.png differ
  let data = parse_diff(input)
  debug_inspect(
    data.files.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[0].new_path,
    content=(
      #|"image.png"
    ),
  )
  debug_inspect(
    data.files[0].is_binary,
    content=(
      #|true
    ),
  )
  debug_inspect(
    data.files[0].hunks.length(),
    content=(
      #|0
    ),
  )
}

///|
test "diff compat: multiple files with git prefix" {
  let input =
    #|diff --git a/file1.txt b/file1.txt
    #|index 1234567..abcdefg 100644
    #|--- a/file1.txt
    #|+++ b/file1.txt
    #|@@ -1,2 +1,2 @@
    #| line1
    #|-old
    #|+new
    #|diff --git a/file2.txt b/file2.txt
    #|index 2345678..bcdefgh 100644
    #|--- a/file2.txt
    #|+++ b/file2.txt
    #|@@ -1,1 +1,2 @@
    #| content
    #|+added
  let data = parse_diff(input)
  debug_inspect(
    data.files.length(),
    content=(
      #|2
    ),
  )
  debug_inspect(
    data.files[0].new_path,
    content=(
      #|"file1.txt"
    ),
  )
  debug_inspect(
    data.files[1].new_path,
    content=(
      #|"file2.txt"
    ),
  )
  debug_inspect(
    data.files[0].hunks.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[1].hunks.length(),
    content=(
      #|1
    ),
  )
}

///|
test "diff compat: japanese characters" {
  let input =
    #|diff --git a/japanese.txt b/japanese.txt
    #|index 1234567..abcdefg 100644
    #|--- a/japanese.txt
    #|+++ b/japanese.txt
    #|@@ -1,2 +1,2 @@
    #| こんにちは
    #|-古いテキスト
    #|+新しいテキスト
  let data = parse_diff(input)
  debug_inspect(
    data.files.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].lines.length(),
    content=(
      #|3
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].lines[1].content,
    content=(
      #|"古いテキスト"
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].lines[2].content,
    content=(
      #|"新しいテキスト"
    ),
  )
}

///|
test "diff compat: empty diff" {
  let data = parse_diff("")
  debug_inspect(
    data.files.length(),
    content=(
      #|0
    ),
  )
}

///|
test "diff compat: multiple hunks in single file" {
  let input =
    #|diff --git a/file.txt b/file.txt
    #|index 1234567..abcdefg 100644
    #|--- a/file.txt
    #|+++ b/file.txt
    #|@@ -1,3 +1,3 @@
    #| line1
    #|-old1
    #|+new1
    #| line3
    #|@@ -10,3 +10,3 @@
    #| line10
    #|-old2
    #|+new2
    #| line12
  let data = parse_diff(input)
  debug_inspect(
    data.files.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[0].hunks.length(),
    content=(
      #|2
    ),
  )
  debug_inspect(
    data.files[0].hunks[0].old_start,
    content=(
      #|1
    ),
  )
  debug_inspect(
    data.files[0].hunks[1].old_start,
    content=(
      #|10
    ),
  )
}

///|
test "diff compat: line type identification" {
  let input =
    #|diff --git a/file.txt b/file.txt
    #|index 1234567..abcdefg 100644
    #|--- a/file.txt
    #|+++ b/file.txt
    #|@@ -1,4 +1,4 @@
    #| context line
    #|-deleted line
    #|+added line
    #| another context
  let data = parse_diff(input)
  let lines = data.files[0].hunks[0].lines
  debug_inspect(
    lines[0].kind,
    content=(
      #|Context
    ),
  )
  debug_inspect(
    lines[1].kind,
    content=(
      #|Deletion
    ),
  )
  debug_inspect(
    lines[2].kind,
    content=(
      #|Addition
    ),
  )
  debug_inspect(
    lines[3].kind,
    content=(
      #|Context
    ),
  )
}

///|
test "diff compat: file paths with spaces" {
  let input =
    #|diff --git a/path with spaces/file.txt b/path with spaces/file.txt
    #|index 1234567..abcdefg 100644
    #|--- a/path with spaces/file.txt
    #|+++ b/path with spaces/file.txt
    #|@@ -1,1 +1,1 @@
    #|-old
    #|+new
  let data = parse_diff(input)
  debug_inspect(
    data.files[0].old_path,
    content=(
      #|"path with spaces/file.txt"
    ),
  )
  debug_inspect(
    data.files[0].new_path,
    content=(
      #|"path with spaces/file.txt"
    ),
  )
}
