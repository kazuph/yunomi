///|
/// Safe substring from start index to end (returns empty if out of range)
///  Uses chars array length (code points) not String.length() (UTF-16 units)
///  to avoid index-out-of-bounds with emoji/surrogate pairs.
pub fn safe_slice(s : String, start : Int) -> String {
  let chars = s.to_array()
  let len = chars.length()
  if start >= len || start < 0 {
    ""
  } else {
    let buf = StringBuilder::new()
    for i in start..<len {
      buf.write_char(chars[i])
    }
    buf.to_string()
  }
}

///|
/// Safe substring from start to end index
///  Uses chars array length (code points) not String.length() (UTF-16 units).
pub fn safe_slice_range(s : String, start : Int, end : Int) -> String {
  let chars = s.to_array()
  let len = chars.length()
  let actual_start = if start < 0 { 0 } else { start }
  let actual_end = if end > len { len } else { end }
  if actual_start >= actual_end {
    ""
  } else {
    let buf = StringBuilder::new()
    for i in actual_start..<actual_end {
      buf.write_char(chars[i])
    }
    buf.to_string()
  }
}

///|
/// Parse integer from string (returns 0 for invalid input)
pub fn parse_int_safe(s : String) -> Int {
  let mut n = 0
  let chars = s.to_array()
  for ch in chars {
    if ch >= '0' && ch <= '9' {
      n = n * 10 + (ch.to_int() - '0'.to_int())
    }
  }
  n
}

///|
/// Split string into lines as String array
pub fn split_to_lines(input : String) -> Array[String] {
  let result : Array[String] = []
  for sv in input.split("\n") {
    result.push(sv.to_owned())
  }
  result
}

///|
/// Quote the source line a review comment refers to (0-based row).
///  Trims surrounding whitespace/CR and caps at 300 chars so the verdict
///  YAML stays readable. Out-of-range rows yield "" (line gets omitted).
pub fn quote_source_line(lines : Array[String], row : Int) -> String {
  if row < 0 || row >= lines.length() {
    return ""
  }
  let chars = lines[row].to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end &&
        (chars[start] == ' ' || chars[start] == '\t' || chars[start] == '\r') {
    start = start + 1
  }
  while end > start &&
        (
          chars[end - 1] == ' ' ||
          chars[end - 1] == '\t' ||
          chars[end - 1] == '\r'
        ) {
    end = end - 1
  }
  let truncated = end - start > 300
  let limit = if truncated { start + 300 } else { end }
  let buf = StringBuilder::new()
  for i = start; i < limit; i = i + 1 {
    buf.write_char(chars[i])
  }
  if truncated {
    buf.write_string("...")
  }
  buf.to_string()
}

///|
/// Safe path containment check that avoids prefix bypass.
///  Ensures `child` is either exactly `base` or lives strictly under `base`
///  by comparing with a trailing path separator — so `/a/b` does NOT match `/a/bad`.
///  Both arguments are expected to be already normalized via `path.resolve`.
///  Supports both Unix (`/`) and Windows (`\`) separators for cross-platform safety.
pub fn is_path_under(base : String, child : String) -> Bool {
  if child == base {
    return true
  }
  child.has_prefix(base + "/") || child.has_prefix(base + "\\")
}
