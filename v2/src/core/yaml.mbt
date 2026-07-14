///|
fn option_string(value : String?, fallback : String) -> String {
  match value {
    Some(v) => v
    None => fallback
  }
}

///|
fn option_int(value : Int?, fallback : Int) -> Int {
  match value {
    Some(v) => v
    None => fallback
  }
}

///|
fn option_attachments(value : Array[String]?) -> Array[String] {
  match value {
    Some(v) => v
    None => []
  }
}

///|
fn write_comment_yaml(buf : StringBuilder, comment : Comment, indent : String) -> Unit {
  let file = option_string(comment.file, "")
  let end_row = option_int(comment.end_row, comment.row)
  let end_col = option_int(comment.end_col, comment.col)
  let snippet = option_string(comment.snippet, if comment.value.length() > 0 { comment.value } else { "" })
  let selector = option_string(comment.selector, "")
  let bounds = option_string(comment.bounds, "")
  let element_text = option_string(comment.element_text, "")
  let attachments = option_attachments(comment.attachments)
  buf.write_string(indent)
  buf.write_string("- file: ")
  buf.write_string(yaml_escape_string(file))
  buf.write_char('\n')
  buf.write_string(indent)
  buf.write_string("  row: ")
  buf.write_string(comment.row.to_string())
  buf.write_char('\n')
  buf.write_string(indent)
  buf.write_string("  col: ")
  buf.write_string(comment.col.to_string())
  buf.write_char('\n')
  buf.write_string(indent)
  buf.write_string("  end_row: ")
  buf.write_string(end_row.to_string())
  buf.write_char('\n')
  buf.write_string(indent)
  buf.write_string("  end_col: ")
  buf.write_string(end_col.to_string())
  buf.write_char('\n')
  buf.write_string(indent)
  buf.write_string("  text: ")
  buf.write_string(yaml_escape_string(comment.text))
  buf.write_char('\n')
  if comment.value.length() > 0 {
    buf.write_string(indent)
    buf.write_string("  value: ")
    buf.write_string(yaml_escape_string(comment.value))
    buf.write_char('\n')
  }
  buf.write_string(indent)
  buf.write_string("  snippet: ")
  buf.write_string(yaml_escape_string(snippet))
  buf.write_char('\n')
  buf.write_string(indent)
  buf.write_string("  context_before: ")
  buf.write_string(yaml_escape_string(comment.context_before))
  buf.write_char('\n')
  buf.write_string(indent)
  buf.write_string("  context_after: ")
  buf.write_string(yaml_escape_string(comment.context_after))
  buf.write_char('\n')
  buf.write_string(indent)
  buf.write_string("  selector: ")
  buf.write_string(yaml_escape_string(selector))
  buf.write_char('\n')
  buf.write_string(indent)
  buf.write_string("  bounds: ")
  buf.write_string(yaml_escape_string(bounds))
  buf.write_char('\n')
  buf.write_string(indent)
  buf.write_string("  element_text: ")
  buf.write_string(yaml_escape_string(element_text))
  buf.write_char('\n')
  buf.write_string(indent)
  buf.write_string("  attachments:")
  if attachments.is_empty() {
    buf.write_string(" []\n")
  } else {
    buf.write_char('\n')
    for attachment in attachments {
      buf.write_string(indent)
      buf.write_string("    - ")
      buf.write_string(yaml_escape_string(attachment))
      buf.write_char('\n')
    }
  }
  if comment.image_path.length() > 0 {
    buf.write_string(indent)
    buf.write_string("  image_path: ")
    buf.write_string(yaml_escape_string(comment.image_path))
    buf.write_char('\n')
  }
}

///|
fn write_summary_images_yaml(buf : StringBuilder, images : Array[String], indent : String) -> Unit {
  if images.length() == 0 {
    return
  }
  buf.write_string(indent)
  buf.write_string("summary_images:\n")
  for image in images {
    buf.write_string(indent)
    buf.write_string("  - ")
    buf.write_string(yaml_escape_string(image))
    buf.write_char('\n')
  }
}

