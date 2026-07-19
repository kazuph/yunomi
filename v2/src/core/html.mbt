///|
/// HTML entity escaping
pub fn escape_html(s : String) -> String {
  let buf = StringBuilder::new()
  let chars = s.to_array()
  for ch in chars {
    match ch {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      '"' => buf.write_string("&quot;")
      '\'' => buf.write_string("&#39;")
      _ => buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
/// Escape string for embedding in JavaScript (also prevents script injection)
pub fn escape_js_string(s : String) -> String {
  let buf = StringBuilder::new()
  let chars = s.to_array()
  for ch in chars {
    match ch {
      '\\' => buf.write_string("\\\\")
      '"' => buf.write_string("\\\"")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      '<' => buf.write_string("\\u003c")
      _ => buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
/// Serialize CsvData as JSON for DATA variable injection
fn serialize_csv_data_json(data : CsvData) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\"headers\":[")
  for i, h in data.headers {
    if i > 0 {
      buf.write_char(',')
    }
    buf.write_char('"')
    buf.write_string(escape_js_string(h))
    buf.write_char('"')
  }
  buf.write_string("],\"rows\":[")
  for i, row in data.rows {
    if i > 0 {
      buf.write_char(',')
    }
    buf.write_char('[')
    for j, cell in row {
      if j > 0 {
        buf.write_char(',')
      }
      buf.write_char('"')
      buf.write_string(escape_js_string(cell))
      buf.write_char('"')
    }
    buf.write_char(']')
  }
  buf.write_string("]}")
  buf.to_string()
}

///|
/// Serialize source lines as JSON array of single-element arrays (cli.cjs DATA format)
pub fn serialize_source_lines_json(lines : Array[String]) -> String {
  let buf = StringBuilder::new()
  buf.write_char('[')
  for i, line in lines {
    if i > 0 {
      buf.write_char(',')
    }
    buf.write_string("[\"")
    buf.write_string(escape_js_string(line))
    buf.write_string("\"]")
  }
  buf.write_char(']')
  buf.to_string()
}

///|
/// Minimal monochrome icons for header action buttons (lucide-style outlines)
pub let icon_svg_media : String = "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><rect x=\"3\" y=\"3\" width=\"18\" height=\"18\" rx=\"2\"/><circle cx=\"9\" cy=\"9\" r=\"2\"/><path d=\"m21 15-3.1-3.1a2 2 0 0 0-2.8 0L6 21\"/></svg>"

///|
pub let icon_svg_code : String = "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><polyline points=\"16 18 22 12 16 6\"/><polyline points=\"8 6 2 12 8 18\"/></svg>"

///|
pub let icon_svg_clock : String = "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><polyline points=\"12 6 12 12 16 14\"/></svg>"

///|
pub let icon_svg_moon : String = "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z\"/></svg>"

///|
pub let icon_svg_sun : String = "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2v2\"/><path d=\"M12 20v2\"/><path d=\"m4.93 4.93 1.41 1.41\"/><path d=\"m17.66 17.66 1.41 1.41\"/><path d=\"M2 12h2\"/><path d=\"M20 12h2\"/><path d=\"m6.34 17.66-1.41 1.41\"/><path d=\"m19.07 4.93-1.41 1.41\"/></svg>"

///|
/// Unresolved-questions pill icon (lucide "circle-help" outline, no emoji)
pub let icon_svg_help : String = "<svg width=\"14\" height=\"14\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3\"/><path d=\"M12 17h.01\"/></svg>"

///|
/// All-answered pill icon (lucide "check" outline, no emoji) — swapped in by
/// app.mbt's flash_answered_pill() as a brief post-confirm acknowledgement
/// (see task #21: closing straight from the last question's "完了" click
/// with zero visual feedback read as "did that just do nothing?").
pub let icon_svg_check : String = "<svg width=\"14\" height=\"14\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"M20 6 9 17l-5-5\"/></svg>"

///|
pub let icon_svg_approve : String = "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"M20 6 9 17l-5-5\"/></svg>"

///|
pub let icon_svg_request_changes : String = "<svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"M21 12a9 9 0 1 1-3-6.7\"/><path d=\"M21 3v6h-6\"/></svg>"

///|
fn build_page_start(
  buf : StringBuilder,
  filename : String,
  file_path? : String = "",
  tab_title? : String = "",
) -> Unit {
  let page_title = if tab_title.length() > 0 {
    tab_title
  } else if file_path.length() > 0 {
    filename
  } else {
    filename
  }
  buf.write_string(
    "<!DOCTYPE html><html lang=\"en\" data-theme=\"light\"><head><meta charset=\"UTF-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
  )
  buf.write_string(
    "<meta http-equiv=\"Cache-Control\" content=\"no-store, no-cache, must-revalidate\">",
  )
  buf.write_string("<meta http-equiv=\"Pragma\" content=\"no-cache\">")
  buf.write_string("<meta http-equiv=\"Expires\" content=\"0\">")
  buf.write_string(
    "<link rel=\"icon\" href=\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Ctext y='52' font-size='52'%3E%F0%9F%8D%B5%3C/text%3E%3C/svg%3E\">",
  )
  buf.write_string("<title>")
  buf.write_string(escape_html(page_title))
  buf.write_string(" | yunomi</title>")
  // highlight.js CDN stylesheets (dark/light theme support)
  buf.write_string(
    "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11/build/styles/github-dark.min.css\" id=\"hljs-theme-dark\" disabled>",
  )
  buf.write_string(
    "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11/build/styles/github.min.css\" id=\"hljs-theme-light\">",
  )
  buf.write_string(
    "<script src=\"https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11/build/highlight.min.js\"></script>",
  )
  buf.write_string("<style>")
  buf.write_string(build_css())
  buf.write_string("</style></head><body>")
  buf.write_string("<header><div class=\"meta\">")
  buf.write_string(
    "<a class=\"brand\" href=\"/\" aria-label=\"yunomi\"><span class=\"brand-mark\" aria-hidden=\"true\">🍵</span></a>",
  )
  buf.write_string("<h1>")
  if tab_title.length() > 0 && tab_title != filename {
    buf.write_string("<span class=\"title-path\">")
    buf.write_string(escape_html(tab_title))
    buf.write_string("</span>")
  }
  buf.write_string("<span class=\"title-file\">")
  buf.write_string(escape_html(filename))
  buf.write_string("</span></h1>")
  buf.write_string("</div><div class=\"actions\">")
  buf.write_string(
    "<span class=\"sse-dot sse-dot-connected\" id=\"sse-status\" role=\"status\" aria-live=\"polite\" title=\"Connected\"></span>",
  )
  buf.write_string(
    "<button class=\"pill\" id=\"pill-comments\" title=\"Click anywhere to comment / ESC to cancel\">Comments <strong id=\"comment-count\">0</strong></button>",
  )
  buf.write_string(
    "<span class=\"review-loop-header-badge\" id=\"review-loop-header-badge\" title=\"AI review loop status\">Round</span>",
  )
  buf.write_string(
    "<button class=\"media-sidebar-toggle\" id=\"media-sidebar-toggle\" title=\"Show / hide media thumbnail list\" aria-label=\"Toggle media gallery\">",
  )
  buf.write_string(icon_svg_media)
  buf.write_string(
    "<span class=\"toggle-count\" id=\"media-toggle-count\"></span></button>",
  )
  buf.write_string(
    "<button class=\"view-toggle\" id=\"view-toggle\" title=\"Hide source panel\" aria-label=\"Toggle source panel\">",
  )
  buf.write_string(icon_svg_code)
  buf.write_string("</button>")
  buf.write_string(
    "<button class=\"history-toggle\" id=\"history-toggle\" title=\"Show review history\" aria-label=\"Review history\">",
  )
  buf.write_string(icon_svg_clock)
  buf.write_string("</button>")
  buf.write_string("<div class=\"theme-picker\" id=\"theme-picker\">")
  buf.write_string(
    "<button class=\"theme-toggle\" id=\"theme-toggle\" title=\"Switch to dark theme\" aria-label=\"Toggle light and dark theme\"><span id=\"theme-icon\">",
  )
  buf.write_string(icon_svg_moon)
  buf.write_string("</span><span id=\"theme-label\">Light</span></button>")
  buf.write_string(
    "<button class=\"theme-menu-toggle\" id=\"theme-menu-toggle\" title=\"Choose color scheme\" aria-label=\"Choose color scheme\" aria-expanded=\"false\">▼</button>",
  )
  buf.write_string("<div class=\"theme-menu\" id=\"theme-menu\" hidden>")
  buf.write_string(
    "<button data-color-scheme=\"primer\"><span>Primer</span><small>GitHub-like</small></button>",
  )
  buf.write_string(
    "<button data-color-scheme=\"tokyo\"><span>Tokyo Night</span><small>sharp dark</small></button>",
  )
  buf.write_string(
    "<button data-color-scheme=\"catppuccin\"><span>Catppuccin</span><small>soft pastel</small></button>",
  )
  buf.write_string(
    "<button data-color-scheme=\"one-dark\"><span>Atom One</span><small>Light / Dark</small></button>",
  )
  buf.write_string(
    "<button data-color-scheme=\"solarized\"><span>Solarized</span><small>Light / Dark</small></button>",
  )
  buf.write_string(
    "<button data-color-scheme=\"gruvbox\"><span>Gruvbox</span><small>Light / Dark</small></button>",
  )
  buf.write_string("</div></div>")
  buf.write_string(
    "<button id=\"send-and-exit\" class=\"submit-exit-btn\">Submit review</button>",
  )
  buf.write_string("</div></header>")
}

///|
pub fn build_review_loop_mount(buf : StringBuilder) -> Unit {
  buf.write_string(
    "<section class=\"review-loop-panel\" id=\"review-loop-panel\" aria-live=\"polite\"></section>",
  )
}

///|
fn build_submit_modal(buf : StringBuilder) -> Unit {
  buf.write_string("<div class=\"modal-overlay\" id=\"submit-modal\">")
  buf.write_string("<div class=\"modal-dialog\">")
  buf.write_string("<h3>Submit review</h3>")
  buf.write_string(
    "<div class=\"review-loop-submit-state\" id=\"review-loop-submit-state\"></div>",
  )
  buf.write_string("<p class=\"modal-summary\" id=\"modal-summary\"></p>")
  buf.write_string(
    "<label for=\"global-comment\">Overall comment (optional)</label>",
  )
  buf.write_string(
    "<textarea id=\"global-comment\" placeholder=\"Add a summary or overall feedback...\"></textarea>",
  )
  buf.write_string(
    "<div class=\"mermaid-error-area\" id=\"mermaid-error-area\" style=\"display:none;\">",
  )
  buf.write_string(
    "<div style=\"background:var(--danger-bg, #fff3f3);border:1px solid var(--danger-border, #e88);border-radius:6px;padding:8px 12px;margin-bottom:12px;\">",
  )
  buf.write_string(
    "<strong style=\"color:var(--danger-text, #c33);\">Mermaid Errors</strong>",
  )
  buf.write_string(
    "<ul id=\"mermaid-error-list\" style=\"margin:4px 0 0 16px;padding:0;font-size:12px;color:var(--danger-text, #c33);\"></ul>",
  )
  buf.write_string("</div></div>")
  buf.write_string("<div class=\"image-attach-area\" id=\"submit-image-area\">")
  buf.write_string(
    "<label id=\"submit-image-label\">Attach images (Paste, 0/10)</label>",
  )
  buf.write_string(
    "<div class=\"image-preview-list\" id=\"submit-image-preview\"></div>",
  )
  buf.write_string("</div>")
  buf.write_string("<div class=\"modal-actions modal-actions-decision\">")
  buf.write_string(
    "<button class=\"decision-btn decision-approve\" id=\"modal-approve\" title=\"Approve\">" +
    icon_svg_approve +
    "Approve</button>",
  )
  buf.write_string("<button id=\"modal-cancel\">Cancel</button>")
  buf.write_string(
    "<button class=\"decision-btn decision-request-changes\" id=\"modal-request-changes\" title=\"Request Changes\">" +
    icon_svg_request_changes +
    "Request Changes <kbd class=\"kbd-hint\">\u{2318}Enter</kbd></button>",
  )
  buf.write_string("</div></div></div>")
}

///|
fn build_comment_list_aside(buf : StringBuilder) -> Unit {
  buf.write_string("<aside class=\"comment-list collapsed\">")
  buf.write_string("<h3>Comments</h3>")
  buf.write_string("<ol id=\"comment-list\"></ol>")
  buf.write_string(
    "<p class=\"hint\">Click \"Submit review\" to send pending comments and stop the server.</p>",
  )
  buf.write_string("</aside>")
}

///|
fn build_history_panel(buf : StringBuilder) -> Unit {
  buf.write_string("<aside class=\"history-panel\" id=\"history-panel\">")
  buf.write_string("<div class=\"history-panel-header\">")
  buf.write_string("<h3>Review History</h3>")
  buf.write_string(
    "<button class=\"history-panel-close\" id=\"history-panel-close\">&#10005;</button>",
  )
  buf.write_string("</div>")
  buf.write_string(
    "<div class=\"history-panel-body\" id=\"history-panel-body\">",
  )
  buf.write_string("<div class=\"history-empty\">No review history yet.</div>")
  buf.write_string("</div></aside>")
}

///|
fn build_recovery_modal(buf : StringBuilder) -> Unit {
  buf.write_string("<div class=\"modal-overlay\" id=\"recovery-modal\">")
  buf.write_string(
    "<div class=\"modal-dialog\"><h3>Restore Previous Draft?</h3>",
  )
  buf.write_string(
    "<p class=\"modal-summary\" id=\"recovery-summary\">Found an unsaved draft from a previous session.</p>",
  )
  buf.write_string("<div class=\"modal-actions\">")
  buf.write_string("<button id=\"recovery-discard\">Discard</button>")
  buf.write_string(
    "<button class=\"primary\" id=\"recovery-restore\">Restore</button>",
  )
  buf.write_string("</div></div></div>")
}

///|
/// Build questions modal HTML: a one-question-per-screen stepper (mirrors
/// Claude Code's AskUserQuestion — answer one, advance to the next, never a
/// tall scrolling stack of every question at once). The internal frontmatter
/// `id` never renders as visible text anywhere in this markup — it only
/// survives as a `data-qid` attribute so collect_yunomi_answers() (dom.mbt)
/// can key the submitted YAML `answers:` map the same way it always has.
/// The card heading IS the question text itself; a `context:` block (if the
/// author supplied one) renders directly under it as the judgment material.
fn build_questions_modal(
  buf : StringBuilder,
  questions : Array[YunomiQuestion],
) -> Unit {
  if questions.length() == 0 {
    return
  }
  let mut unresolved_count = 0
  for q in questions {
    if !q.resolved {
      unresolved_count = unresolved_count + 1
    }
  }
  let resolved_count = questions.length() - unresolved_count
  // Overlay
  buf.write_string(
    "<div class=\"yunomi-questions-overlay\" id=\"yunomi-questions-overlay\">",
  )
  buf.write_string(
    "<div class=\"yunomi-questions-modal\" id=\"yunomi-questions-modal\">",
  )
  buf.write_string("<div class=\"yunomi-questions-header\">")
  buf.write_string(
    "<span class=\"yunomi-questions-progress\" id=\"yunomi-questions-progress\">",
  )
  if unresolved_count > 0 {
    buf.write_string("1/")
    buf.write_string(unresolved_count.to_string())
  }
  buf.write_string("</span>")
  buf.write_string(
    "<button class=\"yunomi-questions-close\" id=\"yunomi-questions-close\" title=\"閉じる\" aria-label=\"閉じる\">&times;</button>",
  )
  buf.write_string("</div>")
  buf.write_string(
    "<div class=\"yunomi-questions-body\" id=\"yunomi-questions-body\">",
  )
  // Stepper: every unresolved question-card is present in the DOM (so
  // existing collect/persist helpers that query `.question-card` keep
  // working unchanged) but only the one at the current step carries
  // `.step-active` — app.mbt's render_question_step() toggles that class.
  buf.write_string(
    "<div class=\"yunomi-questions-stepper\" id=\"yunomi-questions-stepper\">",
  )
  let mut step_idx = 0
  for i, q in questions {
    if q.resolved {
      continue
    }
    buf.write_string("<div class=\"question-card")
    if step_idx == 0 {
      buf.write_string(" step-active")
    }
    buf.write_string("\" data-qid=\"")
    buf.write_string(escape_html(q.id))
    buf.write_string("\" data-step=\"")
    buf.write_string(step_idx.to_string())
    buf.write_string("\">")
    buf.write_string("<div class=\"q-title\">")
    buf.write_string(escape_html(q.question))
    buf.write_string("</div>")
    if q.context.length() > 0 {
      buf.write_string("<div class=\"q-context\">")
      buf.write_string(escape_html(q.context))
      buf.write_string("</div>")
    }
    if q.options.length() > 0 {
      buf.write_string("<div class=\"q-options\">")
      for j, opt in q.options {
        buf.write_string(
          "<button type=\"button\" class=\"q-option-btn\" data-qi=\"",
        )
        buf.write_string(i.to_string())
        buf.write_string("\" data-oi=\"")
        buf.write_string(j.to_string())
        buf.write_string("\" data-val=\"")
        buf.write_string(escape_html(opt))
        buf.write_string("\">")
        buf.write_string(escape_html(opt))
        buf.write_string("</button>")
      }
      buf.write_string("</div>")
    }
    buf.write_string("<textarea class=\"q-answer\" data-qi=\"")
    buf.write_string(i.to_string())
    buf.write_string("\" placeholder=\"回答を入力\">")
    buf.write_string(escape_html(q.answer))
    buf.write_string("</textarea>")
    buf.write_string("</div>")
    step_idx = step_idx + 1
  }
  buf.write_string("</div>")
  // Answer-summary confirmation screen — the stepper's virtual "last step +
  // 1". Reached by clicking "完了" on the final question instead of closing
  // the modal outright: a real reviewer answered a 3rd question, clicked
  // "完了", and the dialog just vanished with no indication anything had
  // been recorded ("最悪のUX" — task #21). app.mbt's render_question_step()
  // populates this via render_answer_summary() and toggles it visible by
  // adding .summary-active to #yunomi-questions-body; left empty here since
  // its content depends on live DOM state (edits made after page load),
  // not the server-rendered snapshot.
  buf.write_string(
    "<div class=\"yunomi-questions-summary\" id=\"yunomi-questions-summary\"></div>",
  )
  // Resolved questions (collapsible, outside the step flow — no action
  // needed on them, so they never occupy a step)
  if resolved_count > 0 {
    buf.write_string("<div class=\"yunomi-resolved-section\">")
    buf.write_string(
      "<button type=\"button\" class=\"yunomi-resolved-toggle\"><span class=\"arrow\">\u{25B8}</span>解決済み (",
    )
    buf.write_string(resolved_count.to_string())
    buf.write_string(")</button><div class=\"yunomi-resolved-list\">")
    for q in questions {
      if !q.resolved {
        continue
      }
      buf.write_string(
        "<div class=\"question-card resolved\"><div class=\"q-title\">",
      )
      buf.write_string(escape_html(q.question))
      buf.write_string("</div>")
      if q.answer.length() > 0 {
        buf.write_string("<div class=\"q-answer-display\">")
        buf.write_string(escape_html(q.answer))
        buf.write_string("</div>")
      }
      buf.write_string("</div>")
    }
    buf.write_string("</div></div>")
  }
  buf.write_string("</div>")
  buf.write_string("<div class=\"yunomi-questions-footer\">")
  buf.write_string(
    "<button type=\"button\" class=\"yunomi-questions-later\" id=\"yunomi-questions-later\" title=\"後で回答する\">後で回答する</button>",
  )
  buf.write_string(
    "<button type=\"button\" class=\"yunomi-questions-next\" id=\"yunomi-questions-next\">",
  )
  buf.write_string(if unresolved_count <= 1 { "完了" } else { "次へ" })
  buf.write_string("</button>")
  buf.write_string("</div></div></div>")
  // Minimal floating pill (replaces the old full-width sentence banner):
  // just an icon + numeric badge, no explanatory copy, no emoji.
  buf.write_string(
    "<button type=\"button\" class=\"yunomi-questions-bar\" id=\"yunomi-questions-bar-open\" title=\"未回答の質問を開く\" aria-label=\"未回答の質問を開く\">",
  )
  // Two icons, pre-rendered and toggled via the `.done` class (see
  // app.mbt's flash_answered_pill()) — swapping which one is visible is a
  // pure CSS class flip, no innerHTML surgery needed on this button after
  // the badge span (which update_questions_badge() also targets) is added.
  buf.write_string("<span class=\"yunomi-questions-bar-icon-pending\">")
  buf.write_string(icon_svg_help)
  buf.write_string("</span><span class=\"yunomi-questions-bar-icon-done\">")
  buf.write_string(icon_svg_check)
  buf.write_string("</span>")
  buf.write_string(
    "<span class=\"yunomi-questions-bar-count\" id=\"yunomi-questions-bar-count\">",
  )
  buf.write_string(unresolved_count.to_string())
  buf.write_string("</span></button>")
}

///|
/// Build questions notice bar (legacy, now integrated into questions modal)
fn build_questions_notice(
  buf : StringBuilder,
  questions : Array[YunomiQuestion],
) -> Unit {
  if questions.length() == 0 {
    return
  }
  // Notice is now handled by the questions bar, but keep for backward compatibility
  let mut pending = 0
  for q in questions {
    if !q.resolved {
      pending = pending + 1
    }
  }
  if pending > 0 {
    buf.write_string(
      "<div id=\"questions-notice\" style=\"display:none\"></div>",
    )
  }
}

///|
/// Serialize questions array to JSON
fn serialize_questions_json(questions : Array[YunomiQuestion]) -> String {
  let buf = StringBuilder::new()
  buf.write_char('[')
  for i, q in questions {
    if i > 0 {
      buf.write_char(',')
    }
    buf.write_string("{\"id\":")
    buf.write_string(json_quote(q.id))
    buf.write_string(",\"question\":")
    buf.write_string(json_quote(q.question))
    buf.write_string(",\"context\":")
    buf.write_string(json_quote(q.context))
    buf.write_string(",\"resolved\":")
    buf.write_string(if q.resolved { "true" } else { "false" })
    buf.write_string(",\"answer\":")
    buf.write_string(json_quote(q.answer))
    buf.write_string(",\"options\":[")
    for j, opt in q.options {
      if j > 0 {
        buf.write_char(',')
      }
      buf.write_string(json_quote(opt))
    }
    buf.write_string("]}")
  }
  buf.write_char(']')
  buf.to_string()
}

///|
/// JSON-encode a string value with quotes
fn json_quote(s : String) -> String {
  let buf = StringBuilder::new()
  buf.write_char('"')
  buf.write_string(escape_js_string(s))
  buf.write_char('"')
  buf.to_string()
}

///|
fn build_script_footer(
  buf : StringBuilder,
  port : Int,
  mode : String,
  filename : String,
  server_instance_id? : String = "",
) -> Unit {
  // Mermaid CDN for markdown mode
  if mode == "markdown" {
    buf.write_string(
      "<script src=\"https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js\"></script>",
    )
    buf.write_string("<script>")
    buf.write_string("window.__mermaidErrors=[];")
    buf.write_string("window.__collectMermaidErrors=async function(){")
    buf.write_string("window.__mermaidErrors=[];")
    buf.write_string("var divs=document.querySelectorAll('.mermaid');")
    buf.write_string("for(var i=0;i<divs.length;i++){")
    buf.write_string("var d=divs[i];")
    buf.write_string("var noSvg=!d.querySelector('svg');")
    buf.write_string("var errSvg=!!d.querySelector('.error-icon');")
    buf.write_string("if(noSvg||errSvg){")
    buf.write_string(
      "var line=parseInt(d.getAttribute('data-source-line'))||0;",
    )
    buf.write_string("var src=d.getAttribute('data-source')||'';")
    buf.write_string("var msg='Mermaid render failed';")
    buf.write_string(
      "try{await mermaid.parse(src);}catch(e){msg=e.message||String(e);}",
    )
    buf.write_string(
      "console.error('[yunomi] Mermaid error at line '+line+':',msg);",
    )
    buf.write_string(
      "window.__mermaidErrors.push({line:line,message:msg,source:src});",
    )
    buf.write_string("var container=d.closest('.mermaid-container');")
    buf.write_string(
      "if(container&&!container.querySelector('.mermaid-error-banner')){",
    )
    buf.write_string("var banner=document.createElement('div');")
    buf.write_string("banner.className='mermaid-error-banner';")
    buf.write_string(
      "banner.textContent='\\u26A0 Mermaid error (line '+line+'): '+msg;",
    )
    buf.write_string("container.prepend(banner);")
    buf.write_string("}")
    buf.write_string("}")
    buf.write_string("}")
    buf.write_string("};")
    // Primer-inspired Mermaid theme variables so diagrams match the app palette.
    buf.write_string("window.__mermaidConfig=function(isLight){")
    buf.write_string(
      "var light={primaryColor:'#ddf4ff',primaryTextColor:'#24292f',primaryBorderColor:'#0969da',lineColor:'#0969da',secondaryColor:'#f6f8fa',secondaryBorderColor:'#8250df',tertiaryColor:'#ffffff',tertiaryBorderColor:'#d0d7de',edgeLabelBackground:'#ffffff',clusterBkg:'#f6f8fa',clusterBorder:'#d0d7de',mainBkg:'#ddf4ff',nodeBorder:'#0969da',background:'#ffffff'};",
    )
    buf.write_string(
      "var dark={primaryColor:'#1f6feb33',primaryTextColor:'#e6edf3',primaryBorderColor:'#2f81f7',lineColor:'#79c0ff',textColor:'#e6edf3',signalColor:'#e6edf3',signalTextColor:'#e6edf3',actorTextColor:'#e6edf3',actorLineColor:'#8b949e',labelTextColor:'#e6edf3',loopTextColor:'#e6edf3',noteTextColor:'#e6edf3',secondaryColor:'#161b22',secondaryBorderColor:'#a371f7',tertiaryColor:'#0d1117',tertiaryBorderColor:'#30363d',edgeLabelBackground:'#161b22',clusterBkg:'#161b22',clusterBorder:'#30363d',mainBkg:'#1f6feb33',nodeBorder:'#2f81f7',background:'#0d1117'};",
    )
    buf.write_string(
      "return {startOnLoad:false,logLevel:0,theme:isLight?'default':'dark',securityLevel:'loose',themeVariables:isLight?light:dark};};",
    )
    buf.write_string(
      "mermaid.initialize(window.__mermaidConfig(document.documentElement.getAttribute('data-theme')==='light'));",
    )
    buf.write_string(
      "mermaid.run().then(function(){return window.__collectMermaidErrors();}).catch(function(e){console.error('[yunomi] Mermaid render error:',e);return window.__collectMermaidErrors();});",
    )
    buf.write_string("window.__reRenderMermaid=function(theme){")
    buf.write_string(
      "document.querySelectorAll('.mermaid-error-banner').forEach(function(b){b.remove();});",
    )
    buf.write_string(
      "mermaid.initialize(window.__mermaidConfig(theme==='light'));",
    )
    buf.write_string("var divs=document.querySelectorAll('.mermaid');")
    buf.write_string(
      "divs.forEach(function(d){d.removeAttribute('data-processed');d.innerHTML=d.getAttribute('data-source');});",
    )
    buf.write_string(
      "if(divs.length>0)mermaid.run({nodes:Array.from(divs)}).then(function(){return window.__collectMermaidErrors();}).catch(function(e){console.error('[yunomi] Mermaid render error:',e);return window.__collectMermaidErrors();});",
    )
    buf.write_string("};")
    // Mermaid fullscreen is handled by ui.js (ZoomPanViewer-based)
    buf.write_string("</script>")
  }
  // highlight.js initialization (highlight code blocks in preview, skip mermaid)
  if mode == "markdown" {
    buf.write_string("<script>")
    buf.write_string("if(typeof hljs!=='undefined'){")
    buf.write_string("var preview=document.querySelector('.md-preview');")
    buf.write_string(
      "if(preview){preview.querySelectorAll('pre code').forEach(function(block){",
    )
    buf.write_string(
      "if(block.closest('.mermaid-container')||block.classList.contains('hljs'))return;",
    )
    buf.write_string("hljs.highlightElement(block);")
    buf.write_string("});}")
    buf.write_string("}")
    buf.write_string("</script>")
  }
  buf.write_string("<script type=\"module\" src=\"/ui.js\"></script>")
  buf.write_string("<script>window.__YUNOMI_PORT__=")
  buf.write_string(port.to_string())
  buf.write_string(";window.__YUNOMI_MODE__=\"")
  buf.write_string(escape_js_string(mode))
  buf.write_string("\";window.__YUNOMI_FILENAME__=\"")
  buf.write_string(escape_js_string(filename))
  buf.write_string("\";window.__YUNOMI_SERVER_INSTANCE__=\"")
  buf.write_string(escape_js_string(server_instance_id))
  buf.write_string("\";</script></body></html>")
}

///|
/// Build complete HTML page for CSV viewer (cli.cjs compatible selectors)
pub fn build_csv_html(
  data : CsvData,
  filename : String,
  port : Int,
  tab_title? : String = "",
  server_instance_id? : String = "",
  mode? : String = "csv",
) -> String {
  let buf = StringBuilder::new()
  build_page_start(buf, filename, tab_title~)
  // Filter menu (cli.cjs L4989-4996)
  buf.write_string(
    "<div class=\"filter-menu\" id=\"filter-menu\"><label class=\"menu-check\"><input type=\"checkbox\" id=\"freeze-col-check\" /> Freeze up to this column</label><button data-action=\"not-empty\">Rows where not empty</button><button data-action=\"empty\">Rows where empty</button><button data-action=\"contains\">Contains...</button><button data-action=\"not-contains\">Does not contain...</button><button data-action=\"reset\">Clear filter</button></div>",
  )
  // Row menu (cli.cjs L4997-4999)
  buf.write_string(
    "<div class=\"filter-menu\" id=\"row-menu\"><label class=\"menu-check\"><input type=\"checkbox\" id=\"freeze-row-check\" /> Freeze up to this row</label></div>",
  )
  buf.write_string(
    "<div style=\"padding:16px;overflow-x:auto\"><table id=\"csv-table\"><thead><tr>",
  )
  for i, header in data.headers {
    buf.write_string("<th data-col=\"")
    buf.write_string(i.to_string())
    buf.write_string("\"><div class=\"th-inner\">")
    buf.write_string(escape_html(header))
    buf.write_string("<span class=\"resizer\" data-col=\"")
    buf.write_string(i.to_string())
    buf.write_string("\"></span></div></th>")
  }
  buf.write_string("</tr></thead><tbody id=\"tbody\">")
  for i, row in data.rows {
    buf.write_string("<tr data-row=\"")
    buf.write_string(i.to_string())
    buf.write_string("\">")
    for j, cell in row {
      buf.write_string("<td data-row=\"")
      buf.write_string(i.to_string())
      buf.write_string("\" data-col=\"")
      buf.write_string(j.to_string())
      buf.write_string("\">")
      buf.write_string(escape_html(cell))
      buf.write_string("</td>")
    }
    buf.write_string("</tr>")
  }
  buf.write_string("</tbody></table></div>")
  build_comment_list_aside(buf)
  build_submit_modal(buf)
  build_history_panel(buf)
  build_recovery_modal(buf)
  buf.write_string("<script>const DATA = ")
  buf.write_string(serialize_csv_data_json(data))
  buf.write_string(";</script>")
  build_script_footer(buf, port, mode, filename, server_instance_id~)
  buf.to_string()
}

///|
/// Build HTML page for diff viewer
pub fn build_diff_html(
  data : DiffData,
  filename : String,
  port : Int,
  tab_title? : String = "",
  server_instance_id? : String = "",
) -> String {
  let buf = StringBuilder::new()
  build_page_start(buf, filename, tab_title~)
  buf.write_string(
    "<div class=\"diff-review-shell\"><aside class=\"diff-file-tree\" id=\"diff-file-tree\"><div class=\"diff-file-tree-title\">Files</div>",
  )
  for file in data.files {
    let display_path = if file.new_path.length() > 0 {
      file.new_path
    } else {
      file.old_path
    }
    buf.write_string("<div class=\"diff-file-tree-item\" data-file=\"")
    buf.write_string(escape_html(display_path))
    buf.write_string(
      "\"><label class=\"diff-viewed-control\"><input type=\"checkbox\" class=\"diff-viewed-checkbox\" data-file=\"",
    )
    buf.write_string(escape_html(display_path))
    buf.write_string("\" aria-label=\"")
    buf.write_string(escape_html(display_path))
    buf.write_string(
      " review state\"><span class=\"diff-viewed-state\">Unreviewed</span></label><button type=\"button\" class=\"diff-file-link\" data-file=\"",
    )
    buf.write_string(escape_html(display_path))
    buf.write_string("\">")
    buf.write_string(escape_html(display_path))
    buf.write_string("</button></div>")
  }
  buf.write_string("</aside><main class=\"diff-review-main\">")
  build_review_loop_mount(buf)
  buf.write_string(
    "<div class=\"diff-toolbar\" role=\"toolbar\" aria-label=\"Diff view\"><div class=\"diff-view-mode\" role=\"group\" aria-label=\"View mode\"><button type=\"button\" id=\"diff-unified-toggle\" data-mode=\"unified\">Unified</button><button type=\"button\" id=\"diff-split-toggle\" data-mode=\"split\">Split</button></div></div><div class=\"diff-view\">",
  )
  for file in data.files {
    let display_path = if file.new_path.length() > 0 {
      file.new_path
    } else {
      file.old_path
    }
    let mut diff_line_count = 0
    for hunk in file.hunks {
      diff_line_count = diff_line_count + hunk.lines.length()
    }
    let is_large = !file.is_binary && diff_line_count > 500
    buf.write_string("<section class=\"diff-file-block\" data-file=\"")
    buf.write_string(escape_html(display_path))
    buf.write_string("\">")
    if is_large {
      buf.write_string(
        "<details class=\"diff-file diff-file-large\"><summary class=\"diff-file-header\">",
      )
    } else {
      buf.write_string("<div class=\"diff-file-header\">")
    }
    buf.write_string(escape_html(display_path))
    if is_large {
      buf.write_string(" <span class=\"diff-label large\">")
      buf.write_string(diff_line_count.to_string())
      buf.write_string(" lines</span>")
    }
    if file.is_new {
      buf.write_string(" <span class=\"diff-label new\">new file</span>")
    } else if file.is_deleted {
      buf.write_string(" <span class=\"diff-label deleted\">deleted</span>")
    } else if file.is_binary {
      buf.write_string(" <span class=\"diff-label binary\">binary</span>")
    }
    if is_large {
      buf.write_string("</summary>")
    } else {
      buf.write_string("</div>")
    }
    if !file.is_binary {
      for hunk in file.hunks {
        buf.write_string("<div class=\"diff-hunk-header\">@@ -")
        buf.write_string(hunk.old_start.to_string())
        buf.write_string(",")
        buf.write_string(hunk.old_count.to_string())
        buf.write_string(" +")
        buf.write_string(hunk.new_start.to_string())
        buf.write_string(",")
        buf.write_string(hunk.new_count.to_string())
        buf.write_string(" @@")
        if hunk.context.length() > 0 {
          buf.write_string(" ")
          buf.write_string(escape_html(hunk.context))
        }
        buf.write_string("</div>")
        let mut old_line = hunk.old_start
        let mut new_line = hunk.new_start
        for line in hunk.lines {
          let css_class = match line.kind {
            Addition => "diff-line addition"
            Deletion => "diff-line deletion"
            Context => "diff-line"
          }
          buf.write_string("<div class=\"")
          buf.write_string(css_class)
          buf.write_string("\" data-file=\"")
          buf.write_string(escape_html(display_path))
          buf.write_string("\">")
          let mut old_num = ""
          let mut new_num = ""
          match line.kind {
            Deletion => {
              old_num = old_line.to_string()
              old_line = old_line + 1
            }
            Addition => {
              new_num = new_line.to_string()
              new_line = new_line + 1
            }
            Context => {
              old_num = old_line.to_string()
              new_num = new_line.to_string()
              old_line = old_line + 1
              new_line = new_line + 1
            }
          }
          buf.write_string("<span class=\"line-num old-num\">")
          buf.write_string(old_num)
          buf.write_string("</span><span class=\"line-num new-num\">")
          buf.write_string(new_num)
          buf.write_string(
            "</span><span class=\"line-content unified-content\">",
          )
          buf.write_string(escape_html(line.content))
          buf.write_string("</span><span class=\"split-content old-content\">")
          if line.kind != Addition {
            buf.write_string(escape_html(line.content))
          }
          buf.write_string("</span><span class=\"split-content new-content\">")
          if line.kind != Deletion {
            buf.write_string(escape_html(line.content))
          }
          buf.write_string("</span></div>")
        }
      }
    }
    if is_large {
      buf.write_string("</details>")
    }
    buf.write_string("</section>")
  }
  buf.write_string("</div></main></div>")
  build_comment_list_aside(buf)
  build_submit_modal(buf)
  build_history_panel(buf)
  build_recovery_modal(buf)
  build_script_footer(buf, port, "diff", filename, server_instance_id~)
  buf.to_string()
}

///|
/// Build HTML page for text viewer
pub fn build_text_html(
  lines : Array[String],
  filename : String,
  port : Int,
  tab_title? : String = "",
  server_instance_id? : String = "",
) -> String {
  let buf = StringBuilder::new()
  build_page_start(buf, filename, tab_title~)
  buf.write_string("<div class=\"text-view\">")
  build_review_loop_mount(buf)
  for i, line in lines {
    let line_num = i + 1
    buf.write_string("<div class=\"text-line\" data-row=\"")
    buf.write_string(i.to_string())
    buf.write_string("\"><span class=\"line-num\">")
    buf.write_string(line_num.to_string())
    buf.write_string("</span><span class=\"line-content\">")
    buf.write_string(escape_html(line))
    buf.write_string("</span></div>")
  }
  buf.write_string("</div>")
  build_comment_list_aside(buf)
  build_submit_modal(buf)
  build_history_panel(buf)
  build_recovery_modal(buf)
  build_script_footer(buf, port, "text", filename, server_instance_id~)
  buf.to_string()
}
