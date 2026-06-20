///| Parse unified diff format

///|
/// Supports both `diff --git` format and legacy `---/+++` format
pub fn parse_diff(input : String) -> DiffData {
  let files : Array[DiffFile] = []
  let lines = split_to_lines(input)
  let len = lines.length()
  let mut i = 0
  while i < len {
    let line = lines[i]
    if line.has_prefix("diff --git ") {
      let paths = extract_git_paths(line)
      let mut is_new = false
      let mut is_deleted = false
      let mut is_binary = false
      i = i + 1
      // Process metadata lines: skip ---, +++, index, detect new/deleted/binary
      while i < len {
        let l = lines[i]
        if l.has_prefix("new file mode") {
          is_new = true
          i = i + 1
        } else if l.has_prefix("deleted file mode") {
          is_deleted = true
          i = i + 1
        } else if l.has_prefix("Binary files") {
          is_binary = true
          i = i + 1
        } else if l.has_prefix("index ") ||
          l.has_prefix("--- ") ||
          l.has_prefix("+++ ") {
          i = i + 1
        } else {
          break
        }
      }
      let result = collect_hunks(lines, i, len)
      i = result.1
      files.push({
        old_path: paths.0,
        new_path: paths.1,
        is_new,
        is_deleted,
        is_binary,
        hunks: result.0,
      })
    } else if line.has_prefix("--- ") {
      // Legacy format (no diff --git prefix)
      let old_path = strip_diff_prefix(safe_slice(line, 4))
      let mut new_path = ""
      i = i + 1
      if i < len && lines[i].has_prefix("+++ ") {
        new_path = strip_diff_prefix(safe_slice(lines[i], 4))
        i = i + 1
      }
      let result = collect_hunks(lines, i, len)
      i = result.1
      files.push({
        old_path,
        new_path,
        is_new: false,
        is_deleted: false,
        is_binary: false,
        hunks: result.0,
      })
    } else {
      i = i + 1
    }
  }
  DiffData::{ files, }
}

///| Extract old_path and new_path from "diff --git a/X b/Y"

///|
/// Non-greedy: finds first " b/" as separator
fn extract_git_paths(line : String) -> (String, String) {
  // "diff --git a/" = 13 characters
  let rest = safe_slice(line, 13)
  let chars = rest.to_array()
  let len = chars.length()
  let mut sep_pos = -1
  // Find first occurrence of " b/"
  let mut idx = 0
  while idx + 2 < len {
    if chars[idx] == ' ' && chars[idx + 1] == 'b' && chars[idx + 2] == '/' {
      sep_pos = idx
      break
    }
    idx = idx + 1
  }
  if sep_pos < 0 {
    (rest, rest)
  } else {
    let old_path = safe_slice_range(rest, 0, sep_pos)
    let new_path = safe_slice(rest, sep_pos + 3)
    (old_path, new_path)
  }
}

///|
/// Collect hunks starting from position i
fn collect_hunks(
  lines : Array[String],
  start : Int,
  len : Int,
) -> (Array[DiffHunk], Int) {
  let hunks : Array[DiffHunk] = []
  let mut i = start
  while i < len {
    let line = lines[i]
    if line.has_prefix("@@ ") {
      let header = parse_hunk_header(line)
      let hunk_lines : Array[DiffLine] = []
      i = i + 1
      while i < len {
        let l = lines[i]
        if l.has_prefix("@@ ") || l.has_prefix("diff ") || l.has_prefix("--- ") {
          break
        }
        if l.has_prefix("+") {
          hunk_lines.push({ kind: Addition, content: safe_slice(l, 1) })
        } else if l.has_prefix("-") {
          hunk_lines.push({ kind: Deletion, content: safe_slice(l, 1) })
        } else if l.has_prefix(" ") {
          hunk_lines.push({ kind: Context, content: safe_slice(l, 1) })
        } else {
          hunk_lines.push({ kind: Context, content: l })
        }
        i = i + 1
      }
      hunks.push({
        old_start: header.0,
        old_count: header.1,
        new_start: header.2,
        new_count: header.3,
        context: header.4,
        lines: hunk_lines,
      })
    } else if line.has_prefix("diff ") || line.has_prefix("--- ") {
      break
    } else {
      i = i + 1
    }
  }
  (hunks, i)
}

///|
/// Strip a/ or b/ prefix from diff paths
fn strip_diff_prefix(path : String) -> String {
  if path.has_prefix("a/") || path.has_prefix("b/") {
    safe_slice(path, 2)
  } else {
    path
  }
}

///|
/// Parse hunk header: @@ -old_start,old_count +new_start,new_count @@ context
fn parse_hunk_header(line : String) -> (Int, Int, Int, Int, String) {
  let mut old_start = 0
  let mut old_count = 0
  let mut new_start = 0
  let mut new_count = 0
  let chars = line.to_array()
  let len = chars.length()
  let mut i = 3 // skip "@@ "
  // Parse -old_start[,old_count]
  if i < len && chars[i] == '-' {
    i = i + 1
    let result = parse_int_from(chars, i, len)
    old_start = result.0
    i = result.1
    if i < len && chars[i] == ',' {
      i = i + 1
      let result2 = parse_int_from(chars, i, len)
      old_count = result2.0
      i = result2.1
    } else {
      old_count = 1
    }
  }
  if i < len && chars[i] == ' ' {
    i = i + 1
  }
  // Parse +new_start[,new_count]
  if i < len && chars[i] == '+' {
    i = i + 1
    let result = parse_int_from(chars, i, len)
    new_start = result.0
    i = result.1
    if i < len && chars[i] == ',' {
      i = i + 1
      let result2 = parse_int_from(chars, i, len)
      new_count = result2.0
      ignore(result2.1)
    } else {
      new_count = 1
    }
  }
  // Extract context: everything after closing "@@"
  let mut context = ""
  let mut close_pos = -1
  let mut j = 3
  while j + 1 < len {
    if chars[j] == '@' && chars[j + 1] == '@' {
      close_pos = j
      break
    }
    j = j + 1
  }
  if close_pos >= 0 {
    context = safe_slice(line, close_pos + 2)
  }
  (old_start, old_count, new_start, new_count, context)
}

///|
/// Parse integer from char array starting at position
fn parse_int_from(chars : Array[Char], start : Int, len : Int) -> (Int, Int) {
  let mut n = 0
  let mut i = start
  while i < len && chars[i] >= '0' && chars[i] <= '9' {
    n = n * 10 + (chars[i].to_int() - '0'.to_int())
    i = i + 1
  }
  (n, i)
}
