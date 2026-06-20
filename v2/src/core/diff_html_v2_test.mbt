///| Tests for build_diff_html new behavior

///| AIRV-008: is_new/is_deleted/is_binary labels + binary hunk skip

///|
/// AIRV-009: hunk header @@ -old,count +new,count @@ context
test "diff html: new file shows new file label" {
  // AIRV-008: is_new=true → diff-label "new file" in file header
  let data : DiffData = {
    files: [
      {
        old_path: "",
        new_path: "newfile.txt",
        is_new: true,
        is_deleted: false,
        is_binary: false,
        hunks: [],
      },
    ],
  }
  let html = build_diff_html(data, "test.diff", 4989)
  debug_inspect(
    html.contains("new file"),
    content=(
      #|true
    ),
  )
}

///|
test "diff html: deleted file shows deleted label" {
  // AIRV-008: is_deleted=true → diff-label "deleted" in file header
  let data : DiffData = {
    files: [
      {
        old_path: "deleted.txt",
        new_path: "",
        is_new: false,
        is_deleted: true,
        is_binary: false,
        hunks: [],
      },
    ],
  }
  let html = build_diff_html(data, "test.diff", 4989)
  debug_inspect(
    html.contains("deleted"),
    content=(
      #|true
    ),
  )
}

///|
test "diff html: binary file shows binary label" {
  // AIRV-008: is_binary=true → diff-label "binary" in file header
  let data : DiffData = {
    files: [
      {
        old_path: "image.png",
        new_path: "image.png",
        is_new: false,
        is_deleted: false,
        is_binary: true,
        hunks: [],
      },
    ],
  }
  let html = build_diff_html(data, "test.diff", 4989)
  debug_inspect(
    html.contains("binary"),
    content=(
      #|true
    ),
  )
}

///|
test "diff html: binary file skips hunk rendering" {
  // AIRV-008: is_binary=true → hunks not rendered even when present
  let data : DiffData = {
    files: [
      {
        old_path: "image.png",
        new_path: "image.png",
        is_new: false,
        is_deleted: false,
        is_binary: true,
        hunks: [
          {
            old_start: 1,
            old_count: 1,
            new_start: 1,
            new_count: 1,
            context: "",
            lines: [{ kind: Addition, content: "binary content" }],
          },
        ],
      },
    ],
  }
  let html = build_diff_html(data, "test.diff", 4989)
  // No hunk header div when binary (check for opening tag, not CSS selector)
  debug_inspect(
    html.contains("<div class=\"diff-hunk-header\">"),
    content=(
      #|false
    ),
  )
  // No line content when binary
  debug_inspect(
    html.contains("binary content"),
    content=(
      #|false
    ),
  )
}

///|
test "diff html: normal file has no label span" {
  // AIRV-008: is_new=false, is_deleted=false, is_binary=false → no diff-label span
  let data : DiffData = {
    files: [
      {
        old_path: "file.txt",
        new_path: "file.txt",
        is_new: false,
        is_deleted: false,
        is_binary: false,
        hunks: [],
      },
    ],
  }
  let html = build_diff_html(data, "test.diff", 4989)
  // No label span in DOM (check for opening tag, not CSS selector)
  debug_inspect(
    html.contains("<span class=\"diff-label"),
    content=(
      #|false
    ),
  )
}

///|
test "diff html: hunk header format @@ -old,count +new,count @@" {
  // AIRV-009: hunk header with standard @@ format matches cli.cjs:789
  let data : DiffData = {
    files: [
      {
        old_path: "file.txt",
        new_path: "file.txt",
        is_new: false,
        is_deleted: false,
        is_binary: false,
        hunks: [
          {
            old_start: 1,
            old_count: 3,
            new_start: 1,
            new_count: 4,
            context: "",
            lines: [{ kind: Context, content: "line" }],
          },
        ],
      },
    ],
  }
  let html = build_diff_html(data, "test.diff", 4989)
  debug_inspect(
    html.contains("@@ -1,3 +1,4 @@"),
    content=(
      #|true
    ),
  )
}

///|
test "diff html: hunk header includes context after @@" {
  // AIRV-009: context string appended after @@ separator
  let data : DiffData = {
    files: [
      {
        old_path: "file.js",
        new_path: "file.js",
        is_new: false,
        is_deleted: false,
        is_binary: false,
        hunks: [
          {
            old_start: 10,
            old_count: 5,
            new_start: 10,
            new_count: 6,
            context: " function example() {",
            lines: [{ kind: Context, content: "body" }],
          },
        ],
      },
    ],
  }
  let html = build_diff_html(data, "test.diff", 4989)
  debug_inspect(
    html.contains("@@ -10,5 +10,6 @@"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("function example()"),
    content=(
      #|true
    ),
  )
}

///|
test "diff html: hunk header element has diff-hunk-header class" {
  // AIRV-009: hunk header div uses class diff-hunk-header
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
            lines: [{ kind: Context, content: "x" }],
          },
        ],
      },
    ],
  }
  let html = build_diff_html(data, "test.diff", 4989)
  debug_inspect(
    html.contains("diff-hunk-header"),
    content=(
      #|true
    ),
  )
}

///|
test "diff html: multiple hunks each have headers" {
  // AIRV-009: every hunk gets its own header
  let data : DiffData = {
    files: [
      {
        old_path: "file.txt",
        new_path: "file.txt",
        is_new: false,
        is_deleted: false,
        is_binary: false,
        hunks: [
          {
            old_start: 1,
            old_count: 2,
            new_start: 1,
            new_count: 2,
            context: "",
            lines: [{ kind: Context, content: "top" }],
          },
          {
            old_start: 20,
            old_count: 3,
            new_start: 20,
            new_count: 3,
            context: "",
            lines: [{ kind: Context, content: "bottom" }],
          },
        ],
      },
    ],
  }
  let html = build_diff_html(data, "test.diff", 4989)
  debug_inspect(
    html.contains("@@ -1,2 +1,2 @@"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("@@ -20,3 +20,3 @@"),
    content=(
      #|true
    ),
  )
}
