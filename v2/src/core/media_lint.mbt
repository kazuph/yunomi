///| Media embed discipline lint
///  yunomi renders media only when written with ![alt](path) image syntax.
///  A [text](path/to.png) link shows up as a plain link, so the reviewer
///  never sees the evidence. find_media_link_violations detects such links
///  so the CLI can refuse to start and ask the caller (usually an AI agent)
///  to fix the markdown before requesting a review.

///|
/// A [text](media) link that should have been an ![alt](media) embed
pub struct MediaLinkViolation {
  line_no : Int // 1-based line number
  snippet : String // the offending [text](url) as written
  fixed : String // suggested replacement: ![text](url)
} derive(Debug, Eq)

///|
/// Extensions yunomi can render inline (images + videos)
let media_link_exts : Array[String] = [
  ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp", ".avif", ".mp4", ".mov",
  ".webm", ".avi", ".mkv", ".m4v", ".ogv",
]

///|
/// Scan markdown content for [text](media-file) links written without `!`.
///  Skips fenced code blocks and inline code spans.
pub fn find_media_link_violations(
  content : String,
) -> Array[MediaLinkViolation] {
  let out : Array[MediaLinkViolation] = []
  let lines = split_to_lines(content)
  let mut in_fence = false
  for li, raw_line in lines {
    if line_is_fence_marker(raw_line) {
      in_fence = !in_fence
      continue
    }
    if in_fence {
      continue
    }
    let line = blank_inline_code(raw_line)
    let chars = line.to_array()
    let n = chars.length()
    let mut i = 0
    while i < n {
      if chars[i] == '[' && (i == 0 || chars[i - 1] != '!') {
        // Find the matching ']' (links may nest brackets in the label)
        let mut depth = 1
        let mut j = i + 1
        while j < n && depth > 0 {
          if chars[j] == '[' {
            depth = depth + 1
          } else if chars[j] == ']' {
            depth = depth - 1
          }
          j = j + 1
        }
        // j now points just past the closing ']'
        if depth == 0 && j < n && chars[j] == '(' {
          let mut k = j + 1
          while k < n && chars[k] != ')' {
            k = k + 1
          }
          if k < n {
            let url_raw = safe_slice_range(line, j + 1, k)
            if is_media_link_target(url_raw) {
              let snippet = safe_slice_range(line, i, k + 1)
              out.push(MediaLinkViolation::{
                line_no: li + 1,
                snippet,
                fixed: "!" + snippet,
              })
            }
            i = k + 1
            continue
          }
        }
      }
      i = i + 1
    }
  }
  out
}

///|
/// Does the link target point at a renderable media file?
fn is_media_link_target(raw : String) -> Bool {
  let cleaned = normalize_link_target(raw)
  if cleaned == "" {
    return false
  }
  for ext in media_link_exts {
    if cleaned.has_suffix(ext) {
      return true
    }
  }
  false
}

///|
/// Extract the bare path from a link target:
///  trims spaces, unwraps <...>, drops the "title" part, query and fragment.
fn normalize_link_target(raw : String) -> String {
  let chars = raw.to_array()
  let mut s = 0
  let mut e = chars.length()
  while s < e && (chars[s] == ' ' || chars[s] == '\t') {
    s = s + 1
  }
  while e > s && (chars[e - 1] == ' ' || chars[e - 1] == '\t') {
    e = e - 1
  }
  let angle_wrapped = s < e && chars[s] == '<'
  let mut i = if angle_wrapped { s + 1 } else { s }
  let buf = StringBuilder::new()
  while i < e {
    let ch = chars[i]
    if ch == '?' || ch == '#' {
      break
    }
    if angle_wrapped {
      if ch == '>' {
        break
      }
    } else if ch == ' ' || ch == '\t' {
      break
    }
    buf.write_char(ch)
    i = i + 1
  }
  buf.to_string().to_lower()
}

///|
/// Fence markers (``` or ~~~) toggle code-block state
fn line_is_fence_marker(line : String) -> Bool {
  let chars = line.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n && (chars[i] == ' ' || chars[i] == '\t') {
    i = i + 1
  }
  if i + 3 > n {
    return false
  }
  (chars[i] == '`' && chars[i + 1] == '`' && chars[i + 2] == '`') ||
  (chars[i] == '~' && chars[i + 1] == '~' && chars[i + 2] == '~')
}

///|
/// Replace inline code spans with spaces so links inside `...` are ignored
fn blank_inline_code(line : String) -> String {
  let chars = line.to_array()
  let buf = StringBuilder::new()
  let mut in_code = false
  for ch in chars {
    if ch == '`' {
      in_code = !in_code
      buf.write_char(' ')
    } else if in_code {
      buf.write_char(' ')
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}