///|
/// Serialize a ReviewResult to YAML string
pub fn review_to_yaml(result : ReviewResult) -> String {
  let buf = StringBuilder::new()
  match result.action {
    Some(a) => {
      buf.write_string("action: ")
      buf.write_string(a.to_string())
      buf.write_char('\n')
    }
    None => ()
  }
  buf.write_string("file: ")
  buf.write_string(yaml_escape_string(result.file))
  buf.write_char('\n')
  buf.write_string("mode: ")
  buf.write_string(result.mode.to_string())
  buf.write_char('\n')
  buf.write_string("comments:\n")
  for comment in result.comments {
    write_comment_yaml(buf, comment, "  ")
  }
  buf.write_string("summary: ")
  buf.write_string(yaml_escape_string(result.summary))
  buf.write_char('\n')
  write_summary_images_yaml(buf, result.summary_images, "")
  if result.answers.length() > 2 {
    buf.write_string("answers: ")
    buf.write_string(yaml_escape_string(result.answers))
    buf.write_char('\n')
  }
  if result.mermaid_errors.length() > 0 {
    buf.write_string("mermaid_errors:\n")
    for err in result.mermaid_errors {
      buf.write_string("  - line: ")
      buf.write_string(err.line.to_string())
      buf.write_char('\n')
      buf.write_string("    error: ")
      buf.write_string(yaml_escape_string(err.message))
      buf.write_char('\n')
    }
  }
  match result.decision {
    Some(d) => {
      buf.write_string("decision: ")
      buf.write_string(d.to_string())
      buf.write_char('\n')
    }
    None => ()
  }
  buf.to_string()
}

///|
/// Serialize multiple ReviewResults
pub fn reviews_to_yaml(results : Array[ReviewResult]) -> String {
  if results.length() == 1 {
    review_to_yaml(results[0])
  } else {
    let buf = StringBuilder::new()
    // Use action from first result (all results share the same action)
    match results[0].action {
      Some(a) => {
        buf.write_string("action: ")
        buf.write_string(a.to_string())
        buf.write_char('\n')
      }
      None => ()
    }
    buf.write_string("files:\n")
    for result in results {
      buf.write_string("  - file: ")
      buf.write_string(yaml_escape_string(result.file))
      buf.write_char('\n')
      buf.write_string("    mode: ")
      buf.write_string(result.mode.to_string())
      buf.write_char('\n')
      buf.write_string("    comments:\n")
      for comment in result.comments {
        write_comment_yaml(buf, comment, "      ")
      }
      buf.write_string("    summary: ")
      buf.write_string(yaml_escape_string(result.summary))
      buf.write_char('\n')
      write_summary_images_yaml(buf, result.summary_images, "    ")
      if result.answers.length() > 2 {
        buf.write_string("    answers: ")
        buf.write_string(yaml_escape_string(result.answers))
        buf.write_char('\n')
      }
      if result.mermaid_errors.length() > 0 {
        buf.write_string("    mermaid_errors:\n")
        for err in result.mermaid_errors {
          buf.write_string("      - line: ")
          buf.write_string(err.line.to_string())
          buf.write_char('\n')
          buf.write_string("        error: ")
          buf.write_string(yaml_escape_string(err.message))
          buf.write_char('\n')
        }
      }
      match result.decision {
        Some(d) => {
          buf.write_string("    decision: ")
          buf.write_string(d.to_string())
          buf.write_char('\n')
        }
        None => ()
      }
    }
    buf.to_string()
  }
}

///|
pub fn yaml_escape_string(s : String) -> String {
  let needs_quote = s.contains(":") ||
    s.contains("#") ||
    s.contains("'") ||
    s.contains("\"") ||
    s.contains("\n") ||
    s.contains("[") ||
    s.contains("]") ||
    s.contains("{") ||
    s.contains("}") ||
    s.contains(",") ||
    s.contains("&") ||
    s.contains("*") ||
    s.contains("!") ||
    s.contains("|") ||
    s.contains(">") ||
    s.contains("%") ||
    s.contains("@")
  if needs_quote {
    let buf = StringBuilder::new()
    buf.write_char('\'')
    // Escape single quotes by doubling them
    let chars = s.to_array()
    for ch in chars {
      if ch == '\'' {
        buf.write_string("''")
      } else {
        buf.write_char(ch)
      }
    }
    buf.write_char('\'')
    buf.to_string()
  } else {
    s
  }
}
