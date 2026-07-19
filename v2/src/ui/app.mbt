///|
/// Comment stored in the app
struct AppComment {
  row : Int
  col : Int
  mut text : String
  mut image : String
  mut value : String
  mut pending : Bool
  mut sent : Bool
}

///|
/// Application state
let comments : Map[String, AppComment] = {}

///|
/// Currently active inline comment target
let active_key : Ref[String] = Ref("")

///|
/// Values restored when an inline edit is cancelled.
let active_original_text : Ref[String] = Ref("")

///|
let active_original_image : Ref[String] = Ref("")

///|
let active_was_new : Ref[Bool] = Ref(false)

///|
/// Currently highlighted target for keyboard-driven comments
let selected_comment_row : Ref[Int] = Ref(-1)

///|
let selected_comment_col : Ref[Int] = Ref(0)

///|
let selected_comment_el : Ref[Element] = Ref(null_element())

///|

///|
/// Scroll sync state
let scroll_sync_raf : Ref[Int] = Ref(0)

///|
let scroll_sync_disabled_until : Ref[Double] = Ref(0.0)

///|
let scroll_active_pane : Ref[String] = Ref("")

///|
/// Drag selection state
let is_dragging : Ref[Bool] = Ref(false)

///|
let drag_start_row : Ref[Int] = Ref(-1)

///|
let drag_end_row : Ref[Int] = Ref(-1)

///|
/// Max number of images attachable to the submit review
let submit_image_limit : Int = 10

///|
/// Image state for paste attachment
let current_comment_image : Ref[String] = Ref("")

///|
let submit_images : Array[String] = []

///|
let close_report_sent : Ref[Bool] = Ref(false)

///|
let submit_in_flight : Ref[Bool] = Ref(false)

///|
let pending_decision : Ref[String] = Ref("")

///|
/// Decision constants (must match @core.ReviewDecision::to_string)
let decision_approve : String = "approve"

///|
let decision_request_changes : String = "request_changes"

///|
/// Action constants (must match @core.ReviewAction::to_string)
let action_final_approve : String = "final_approve"

///|
let action_final_request_changes : String = "final_request_changes"

///|
/// Pending action for submit
let pending_action : Ref[String] = Ref("")

///|
let review_loop_unresolved_count : Ref[Int] = Ref(0)

///|
let review_tab_id : Ref[String] = Ref("")

///|
let page_instance_id : Ref[String] = Ref("")

///|
/// Set right before a reload we triggered ourselves (SSE "reload" event —
/// the AI agent updated the file being reviewed while this tab was open).
/// pagehide/beforeunload fire for this navigation exactly like a real tab
/// close, but this reload is expected and imminent: the reloaded page will
/// re-register via /session/open momentarily. Skipping the redundant /close
/// keeps the active-tab bookkeeping stable during that handoff.
let intentional_reload_in_progress : Ref[Bool] = Ref(false)

///|
/// Delegate to core's parse_int_safe
fn str_to_int(s : String) -> Int {
  @core.parse_int_safe(s)
}

///|
/// Truncate string to max length
fn truncate(s : String, max : Int) -> String {
  if s.length() <= max {
    s
  } else {
    let buf = StringBuilder::new()
    let chars = s.to_array()
    for i in 0..<max {
      buf.write_char(chars[i])
    }
    buf.to_string()
  }
}

///|
fn open_inline_comment_editor(
  target : Element,
  key : String,
  row : Int,
  col : Int,
) -> Unit {
  if get_tag_name(target) == "SUMMARY" {
    let details = closest(target, "details")
    if !is_null(details) {
      set_attribute(details, "open", "")
    }
  }
  active_key.val = key
  selected_comment_row.val = row
  selected_comment_col.val = col
  selected_comment_el.val = target
  let editor_text = Ref("")
  let comment_value = build_comment_value(target, row, col)
  match comments.get(key) {
    Some(comment) => {
      comment.value = comment_value
      active_original_text.val = comment.text
      active_original_image.val = comment.image
      active_was_new.val = false
      editor_text.val = comment.text
      current_comment_image.val = comment.image
    }
    None => {
      active_original_text.val = ""
      active_original_image.val = ""
      active_was_new.val = true
      current_comment_image.val = ""
      comments.set(key, {
        row,
        col,
        text: "",
        image: "",
        value: comment_value,
        pending: true,
        sent: false,
      })
    }
  }
  show_inline_comment_editor(
    target,
    key,
    row,
    col,
    editor_text.val,
    if comment_value.has_prefix("Video ") {
      comment_value
    } else {
      resolve_comment_target_preview(target)
    },
    if pending_comment_count() == 0 {
      "Start a review"
    } else {
      "Add review comment"
    },
    "Add single comment",
    fn() { save_comment() },
    fn() { send_now_comment() },
    fn() { cancel_inline_comment_edit() },
    fn() { sync_active_comment_draft() },
  )
  render_comment_image_preview()
}

///|
fn resolve_comment_target_preview(target : Element) -> String {
  if is_null(target) {
    return ""
  }
  if has_class(target, "mermaid-container") {
    let mermaid = query_in(target, ".mermaid")
    let source = get_attr(mermaid, "data-source")
    if source.length() > 0 {
      return source
    }
    return "Mermaid diagram"
  }
  let content = get_text_content_without_comment_buttons(target)
  if content.length() > 0 {
    return content
  }
  let tag = get_tag_name(target)
  if tag == "IMG" {
    let alt = get_attr(target, "alt")
    if alt.length() > 0 {
      return alt
    }
    let src = get_src(target)
    if src.length() > 0 {
      return "[image] " + extract_filename(src)
    }
  }
  if tag == "VIDEO" {
    let title = get_attr(target, "title")
    if title.length() > 0 {
      return title
    }
    let src = get_attr(target, "src")
    if src.length() > 0 {
      return "[video] " + extract_filename(src)
    }
  }
  let image = query_in(target, "img")
  if !is_null(image) {
    return resolve_comment_target_preview(image)
  }
  let video = query_in(target, "video.video-preview")
  if !is_null(video) {
    return resolve_comment_target_preview(video)
  }
  let mermaid = query_in(target, ".mermaid-container")
  if !is_null(mermaid) {
    return resolve_comment_target_preview(mermaid)
  }
  ""
}

///|
fn format_comment_time(seconds : Double) -> String {
  let m = (seconds / 60.0).to_int()
  let s = (seconds % 60.0).to_int()
  if s < 10 {
    "\{m}:0\{s}"
  } else {
    "\{m}:\{s}"
  }
}

///|
fn source_line_for_row(row : Int) -> String {
  let data = js_get_data()
  if row >= 0 && row < data.length() && data[row].length() > 0 {
    data[row][0]
  } else {
    ""
  }
}

///|
fn build_comment_value(target : Element, row : Int, col : Int) -> String {
  let source_line = source_line_for_row(row)
  if is_null(target) {
    return source_line
  }
  let timeline = closest(target, ".timeline-thumb-wrapper")
  if !is_null(timeline) {
    let wrapper = closest(timeline, ".video-overlay-wrapper")
    let video = query_in(wrapper, "video.video-preview")
    let img = query_in(timeline, "img.timeline-thumb")
    let time_raw = get_dataset(img, "time")
    let seconds = parse_float(time_raw)
    let label = resolve_comment_target_preview(timeline)
    let src = get_attr(video, "src")
    return "Video thumbnail \{format_comment_time(seconds)} (\{seconds.to_string()}s): " +
      label +
      " src=" +
      src +
      " | source: " +
      source_line
  }
  let tag = get_tag_name(target)
  if tag == "VIDEO" {
    let seconds = video_get_current_time(target)
    let label = resolve_comment_target_preview(target)
    let src = get_attr(target, "src")
    return "Video \{format_comment_time(seconds)} (\{seconds.to_string()}s): " +
      label +
      " src=" +
      src +
      " | source: " +
      source_line
  }
  let wrapped_video = query_in(target, "video.video-preview")
  if !is_null(wrapped_video) {
    return build_comment_value(wrapped_video, row, col)
  }
  if col > 0 {
    let cell_text = resolve_comment_target_preview(target)
    return "Markdown table cell R\{row + 1} C\{col}: " +
      cell_text +
      " | source: " +
      source_line
  }
  if has_class(target, "mermaid-container") {
    return "Mermaid block lines \{row + 1}: " + source_line
  }
  let preview = resolve_comment_target_preview(target)
  if preview.length() > 0 && source_line.length() > 0 && preview != source_line {
    preview + " | source: " + source_line
  } else if preview.length() > 0 {
    preview
  } else {
    source_line
  }
}

///|
/// Get localStorage key for comment storage (cli.cjs compatible)
fn get_storage_key() -> String {
  let filename = get_yunomi_filename()
  "yunomi:comments:\{filename}"
}

///|
/// Initialize the app - called on page load
pub fn init_app() -> Unit {
  let mode = get_yunomi_mode()
  let port = get_yunomi_port()
  load_review_loop_state()
  // Restore theme from localStorage
  let saved_theme = local_storage_get("yunomi:theme")
  if saved_theme.length() > 0 {
    set_theme(saved_theme)
    toggle_hljs_theme(saved_theme)
    rerender_mermaid(saved_theme)
    update_theme_button(saved_theme)
  }
  init_color_scheme_menu()
  // Setup theme toggle with localStorage persistence
  let theme_btn = query("#theme-toggle")
  if !is_null(theme_btn) {
    on(theme_btn, "click", fn(_e) {
      let current = get_theme()
      if current == "dark" {
        set_theme("light")
        toggle_hljs_theme("light")
        rerender_mermaid("light")
        local_storage_set("yunomi:theme", "light")
        update_theme_button("light")
      } else {
        set_theme("dark")
        toggle_hljs_theme("dark")
        rerender_mermaid("dark")
        local_storage_set("yunomi:theme", "dark")
        update_theme_button("dark")
      }
    })
  }
  // Setup submit button
  let submit_btn = query("#send-and-exit")
  if !is_null(submit_btn) {
    on(submit_btn, "click", fn(_e) { show_submit_modal() })
  }
  // Setup modal buttons
  let modal_cancel = query("#modal-cancel")
  if !is_null(modal_cancel) {
    on(modal_cancel, "click", fn(_e) { hide_submit_modal() })
  }
  let submit_modal = query("#submit-modal")
  if !is_null(submit_modal) {
    on(submit_modal, "click", fn(e) {
      // The overlay is the part outside Submit Review. It is a normal
      // dismissal path, while the draft remains available on reopen.
      if elem_eq(event_target(e), submit_modal) {
        hide_submit_modal()
      }
    })
  }
  let modal_approve = query("#modal-approve")
  if !is_null(modal_approve) {
    on(modal_approve, "click", fn(_e) {
      pending_decision.val = decision_approve
      pending_action.val = action_final_approve
      submit_review(port)
    })
  }
  let modal_request_changes = query("#modal-request-changes")
  if !is_null(modal_request_changes) {
    on(modal_request_changes, "click", fn(_e) {
      pending_decision.val = decision_request_changes
      pending_action.val = action_final_request_changes
      submit_review(port)
    })
  }
  // Setup recovery modal buttons
  let recovery_restore = query("#recovery-restore")
  if !is_null(recovery_restore) {
    on(recovery_restore, "click", fn(_e) { restore_comments() })
  }
  let recovery_discard = query("#recovery-discard")
  if !is_null(recovery_discard) {
    on(recovery_discard, "click", fn(_e) { discard_comments() })
  }
  // Keyboard shortcut: Cmd/Ctrl+Enter context-dependent
  on_doc("keydown", fn(e) {
    if event_key(e) == "Enter" && (event_meta_key(e) || event_ctrl_key(e)) {
      prevent_default(e)
      let active = get_active_element()
      if inline_comment_editor_open() &&
        get_attr(active, "id") == "comment-input" {
        save_comment()
        return
      }
      // If submit modal is open, default to request changes
      let modal = query("#submit-modal")
      if !is_null(modal) && has_class(modal, "visible") {
        pending_decision.val = decision_request_changes
        pending_action.val = action_final_request_changes
        submit_review(port)
        return
      }
      let submit_btn = query("#send-and-exit")
      if !is_null(submit_btn) {
        _click_element(submit_btn)
        return
      }
    }
    if event_key(e) == "Escape" {
      if inline_comment_editor_open() {
        cancel_inline_comment_edit()
      }
      hide_submit_modal()
    }
  })
  // Also support Cmd/Ctrl+Enter from within submit modal textarea
  let global_comment_input = query("#global-comment")
  if !is_null(global_comment_input) {
    on(global_comment_input, "keydown", fn(e) {
      if event_key(e) == "Enter" && (event_meta_key(e) || event_ctrl_key(e)) {
        prevent_default(e)
        pending_decision.val = decision_request_changes
        pending_action.val = action_final_request_changes
        submit_review(port)
      }
    })
    // Persist the summary/decision draft as the human types it, same as
    // comments — a reload (or the close-abandonment safety net) must never
    // be able to wipe it silently.
    on(global_comment_input, "input", fn(_e) { persist_draft() })
  }
  // Setup view toggle (cli.cjs L7232-7270: preview-only panel state)
  init_view_toggle()
  // Setup pill-comments (comment list toggle)
  let pill_comments = query("#pill-comments")
  if !is_null(pill_comments) {
    on(pill_comments, "click", fn(_e) { toggle_comment_list_panel() })
  }
  // Setup click handlers based on mode
  match mode {
    "csv" | "tsv" => {
      setup_csv_clicks()
      init_csv_resizers_and_filters()
    }
    "diff" => setup_diff_clicks()
    "markdown" => setup_csv_clicks()
    _ => setup_text_clicks()
  }
  setup_diff_enhancements_dom(get_yunomi_filename())
  setup_vim_review_keyboard(get_yunomi_filename())
  // Setup scroll sync and preview click for markdown mode
  if mode == "markdown" {
    setup_scroll_sync()
    setup_preview_click()
    setup_preview_comment_buttons()
    setup_comment_keyboard_shortcuts()
    setup_preview_mouseup()
    setup_task_decision_checkboxes()
    // Initialize heading toggles (collapsible sections)
    init_heading_toggles()
    // Setup fullscreen viewers with pure MoonBit ZoomPanViewer/VideoTimeline
    setup_mermaid_fullscreen_moonbit()
    setup_image_fullscreen_moonbit()
    setup_video_fullscreen_moonbit()
    // Initialize media sidebar (pure MoonBit implementation)
    ignore(set_timeout(fn() { init_media_sidebar() }, 500))
  }
  // Setup drag selection handlers
  setup_drag_handlers()
  // Questions overlay, bar, and auto-popup
  setup_questions_ui()
  // Setup history toggle
  let history_btn = query("#history-toggle")
  if !is_null(history_btn) {
    on(history_btn, "click", fn(_e) { toggle_history_panel() })
  }
  let history_close = query("#history-panel-close")
  if !is_null(history_close) {
    on(history_close, "click", fn(_e) { toggle_history_panel() })
  }
  // Setup paste handler for image attachment
  setup_paste_handler()
  // Check for saved comments and show recovery modal if present
  check_recovery()
  if retire_if_stale_review_session(get_yunomi_server_instance()) {
    window_close()
    ignore(set_timeout(fn() { location_replace("about:blank") }, 400))
    return
  }
  // Register the tab so the server can tell reload from close.
  setup_close_detection(port)
  // Setup SSE for live reload
  setup_sse(port)
}

///|
fn load_review_loop_state() -> Unit {
  let url = location_origin() + "/review-state"
  fetch_get(url, fn(data) {
    review_loop_unresolved_count.val = render_review_loop_panel_json(data)
  })
}

///|
fn pending_comment_count() -> Int {
  let count = Ref(0)
  comments.each(fn(_key, comment) {
    if comment_has_content(comment) && comment.pending {
      count.val = count.val + 1
    }
  })
  count.val
}

///|
fn setup_task_decision_checkboxes() -> Unit {
  let boxes = query_all(".task-decision-checkbox")
  for box in boxes {
    on(box, "click", fn(e) { stop_propagation(e) })
    on(box, "change", fn(e) {
      stop_propagation(e)
      let target = event_target(e)
      let line = str_to_int(get_attr(target, "data-source-line"))
      let text = get_attr(target, "data-decision-text")
      let checked = is_checked(target)
      send_decision_to_server(target, line, text, checked)
    })
  }
}

///|
fn send_decision_to_server(
  box : Element,
  line : Int,
  text : String,
  checked : Bool,
) -> Unit {
  if line <= 0 {
    return
  }
  let url = location_origin() + "/decision"
  let checked_json = if checked { "true" } else { "false" }
  let body = "{\"file\":\"" +
    get_yunomi_filename() +
    "\",\"line\":" +
    line.to_string() +
    ",\"text\":" +
    json_encode_string(text) +
    ",\"checked\":" +
    checked_json +
    "}"
  fetch_post(url, body, fn(response) {
    if response == "error" {
      set_checked(box, !checked)
      show_toast("Decision update failed")
    }
  })
}

///|
fn setup_csv_clicks() -> Unit {
  let cells = query_all("td[data-row]:not(#md-preview *)")
  for cell in cells {
    on(cell, "click", fn(e) {
      if is_dragging.val {
        return
      }
      let target = event_target(e)
      let row_str = get_attr(target, "data-row")
      let col_str = get_attr(target, "data-col")
      let key = "\{row_str}:\{col_str}"
      show_inline_comment(target, key, str_to_int(row_str), str_to_int(col_str))
    })
    on(cell, "mousedown", fn(e) {
      let target = event_target(e)
      let row_str = get_attr(target, "data-row")
      if row_str.length() > 0 {
        begin_drag(str_to_int(row_str))
      }
      ignore(e)
    })
  }
}

///|
fn setup_diff_clicks() -> Unit {
  let lines = query_all(".diff-line")
  for i, line in lines {
    let row = i + 1
    set_attribute(line, "data-row", row.to_string())
    on(line, "click", fn(e) {
      let target = closest(event_target(e), ".diff-line")
      if !is_null(target) {
        let file = get_attr(target, "data-file")
        let content = get_text_content(target)
        let key = "\{file}:\{truncate(content, 20)}"
        show_inline_comment(target, key, row, 0)
      }
    })
  }
}

///|
fn setup_text_clicks() -> Unit {
  let lines = query_all(".text-line")
  for line in lines {
    on(line, "click", fn(e) {
      if is_dragging.val {
        return
      }
      let target = closest(event_target(e), ".text-line")
      if !is_null(target) {
        let row_str = get_attr(target, "data-row")
        let key = "\{row_str}:0"
        show_inline_comment(target, key, str_to_int(row_str), 0)
      }
    })
    on(line, "mousedown", fn(e) {
      let target = closest(event_target(e), ".text-line")
      if !is_null(target) {
        let row_str = get_attr(target, "data-row")
        if row_str.length() > 0 {
          begin_drag(str_to_int(row_str))
        }
      }
    })
  }
}

///|
/// localStorage key that flags "the reload about to happen (or that just
/// happened) was triggered by this app's own SSE 'reload' handler, not a
/// real F5 or a tab reopened after being closed for a while." Scoped per
/// file, same as the draft itself. See setup_sse()'s "reload" handler for
/// where it's set, and check_recovery() for where it's consumed.
fn reload_inflight_key() -> String {
  "yunomi:reload-inflight:\{get_yunomi_filename()}"
}

///|
/// Check for a saved draft (comments, summary, and/or question answers) and
/// either auto-restore it (if this load follows a reload this app
/// triggered itself — see reload_inflight_key()) or show the recovery
/// modal for the human to decide (with TTL validation).
///
/// Skipping the confirmation modal for self-triggered reloads matters in
/// practice: a busy review session where the file under review keeps
/// getting edited (e.g. multiple agents actively working on the same
/// REPORT.md while a human is mid-review) can fire several of these
/// reloads within seconds of each other. Requiring a fresh manual "Restore"
/// click after EVERY one of them means the human can lose their in-progress
/// answer to a NEXT reload before they even get a chance to click — from
/// their side that reads as "the dialog flashes and vanishes" / "my answer
/// just disappeared", even though the draft was never actually lost in
/// localStorage the whole time.
fn check_recovery() -> Unit {
  let key = get_storage_key()
  let stored = ls_get(key)
  let reload_flag_key = reload_inflight_key()
  let was_self_triggered_reload = ls_get(reload_flag_key).length() > 0
  if was_self_triggered_reload {
    ls_remove(reload_flag_key)
  }
  if stored.length() == 0 {
    return
  }
  if is_storage_expired(stored) {
    ls_remove(key)
    return
  }
  if was_self_triggered_reload {
    restore_comments()
    return
  }
  let modal = query("#recovery-modal")
  if !is_null(modal) {
    add_class(modal, "visible")
    remove_class(modal, "hidden")
  }
}

///|
/// Restore the full saved draft: comments, the global summary/decision
/// textarea, and frontmatter question answers (option selection + free
/// text) — everything persist_draft() saves under one key.
fn restore_comments() -> Unit {
  let key = get_storage_key()
  let stored = ls_get(key)
  if stored.length() > 0 {
    let entries = parse_stored_comments(stored)
    for entry in entries {
      if entry.length() >= 4 {
        let k = entry[0]
        let row = str_to_int(entry[1])
        let col = str_to_int(entry[2])
        let text = entry[3]
        let value = if entry.length() > 4 { entry[4] } else { "" }
        if text.length() > 0 {
          let pending = entry.length() > 5 && entry[5] == "true"
          let sent = entry.length() <= 6 || entry[6] == "true"
          comments.set(k, { row, col, text, image: "", value, pending, sent })
        }
      }
    }
    update_comment_indicators()
    let summary = parse_stored_summary(stored)
    if summary.length() > 0 {
      let summary_el = query("#global-comment")
      if !is_null(summary_el) {
        set_value(summary_el, summary)
      }
    }
    let stored_answers = parse_stored_answers(stored)
    apply_yunomi_draft_answers(stored_answers)
    // Resume the stepper at whatever question the human was on when the
    // draft was last saved — not step 0 — so a modal that vanished mid-Q2
    // (reload, crash, accidental close) reopens on Q2, not back at Q1.
    question_step_index.val = parse_stored_step(stored)
    render_question_step()
    // Badge only — closing is owned exclusively by the explicit
    // Next/完了/確定して閉じる button flow (advance_question_step()) and
    // the X/Later/backdrop/ESC escape hatches, never by a timer reacting
    // to DOM state alone. This restore may be fully answered already (the
    // human had finished typing the last question right before a reload
    // interrupted them); an implicit auto-close here would undo the
    // "always show on load" guarantee the very next tick after
    // hide_recovery_modal() below opens it — the exact bug report task
    // #19 exists to fix, and the same class of bug task #21's mandatory
    // summary confirmation screen would otherwise reintroduce.
    update_questions_badge()
    if parse_stored_submit_open(stored) {
      show_submit_modal()
    } else {
      let active = parse_stored_active_comment(stored)
      if active.length() >= 3 {
        let key = active[0]
        let row = str_to_int(active[1])
        let col = str_to_int(active[2])
        ignore(
          set_timeout(
            fn() {
              let target = resolve_restored_comment_target(key, row, col)
              if !is_null(target) {
                show_inline_comment(target, key, row, col)
              }
            },
            0,
          ),
        )
      }
    }
    // hide_recovery_modal() re-checks for unanswered questions once the
    // recovery modal is gone (see its doc comment) — that single re-check
    // point covers both this Restore path and the Discard path, so we don't
    // duplicate the open-questions-modal decision here.
    hide_recovery_modal()
  } else {
    hide_recovery_modal()
  }
}

///|
fn discard_comments() -> Unit {
  ls_remove(get_storage_key())
  hide_recovery_modal()
}

///|
/// True when the page has at least one frontmatter question that is not
/// marked `resolved: true` — i.e. there is a stepper card to show at all.
/// Unlike count_unanswered_questions(), this is NOT affected by whether a
/// restored draft (or the server-rendered `answer:`) already fills every
/// field in: a question can be fully prefilled and still count here, which
/// is exactly the point — "already answered" must not be confused with
/// "nothing left for the human to see or confirm".
fn has_unresolved_questions() -> Bool {
  query_all("#yunomi-questions-stepper .question-card").length() > 0
}

///|
/// Hide the recovery modal and give the deferred questions auto-popup a
/// chance to run. setup_questions_ui()'s auto-popup skips opening the
/// questions modal for as long as the recovery modal is visible (see its
/// comment near the 500ms set_timeout), so once the human has resolved the
/// recovery modal (Restore or Discard — both paths call this function) we
/// re-check here: if any unresolved question exists, open the questions
/// modal now. This is the single re-check point for both paths, so there
/// is no risk of a double-open.
///
/// Deliberately uses has_unresolved_questions() (static: "does a question
/// exist at all"), not count_unanswered_questions() (dynamic: "is anything
/// still blank right now"). A real review session hit exactly this gap: a
/// prior round's answers survived in the restored draft, every question
/// counted as "answered" the instant Restore ran, and the stepper never
/// got a chance to show them — the human never saw a dialog was involved
/// at all. "気がついたら回答する" is explicitly not an acceptable fallback
/// here: if a question exists, the human sees it on load, full stop —
/// already-answered ones just arrive prefilled so confirming is a matter
/// of stepping through, not re-typing.
fn hide_recovery_modal() -> Unit {
  let modal = query("#recovery-modal")
  if !is_null(modal) {
    remove_class(modal, "visible")
    add_class(modal, "hidden")
  }
  if has_unresolved_questions() && !app_dialog_visible() {
    open_questions_modal()
  }
}

///|
fn show_inline_comment(
  target : Element,
  key : String,
  row : Int,
  col : Int,
) -> Unit {
  open_inline_comment_editor(target, key, row, col)
}

///|
fn close_inline_comment() -> Unit {
  close_inline_comment_editor()
  blur_active_element()
  active_key.val = ""
  // Clear preview highlight and source selection
  let old_highlights = query_all(".preview-highlight")
  for el in old_highlights {
    remove_class(el, "preview-highlight")
  }
  let old_selected = query_all("td.selected")
  for el in old_selected {
    remove_class(el, "selected")
  }
}

///|
fn cancel_inline_comment_edit() -> Unit {
  let key = active_key.val
  if key.length() > 0 {
    if active_was_new.val {
      ignore(comments.remove(key))
    } else {
      match comments.get(key) {
        Some(comment) => {
          comment.text = active_original_text.val
          comment.image = active_original_image.val
        }
        None => ()
      }
    }
  }
  current_comment_image.val = ""
  close_inline_comment()
  update_comment_indicators()
  persist_draft()
}

///|
fn comment_has_content(comment : AppComment) -> Bool {
  comment.text.length() > 0 || comment.image.length() > 0
}

///|
fn comment_location_label(comment : AppComment) -> String {
  if comment.col > 0 {
    "R" + comment.row.to_string() + " C" + comment.col.to_string()
  } else if comment.row > 0 {
    "Line " + comment.row.to_string()
  } else {
    "General"
  }
}

///|
fn resolve_comment_indicator_target(comment : AppComment) -> Element {
  if comment.col > 0 {
    let exact = query(
      "[data-row=\"\{comment.row}\"][data-col=\"\{comment.col}\"]",
    )
    if !is_null(exact) {
      return exact
    }
  }
  let line_cell = query(
    "td[data-row=\"\{comment.row}\"][data-col=\"1\"]:not(#md-preview *)",
  )
  if !is_null(line_cell) {
    return line_cell
  }
  let text_line = query(".text-line[data-row=\"\{comment.row}\"]")
  if !is_null(text_line) {
    return text_line
  }
  let diff_line = query(".diff-line[data-row=\"\{comment.row}\"]")
  if !is_null(diff_line) {
    return diff_line
  }
  null_element()
}

///|
fn render_comment_list() -> Unit {
  let list = query("#comment-list")
  if is_null(list) {
    return
  }
  let buf = StringBuilder::new()
  let mut count = 0
  comments.each(fn(key, comment) {
    if comment_has_content(comment) {
      count = count + 1
      buf.write_string("<li data-key=\"")
      buf.write_string(@core.escape_html(key))
      buf.write_string("\">")
      buf.write_string(
        "<button class=\"comment-list-entry\" data-comment-key=\"",
      )
      buf.write_string(@core.escape_html(key))
      buf.write_string(
        "\" style=\"all:unset;display:block;width:100%;cursor:pointer\">",
      )
      buf.write_string("<strong>")
      buf.write_string(@core.escape_html(comment_location_label(comment)))
      buf.write_string("</strong>")
      buf.write_string("<div>")
      if comment.text.length() > 0 {
        buf.write_string(@core.escape_html(truncate(comment.text, 120)))
      } else {
        buf.write_string("[image only]")
      }
      buf.write_string("</div></button></li>")
    }
  })
  if count == 0 {
    set_inner_html(
      list, "<li style=\"color:var(--text-dim);list-style:none;margin-left:-18px\">No comments yet</li>",
    )
    return
  }
  set_inner_html(list, buf.to_string())
  render_comment_replies_for_file(get_yunomi_filename())
  let entries = query_all(".comment-list-entry")
  for entry in entries {
    on(entry, "click", fn(e) {
      let target = event_target(e)
      let button = closest(target, ".comment-list-entry")
      if is_null(button) {
        return
      }
      let key = get_attr(button, "data-comment-key")
      match comments.get(key) {
        Some(comment) => {
          let comment_target = resolve_comment_indicator_target(comment)
          if !is_null(comment_target) {
            scroll_into_view(comment_target)
            show_inline_comment(comment_target, key, comment.row, comment.col)
          }
        }
        None => ()
      }
    })
  }
}

///|
fn toggle_comment_list_panel() -> Unit {
  let panel = query(".comment-list")
  if is_null(panel) {
    return
  }
  render_comment_list()
  if has_class(panel, "collapsed") {
    remove_class(panel, "collapsed")
  } else {
    add_class(panel, "collapsed")
  }
}

///|
fn send_now_comment() -> Unit {
  let textarea = query("#comment-input")
  if is_null(textarea) {
    return
  }
  let text = get_value(textarea)
  let key = active_key.val
  if key.length() == 0 {
    return
  }
  match comments.get(key) {
    Some(comment) => {
      comment.text = text
      comment.image = current_comment_image.val
      comment.pending = false
      comment.sent = true
      send_comment_to_server(
        comment.row,
        comment.col,
        text,
        "send-now",
        key,
        current_comment_image.val.length() > 0,
      )
      current_comment_image.val = ""
      close_inline_comment()
      update_comment_indicators()
      persist_draft()
      render_comment_list()
      show_comment_list_panel()
    }
    None => ()
  }
}

///|
fn show_comment_list_panel() -> Unit {
  let panel = query(".comment-list")
  if !is_null(panel) {
    remove_class(panel, "collapsed")
  }
}

///|
fn save_comment() -> Unit {
  let textarea = query("#comment-input")
  if is_null(textarea) {
    return
  }
  let text = get_value(textarea)
  let key = active_key.val
  let is_delete = text.length() == 0 && current_comment_image.val.length() == 0
  if key.length() > 0 {
    match comments.get(key) {
      Some(comment) => {
        if is_delete && comment.sent {
          send_comment_to_server(
            comment.row,
            comment.col,
            "",
            "delete",
            key,
            false,
          )
        }
        comment.text = text
        comment.image = current_comment_image.val
        comment.pending = true
      }
      None => ()
    }
    if is_delete {
      ignore(comments.remove(key))
    }
  }
  current_comment_image.val = ""
  close_inline_comment()
  update_comment_indicators()
  persist_draft()
}

///|
/// Fullscreen viewers own keyboard focus while visible. Commit an open editor
/// as a local pending draft before transferring that ownership.
fn close_inline_comment_before_fullscreen() -> Unit {
  if inline_comment_editor_open() {
    save_comment()
  }
}

///|
/// Send a comment event to the server for real-time IPC
fn send_comment_to_server(
  row : Int,
  col : Int,
  text : String,
  event_type : String,
  key : String,
  has_image : Bool,
) -> Unit {
  let port = get_yunomi_port()
  if port <= 0 {
    return
  }
  let url = location_origin() + "/comment"
  let buf = StringBuilder::new()
  buf.write_string("{\"type\":")
  buf.write_string(json_encode_string(event_type))
  buf.write_string(",\"row\":")
  buf.write_string(row.to_string())
  buf.write_string(",\"col\":")
  buf.write_string(col.to_string())
  buf.write_string(",\"text\":")
  buf.write_string(json_encode_string(text))
  buf.write_string(",\"key\":")
  buf.write_string(json_encode_string(key))
  if has_image {
    buf.write_string(",\"hasImage\":true")
  }
  buf.write_string("}")
  fetch_post(url, buf.to_string(), fn(response) {
    // Show sent/failed badge on the comment indicator
    update_sent_badge(key, response != "error")
  })
}

///|
/// Update sent/failed badge on comment list item
fn update_sent_badge(key : String, success : Bool) -> Unit {
  let list_items = query_all("#comment-list li")
  for item in list_items {
    let item_key = get_attr(item, "data-key")
    if item_key == key {
      let existing_badge = query_in(item, ".comment-sent-badge")
      if !is_null(existing_badge) {
        remove_element(existing_badge)
      }
      let badge_html = if success {
        "<span class=\"comment-sent-badge sent\">sent</span>"
      } else {
        "<span class=\"comment-sent-badge failed\">failed</span>"
      }
      append_html(item, badge_html)
      // Auto-remove badge after 3 seconds
      ignore(
        set_timeout_dom(
          fn() {
            let badge = query_in(item, ".comment-sent-badge")
            if !is_null(badge) {
              remove_element(badge)
            }
          },
          3000,
        ),
      )
    }
  }
}

///|
fn update_comment_indicators() -> Unit {
  let all_commented = query_all(".has-comment")
  for el in all_commented {
    remove_class(el, "has-comment")
  }
  clear_inline_saved_comments()
  let mut count = 0
  comments.each(fn(key, comment) {
    if comment_has_content(comment) {
      count = count + 1
      let el = resolve_comment_indicator_target(comment)
      if !is_null(el) {
        add_class(el, "has-comment")
      }
      render_inline_saved_comment(
        key,
        comment.row,
        comment.col,
        comment.text,
        comment.image,
        comment.value,
        comment.pending,
      )
    }
  })
  // Update comment count badge
  let count_el = query("#comment-count")
  if !is_null(count_el) {
    set_text_content(count_el, count.to_string())
  }
  bind_inline_saved_comments(fn(key, target, row, col) {
    if !is_null(target) {
      show_inline_comment(target, key, row, col)
    }
  })
  render_comment_list()
}

///|
fn show_submit_modal() -> Unit {
  let modal = query("#submit-modal")
  let list = query("#modal-summary")
  if is_null(modal) || is_null(list) {
    return
  }
  let questions = query("#yunomi-questions-overlay")
  if !is_null(questions) && has_class(questions, "visible") {
    close_questions_modal()
  }
  let buf = StringBuilder::new()
  comments.each(fn(key, comment) {
    if comment.text.length() > 0 && comment.pending {
      buf.write_string("<li><span class=\"location\">")
      buf.write_string(@core.escape_html(key))
      buf.write_string("</span>: ")
      buf.write_string(@core.escape_html(comment.text))
      buf.write_string("</li>")
    }
  })
  let html = buf.to_string()
  if html.length() == 0 {
    set_inner_html(
      list, "<li style=\"color:var(--text-dim)\">No comments yet</li>",
    )
  } else {
    set_inner_html(list, html)
  }
  let approve = query("#modal-approve")
  if !is_null(approve) {
    let has_unresolved_threads = review_loop_unresolved_count.val > 0
    set_disabled(approve, has_unresolved_threads)
    if has_unresolved_threads {
      set_attribute(
        approve, "title", "Resolve all open review threads before approving",
      )
    } else {
      set_attribute(approve, "title", "Approve")
    }
  }
  let loop_state = query("#review-loop-submit-state")
  if !is_null(loop_state) {
    let status_text = get_review_loop_status_text()
    if status_text.length() > 0 {
      let suffix = if review_loop_unresolved_count.val > 0 {
        " — Resolve before approving"
      } else {
        ""
      }
      set_text_content(loop_state, status_text + suffix)
      set_style(loop_state, "display", "block")
      if review_loop_unresolved_count.val == 0 {
        add_class(loop_state, "ready")
      } else {
        remove_class(loop_state, "ready")
      }
    } else {
      set_text_content(loop_state, "")
      set_style(loop_state, "display", "none")
      remove_class(loop_state, "ready")
    }
  }
  let header_badge = query("#review-loop-header-badge")
  if !is_null(header_badge) {
    let status_text = get_review_loop_status_text()
    if status_text.length() > 0 {
      set_text_content(header_badge, status_text)
      set_style(header_badge, "display", "inline-flex")
      if review_loop_unresolved_count.val == 0 {
        add_class(header_badge, "ready")
      } else {
        remove_class(header_badge, "ready")
      }
    } else {
      set_text_content(header_badge, "")
      set_style(header_badge, "display", "none")
      remove_class(header_badge, "ready")
    }
  }
  // Show mermaid errors if any
  // Show mermaid errors if any
  let mermaid_error_area = query("#mermaid-error-area")
  let mermaid_error_list = query("#mermaid-error-list")
  let err_count = get_mermaid_error_count()
  if err_count > 0 &&
    !is_null(mermaid_error_area) &&
    !is_null(mermaid_error_list) {
    let err_buf = StringBuilder::new()
    for i = 0; i < err_count; i = i + 1 {
      let line = get_mermaid_error_line(i)
      let msg = get_mermaid_error_message(i)
      err_buf.write_string("<li><strong>Line ")
      err_buf.write_string(line.to_string())
      err_buf.write_string(":</strong> ")
      err_buf.write_string(@core.escape_html(msg))
      err_buf.write_string("</li>")
    }
    set_inner_html(mermaid_error_list, err_buf.to_string())
    set_style(mermaid_error_area, "display", "block")
    log_mermaid_errors_to_console()
  } else if !is_null(mermaid_error_area) {
    set_style(mermaid_error_area, "display", "none")
  }
  add_class(modal, "visible")
  let summary = query("#global-comment")
  if !is_null(summary) {
    focus_element(summary)
  }
}

///|
fn hide_submit_modal() -> Unit {
  let modal = query("#submit-modal")
  if !is_null(modal) {
    remove_class(modal, "visible")
  }
  persist_draft()
}

///|
fn sync_active_comment_draft() -> Unit {
  let key = active_key.val
  if key.length() == 0 {
    return
  }
  let textarea = query("#comment-input")
  if is_null(textarea) {
    return
  }
  let text = get_value(textarea)
  match comments.get(key) {
    Some(comment) => {
      comment.text = text
      comment.image = current_comment_image.val
    }
    None => ()
  }
  persist_draft()
}

///|
fn build_review_payload() -> String {
  sync_active_comment_draft()
  let summary_el = query("#global-comment")
  let summary = if is_null(summary_el) { "" } else { get_value(summary_el) }
  let buf = StringBuilder::new()
  buf.write_string("{\"summary\":")
  buf.write_string(json_encode_string(summary))
  buf.write_string(",\"comments\":[")
  let first = Ref(true)
  comments.each(fn(_key, comment) {
    if comment.text.length() > 0 && comment.pending {
      if !first.val {
        buf.write_char(',')
      }
      buf.write_string("{\"row\":")
      buf.write_string(comment.row.to_string())
      buf.write_string(",\"col\":")
      buf.write_string(comment.col.to_string())
      buf.write_string(",\"text\":")
      buf.write_string(json_encode_string(comment.text))
      if comment.value.length() > 0 {
        buf.write_string(",\"value\":")
        buf.write_string(json_encode_string(comment.value))
      }
      if comment.image.length() > 0 {
        buf.write_string(",\"image\":")
        buf.write_string(json_encode_string(comment.image))
      }
      buf.write_char('}')
      first.val = false
    }
  })
  buf.write_string("],\"summaryImages\":[")
  for i, img in submit_images {
    if i > 0 {
      buf.write_char(',')
    }
    buf.write_string(json_encode_string(img))
  }
  buf.write_string("],\"yunomiAnswers\":")
  let answers_json = collect_yunomi_answers()
  if answers_json.length() > 2 {
    buf.write_string(answers_json)
  } else {
    buf.write_string("{}")
  }
  // Include mermaid errors
  let merr_count = get_mermaid_error_count()
  if merr_count > 0 {
    buf.write_string(",\"mermaidErrors\":[")
    for i = 0; i < merr_count; i = i + 1 {
      if i > 0 {
        buf.write_char(',')
      }
      buf.write_string("{\"line\":")
      buf.write_string(get_mermaid_error_line(i).to_string())
      buf.write_string(",\"message\":")
      buf.write_string(json_encode_string(get_mermaid_error_message(i)))
      buf.write_char('}')
    }
    buf.write_string("]")
  }
  // Include decision if set
  if pending_decision.val.length() > 0 {
    buf.write_string(",\"decision\":")
    buf.write_string(json_encode_string(pending_decision.val))
  }
  // Include action
  if pending_action.val.length() > 0 {
    buf.write_string(",\"action\":")
    buf.write_string(json_encode_string(pending_action.val))
  }
  buf.write_string("}")
  buf.to_string()
}

///|
fn report_tab_closed(_port : Int) -> Unit {
  if submit_in_flight.val || close_report_sent.val {
    return
  }
  if intentional_reload_in_progress.val {
    // A self-triggered reload (file change -> SSE "reload") is not a real
    // close. The reloaded page re-registers via /session/open on its own.
    close_report_sent.val = true
    return
  }
  close_report_sent.val = true
  let url = location_origin() + "/close"
  let payload = "{\"tabId\":" +
    json_encode_string(review_tab_id.val) +
    ",\"instanceId\":" +
    json_encode_string(page_instance_id.val) +
    ",\"draft\":" +
    json_encode_string(build_review_payload()) +
    "}"
  send_beacon_json(url, payload)
}

///|
fn setup_close_detection(port : Int) -> Unit {
  review_tab_id.val = get_or_create_tab_id()
  page_instance_id.val = create_page_instance_id()
  let open_url = location_origin() + "/session/open"
  let open_payload = "{\"tabId\":" +
    json_encode_string(review_tab_id.val) +
    ",\"instanceId\":" +
    json_encode_string(page_instance_id.val) +
    "}"
  fetch_post_keepalive(open_url, open_payload)
  on_window("pagehide", fn(_e) { report_tab_closed(port) })
  on_window("beforeunload", fn(_e) { report_tab_closed(port) })
}

///|
fn submit_review(_port : Int) -> Unit {
  submit_in_flight.val = true
  close_report_sent.val = true
  let url = location_origin() + "/exit"
  fetch_post(url, build_review_payload(), fn(response) {
    if response.contains("unresolved_comments") {
      submit_in_flight.val = false
      close_report_sent.val = false
      show_toast("Resolve all open threads before approving")
      return
    }
    // Hide the Submit Review dialog explicitly instead of relying solely
    // on the tab itself going away — window_close() is refused by real
    // browsers for tabs they didn't script-open (which is how yunomi opens
    // its review tab), and even the about:blank fallback below has a
    // visible 400ms window before it fires. Without this, a human watching
    // the actual tab sees the dialog just sit there and reads it as
    // "Submit didn't work", even though the request succeeded server-side.
    hide_submit_modal()
    // A submitted request-for-changes is final for this browser tab too.
    // Loop servers remain alive for `yunomi go`, but the human should not
    // be left staring at a completed review or an inert dialog.
    ls_remove(get_storage_key())
    window_close()
    // Browsers refuse window.close() for tabs they consider
    // user-opened; park the survivor on about:blank so it neither
    // looks like a live review nor matches future tab reuse
    ignore(set_timeout(fn() { location_replace("about:blank") }, 400))
  })
}

///|
fn json_encode_string(s : String) -> String {
  "\"" + @core.escape_js_string(s) + "\""
}

///|
/// Theme button shows the mode you would switch TO (moon=to dark, sun=to light)
fn update_theme_button(theme : String) -> Unit {
  let icon = query("#theme-icon")
  if !is_null(icon) {
    set_inner_html(
      icon,
      if theme == "dark" {
        @core.icon_svg_sun
      } else {
        @core.icon_svg_moon
      },
    )
  }
  let label = query("#theme-label")
  if !is_null(label) {
    set_inner_html(label, if theme == "dark" { "Dark" } else { "Light" })
  }
  let btn = query("#theme-toggle")
  if !is_null(btn) {
    set_attribute(
      btn,
      "title",
      if theme == "dark" {
        "Switch to light theme"
      } else {
        "Switch to dark theme"
      },
    )
  }
}

///|
/// Panel state toggle — cli.cjs L7232-7270 initPanelState
fn init_view_toggle() -> Unit {
  let view_toggle = query("#view-toggle")
  let md_layout = query(".md-layout")
  if is_null(view_toggle) || is_null(md_layout) {
    return
  }
  // Load saved state — default is preview-only; show source only when explicitly saved
  let saved = local_storage_get("yunomi-panel-state")
  if saved != "both" {
    add_class(md_layout, "preview-only")
    set_attribute(view_toggle, "title", "Show source panel")
    add_class(view_toggle, "active")
  }
  // Narrow viewport auto-hide
  init_view_toggle_narrow(view_toggle)
  on_window("resize", fn(_e) { init_view_toggle_narrow(view_toggle) })
  // Click handler
  on(view_toggle, "click", fn(_e) {
    let is_now_preview_only = !has_class(md_layout, "preview-only")
    if is_now_preview_only {
      add_class(md_layout, "preview-only")
      set_attribute(view_toggle, "title", "Show source panel")
      add_class(view_toggle, "active")
    } else {
      remove_class(md_layout, "preview-only")
      set_attribute(view_toggle, "title", "Hide source panel")
      remove_class(view_toggle, "active")
    }
    local_storage_set(
      "yunomi-panel-state",
      if is_now_preview_only {
        "preview-only"
      } else {
        "both"
      },
    )
  })
}

///|
/// Hide view toggle on narrow viewports
fn init_view_toggle_narrow(view_toggle : Element) -> Unit {
  if window_inner_width() <= 960 {
    set_style(view_toggle, "display", "none")
  } else {
    set_style(view_toggle, "display", "")
  }
}

///|

///|
/// Enable/disable Submit & Exit button based on SSE connection
fn set_send_buttons_enabled(enabled : Bool) -> Unit {
  let submit_btn = query("#send-and-exit")
  if !is_null(submit_btn) {
    set_disabled(submit_btn, !enabled)
  }
}

///|
/// Update SSE status dot state (connected / reconnecting / sending)
fn set_sse_status(state : String, label : String) -> Unit {
  let status_el = query("#sse-status")
  if is_null(status_el) {
    return
  }
  remove_class(status_el, "sse-dot-connected")
  remove_class(status_el, "sse-dot-reconnecting")
  remove_class(status_el, "sse-dot-sending")
  if state == "connected" {
    add_class(status_el, "sse-dot-connected")
  } else if state == "reconnecting" {
    add_class(status_el, "sse-dot-reconnecting")
  } else if state == "sending" {
    add_class(status_el, "sse-dot-sending")
  }
  set_attribute(status_el, "title", label)
}

///|
/// Track whether SSE was previously connected (to show "Reconnected")
let sse_was_connected : Ref[Bool] = Ref(false)

///|
/// Server instance id from the first SSE hello; a different id on reconnect
/// means a NEW server reused this port. A lingering old tab must not join the
/// new review, otherwise closing one tab can make other stale tabs reappear.
let sse_server_instance : Ref[String] = Ref("")

///|
/// Reply events update the current DOM directly. The server also emits a
/// `round` event for compatibility with older clients/tests; suppress the
/// next round-triggered reload only for that paired reply update.
let suppress_next_round_reload : Ref[Bool] = Ref(false)

///|
fn apply_live_comment_event(data : String) -> Unit {
  let event_type = json_extract_field(data, "type")
  let key_raw = json_extract_field(data, "key")
  let received_row = str_to_int(json_extract_field(data, "row"))
  // CLI locations are user-facing 1-based lines (`file.md:3`), while browser
  // comments and DOM data-row values are 0-based.
  let row = if key_raw.has_prefix("cli-") && received_row > 0 {
    received_row - 1
  } else {
    received_row
  }
  let col = str_to_int(json_extract_field(data, "col"))
  let text = json_extract_field(data, "text")
  let key = if key_raw.length() > 0 {
    key_raw
  } else {
    "live-" + row.to_string() + "-" + col.to_string()
  }
  if event_type == "delete" {
    ignore(comments.remove(key))
  } else if text.length() > 0 {
    match comments.get(key) {
      Some(existing) =>
        comments.set(key, {
          row: if row > 0 {
            row
          } else {
            existing.row
          },
          col: if col > 0 {
            col
          } else {
            existing.col
          },
          text,
          image: existing.image,
          value: existing.value,
          pending: false,
          sent: true,
        })
      None =>
        comments.set(key, {
          row,
          col,
          text,
          image: "",
          value: "",
          pending: false,
          sent: true,
        })
    }
  }
  update_comment_indicators()
  persist_draft()
}

///|
fn setup_sse(_port : Int) -> Unit {
  let url = location_origin() + "/sse"
  let es = new_event_source(url)
  sse_on(es, "reload", fn(_e) {
    intentional_reload_in_progress.val = true
    // intentional_reload_in_progress is an in-memory flag — it dies with
    // this page's JS realm the instant location_reload() actually
    // navigates, so the FRESH page load that follows has no way to know
    // "the recovery modal I'm about to show is for a reload I triggered
    // myself 200ms ago", not a genuinely stale/ambiguous draft. Carry that
    // fact across the reload via localStorage (survives navigation, unlike
    // any in-memory Ref) so check_recovery() on the other side can skip
    // straight to restoring instead of making the human click through a
    // confirmation modal for every single file-change reload — see its
    // comment for why that matters (a busy multi-agent session can trigger
    // several of these reloads in quick succession).
    ls_set(reload_inflight_key(), "1")
    location_reload()
  })
  sse_on(es, "round", fn(e) {
    let data = sse_event_data(e)
    review_loop_unresolved_count.val = render_review_loop_panel_json(data)
    if suppress_next_round_reload.val {
      suppress_next_round_reload.val = false
    } else {
      intentional_reload_in_progress.val = true
      ls_set(reload_inflight_key(), "1")
      location_reload()
    }
  })
  sse_on(es, "reply", fn(e) {
    suppress_next_round_reload.val = true
    apply_comment_reply_event(get_yunomi_filename(), sse_event_data(e))
  })
  sse_on(es, "comment", fn(e) { apply_live_comment_event(sse_event_data(e)) })
  sse_on(es, "send-now", fn(e) { mark_send_now_event(sse_event_data(e)) })
  sse_on(es, "hello", fn(e) {
    let id = sse_event_data(e)
    if sse_server_instance.val == "" {
      sse_server_instance.val = id
    } else if sse_server_instance.val != id {
      report_tab_closed(_port)
      sse_close(es)
      window_close()
      ignore(set_timeout(fn() { location_replace("about:blank") }, 400))
    }
  })
  // SSE connection status tracking
  sse_on_open(es, fn() {
    let label = if sse_was_connected.val { "Reconnected" } else { "Connected" }
    set_sse_status("connected", label)
    sse_was_connected.val = true
    set_send_buttons_enabled(true)
  })
  sse_on_error_status(es, fn() {
    set_sse_status("reconnecting", "Reconnecting...")
    set_send_buttons_enabled(false)
  })
}

///|
/// Save the full in-progress draft (comments + global summary + frontmatter
/// question answers + the questions stepper's current position) to
/// localStorage under one key, in cli.cjs-compatible { comments, timestamp }
/// shape extended with `summary`, `answers`, and `step`. Everything the user
/// can type or navigate mid-review shares this single Restore/Discard flow —
/// before this, only comments survived a reload; question answers, the
/// stepper position, and the summary/decision textarea existed only in the
/// live DOM and vanished on any interruption (reload, crash, tab close).
fn persist_draft() -> Unit {
  let key = get_storage_key()
  let buf = StringBuilder::new()
  buf.write_string("{\"comments\":{")
  let first = Ref(true)
  comments.each(fn(k, comment) {
    if !first.val {
      buf.write_char(',')
    }
    buf.write_string(json_encode_string(k))
    buf.write_string(":{\"row\":")
    buf.write_string(comment.row.to_string())
    buf.write_string(",\"col\":")
    buf.write_string(comment.col.to_string())
    buf.write_string(",\"text\":")
    buf.write_string(json_encode_string(comment.text))
    if comment.value.length() > 0 {
      buf.write_string(",\"value\":")
      buf.write_string(json_encode_string(comment.value))
    }
    buf.write_string(",\"pending\":")
    buf.write_string(if comment.pending { "true" } else { "false" })
    buf.write_string(",\"sent\":")
    buf.write_string(if comment.sent { "true" } else { "false" })
    buf.write_char('}')
    first.val = false
  })
  buf.write_string("},\"summary\":")
  let summary_el = query("#global-comment")
  let summary = if is_null(summary_el) { "" } else { get_value(summary_el) }
  buf.write_string(json_encode_string(summary))
  buf.write_string(",\"answers\":")
  buf.write_string(collect_yunomi_draft_answers())
  buf.write_string(",\"step\":")
  buf.write_string(question_step_index.val.to_string())
  let comment_open = inline_comment_editor_open() && active_key.val.length() > 0
  let active_comment = comments.get(active_key.val)
  let active_row = match active_comment {
    Some(comment) => comment.row
    None => 0
  }
  let active_col = match active_comment {
    Some(comment) => comment.col
    None => 0
  }
  let submit = query("#submit-modal")
  let submit_open = !is_null(submit) && has_class(submit, "visible")
  buf.write_string(",\"ui\":{\"comment_open\":")
  buf.write_string(if comment_open { "true" } else { "false" })
  buf.write_string(",\"active_key\":")
  buf.write_string(json_encode_string(active_key.val))
  buf.write_string(",\"active_row\":")
  buf.write_string(active_row.to_string())
  buf.write_string(",\"active_col\":")
  buf.write_string(active_col.to_string())
  buf.write_string(",\"submit_open\":")
  buf.write_string(if submit_open { "true" } else { "false" })
  buf.write_char('}')
  buf.write_string(",\"timestamp\":")
  buf.write_string(date_now_string())
  buf.write_char('}')
  ls_set(key, buf.to_string())
}

///|
/// Toggle history panel
fn toggle_history_panel() -> Unit {
  let panel = query("#history-panel")
  if is_null(panel) {
    return
  }
  let body = query("body")
  let is_open = get_attr(panel, "class").contains("open")
  if is_open {
    remove_class(panel, "open")
    if !is_null(body) {
      remove_class(body, "history-open")
    }
  } else {
    add_class(panel, "open")
    if !is_null(body) {
      add_class(body, "history-open")
    }
    load_history_data()
  }
}

///|
/// Load history data from server
fn load_history_data() -> Unit {
  let _port = get_yunomi_port()
  let url = location_origin() + "/history"
  fetch_get(url, fn(data) {
    let panel_body = query("#history-panel-body")
    if !is_null(panel_body) {
      if data.length() <= 2 {
        set_inner_html(
          panel_body, "<div style=\"color:var(--text-dim);padding:16px;text-align:center\">No history yet</div>",
        )
      } else {
        let buf = StringBuilder::new()
        buf.write_string(
          "<ul class=\"history-entries\" style=\"list-style:none;padding:0;margin:0\">",
        )
        buf.write_string(render_history_entries(data))
        buf.write_string("</ul>")
        set_inner_html(panel_body, buf.to_string())
      }
    }
  })
}

///|
/// Render history entries from JSON array to HTML list items
fn render_history_entries(json : String) -> String {
  let buf = StringBuilder::new()
  let entries = split_json_array(json)
  for entry in entries {
    let ts = json_extract_field(entry, "timestamp")
    let file = json_extract_field(entry, "file")
    let summary = json_extract_field(entry, "summary")
    let count = json_extract_field(entry, "commentCount")
    buf.write_string(
      "<li class=\"history-entry\" style=\"padding:12px 16px;border-bottom:1px solid var(--border)\">",
    )
    buf.write_string("<div style=\"font-size:12px;color:var(--text-dim)\">")
    buf.write_string(@core.escape_html(ts))
    buf.write_string("</div>")
    buf.write_string("<div style=\"font-weight:600;margin:4px 0\">")
    buf.write_string(@core.escape_html(file))
    buf.write_string("</div>")
    if summary.length() > 0 {
      buf.write_string("<div style=\"font-size:13px;color:var(--text-dim)\">")
      buf.write_string(@core.escape_html(summary))
      buf.write_string("</div>")
    }
    if count.length() > 0 {
      buf.write_string("<div style=\"font-size:12px;color:var(--accent)\">")
      buf.write_string(@core.escape_html(count))
      buf.write_string(" comments</div>")
    }
    buf.write_string("</li>")
  }
  buf.to_string()
}

///|
/// Split a JSON array string into individual object strings
fn split_json_array(json : String) -> Array[String] {
  let result : Array[String] = []
  let chars = json.to_array()
  let len = chars.length()
  let mut depth = 0
  let mut start = -1
  let mut in_string = false
  let mut i = 0
  while i < len {
    let ch = chars[i]
    if in_string {
      if ch == '\\' {
        i = i + 2 // skip escaped char
        continue
      }
      if ch == '"' {
        in_string = false
      }
      i = i + 1
      continue
    }
    match ch {
      '"' => in_string = true
      '{' => {
        if depth == 0 {
          start = i
        }
        depth = depth + 1
      }
      '}' => {
        depth = depth - 1
        if depth == 0 && start >= 0 {
          result.push(@core.safe_slice_range(json, start, i + 1))
          start = -1
        }
      }
      _ => ()
    }
    i = i + 1
  }
  result
}

///|
/// Extract a field value from a JSON object string
fn json_extract_field(json : String, field : String) -> String {
  let key = "\"" + field + "\""
  let chars = json.to_array()
  let len = chars.length()
  let key_chars = key.to_array()
  let key_len = key_chars.length()
  let mut i = 0
  while i + key_len < len {
    let mut match_ = true
    for k = 0; k < key_len; k = k + 1 {
      if chars[i + k] != key_chars[k] {
        match_ = false
        break
      }
    }
    if match_ {
      let mut j = i + key_len
      while j < len && (chars[j] == ':' || chars[j] == ' ') {
        j = j + 1
      }
      if j < len {
        if chars[j] == '"' {
          let val_start = j + 1
          let mut val_end = val_start
          while val_end < len && chars[val_end] != '"' {
            if chars[val_end] == '\\' {
              val_end = val_end + 1
            }
            val_end = val_end + 1
          }
          return @core.safe_slice_range(json, val_start, val_end)
        } else {
          let val_start = j
          let mut val_end = j
          while val_end < len && chars[val_end] != ',' && chars[val_end] != '}' {
            val_end = val_end + 1
          }
          return @core.safe_slice_range(json, val_start, val_end)
        }
      }
    }
    i = i + 1
  }
  ""
}

///|
/// Setup paste handler for image attachment
fn setup_paste_handler() -> Unit {
  on_paste_image(fn(base64) {
    let submit_modal = query("#submit-modal")
    let submit_visible = !is_null(submit_modal) &&
      (
        get_attr(submit_modal, "class").contains("visible") ||
        get_computed_style(submit_modal, "display") != "none"
      )
    let comment_visible = inline_comment_editor_open()
    if submit_visible {
      if submit_images.length() < submit_image_limit {
        submit_images.push(base64)
        render_submit_image_preview()
      }
    } else if comment_visible {
      if current_comment_image.val.length() == 0 {
        current_comment_image.val = base64
        render_comment_image_preview()
      }
    }
  })
}

///|
/// Render submit image preview
fn render_submit_image_preview() -> Unit {
  let container = query("#submit-image-preview")
  if is_null(container) {
    return
  }
  // Show attached/limit so the user never has to count thumbnails
  let label = query("#submit-image-label")
  if !is_null(label) {
    set_text_content(
      label,
      "Attach images (Paste, " +
      submit_images.length().to_string() +
      "/" +
      submit_image_limit.to_string() +
      ")",
    )
  }
  let buf = StringBuilder::new()
  for i, img in submit_images {
    buf.write_string(
      "<div class=\"image-preview-item\" style=\"position:relative;display:inline-block;margin:4px\"><img src=\"",
    )
    buf.write_string(img)
    buf.write_string(
      "\" alt=\"attached\" style=\"max-width:60px;max-height:60px;border-radius:4px\"><button class=\"remove-image\" data-idx=\"",
    )
    buf.write_string(i.to_string())
    buf.write_string(
      "\" style=\"position:absolute;top:-4px;right:-4px;background:var(--accent);color:#fff;border:none;border-radius:50%;width:16px;height:16px;cursor:pointer;font-size:10px;line-height:16px;text-align:center\">\u{00D7}</button></div>",
    )
  }
  set_inner_html(container, buf.to_string())
  let remove_btns = query_all(".remove-image")
  for btn in remove_btns {
    on(btn, "click", fn(e) {
      let target = event_target(e)
      let idx_str = get_attr(target, "data-idx")
      let idx = str_to_int(idx_str)
      if idx >= 0 && idx < submit_images.length() {
        ignore(submit_images.remove(idx))
        render_submit_image_preview()
      }
    })
  }
}

///|
/// Render comment image preview
fn render_comment_image_preview() -> Unit {
  let container = query("#comment-image-preview")
  if is_null(container) {
    return
  }
  if current_comment_image.val.length() == 0 {
    set_inner_html(container, "")
    return
  }
  let buf = StringBuilder::new()
  buf.write_string(
    "<div class=\"image-preview-item\" style=\"position:relative;display:inline-block;margin:4px\"><img src=\"",
  )
  buf.write_string(current_comment_image.val)
  buf.write_string(
    "\" alt=\"attached\" style=\"max-width:60px;max-height:60px;border-radius:4px\"><button id=\"remove-comment-image\" style=\"position:absolute;top:-4px;right:-4px;background:var(--accent);color:#fff;border:none;border-radius:50%;width:16px;height:16px;cursor:pointer;font-size:10px;line-height:16px;text-align:center\">\u{00D7}</button></div>",
  )
  set_inner_html(container, buf.to_string())
  let remove_btn = query("#remove-comment-image")
  if !is_null(remove_btn) {
    on(remove_btn, "click", fn(_e) {
      current_comment_image.val = ""
      render_comment_image_preview()
    })
  }
}

///|
/// Scroll sync for markdown split view
fn setup_scroll_sync() -> Unit {
  let md_left = query(".md-left")
  let md_right = query(".md-right")
  if is_null(md_left) || is_null(md_right) {
    return
  }
  // Preview (md-left) is the primary scroll axis.
  // Only Preview→Source sync is active. Source→Preview is disabled
  // to prevent the sync from fighting the user's scroll in Preview.
  on(md_left, "scroll", fn(_e) { sync_scroll(md_left, md_right, "left") })
  // Invalidate heading anchor cache when images load (layout shift)
  let preview_imgs = query_all_in(md_left, "img")
  for img in preview_imgs {
    on(img, "load", fn(_e) { invalidate_heading_anchors() })
  }
}

///|
/// Invalidate heading anchors cache so it rebuilds on next scroll
fn invalidate_heading_anchors() -> Unit {
  heading_anchors_built.val = false
  while heading_anchors_cache.length() > 0 {
    ignore(heading_anchors_cache.pop())
  }
}

///|
/// Heading anchor for scroll sync
struct HeadingAnchor {
  line : Int // 0-indexed source line
  preview_el : Element
}

///|
/// Build heading anchors map for scroll sync
fn build_heading_anchors() -> Array[HeadingAnchor] {
  let anchors : Array[HeadingAnchor] = []
  let preview = query("#md-preview")
  if is_null(preview) {
    return anchors
  }
  let headings = query_all_in(preview, "h1, h2, h3, h4, h5, h6")
  let data = js_get_data()
  for h in headings {
    let text = normalize_text(get_text_content(h))
    let stripped = strip_markdown(text)
    for i, row in data {
      if row.length() > 0 {
        let src = row[0]
        if src.has_prefix("#") {
          let src_stripped = strip_markdown(src)
          if src_stripped == stripped {
            anchors.push({ line: i, preview_el: h })
            break
          }
        }
      }
    }
  }
  anchors
}

///|
/// Cached heading anchors
let heading_anchors_cache : Array[HeadingAnchor] = []

///|
let heading_anchors_built : Ref[Bool] = Ref(false)

///|
/// Get or build heading anchors
fn get_heading_anchors() -> Array[HeadingAnchor] {
  if !heading_anchors_built.val {
    let anchors = build_heading_anchors()
    for a in anchors {
      heading_anchors_cache.push(a)
    }
    heading_anchors_built.val = true
  }
  heading_anchors_cache
}

///| Apply scroll position with delta limiting to prevent jumps

///| When images load and shift layout, raw set_scroll_top causes large jumps.

///|
/// This limits per-frame delta to viewport height, producing smoother sync.
fn apply_scroll_clamped(
  target : Element,
  desired : Double,
  target_max : Double,
) -> Unit {
  let current = get_scroll_top(target)
  let clamped = if desired < 0.0 {
    0.0
  } else if desired > target_max {
    target_max
  } else {
    desired
  }
  let delta = clamped - current
  let viewport_h = get_client_height(target)
  // Limit jump to 1x viewport height per frame to avoid jarring snaps
  let max_delta = if viewport_h > 100.0 { viewport_h } else { 400.0 }
  if delta.abs() > max_delta {
    let limited = current + (if delta > 0.0 { max_delta } else { -max_delta })
    set_scroll_top(target, limited)
  } else {
    set_scroll_top(target, clamped)
  }
}

///|
fn sync_scroll(
  source : Element,
  target : Element,
  source_name : String,
) -> Unit {
  if date_now() < scroll_sync_disabled_until.val {
    return
  }
  if scroll_active_pane.val.length() > 0 &&
    scroll_active_pane.val != source_name {
    return
  }
  scroll_active_pane.val = source_name
  if scroll_sync_raf.val != 0 {
    cancel_animation_frame(scroll_sync_raf.val)
  }
  scroll_sync_raf.val = request_animation_frame(fn() {
    if date_now() < scroll_sync_disabled_until.val {
      return
    }
    let source_max = get_scroll_height(source) - get_client_height(source)
    let target_max = get_scroll_height(target) - get_client_height(target)
    if source_max <= 0.0 || target_max <= 0.0 {
      return
    }
    // Edge snap: top
    if get_scroll_top(source) <= 1.0 {
      set_scroll_top(target, 0.0)
      ignore(set_timeout(fn() { scroll_active_pane.val = "" }, 100))
      return
    }
    // Edge snap: bottom
    if get_scroll_top(source) >= source_max - 1.0 {
      set_scroll_top(target, target_max)
      ignore(set_timeout(fn() { scroll_active_pane.val = "" }, 100))
      return
    }
    // Heading-based sync: find closest heading anchor to viewport midpoint
    let anchors = get_heading_anchors()
    if anchors.length() >= 2 {
      let source_scroll = get_scroll_top(source)
      let source_height = get_client_height(source)
      let source_mid = source_scroll + source_height / 2.0
      // Find closest anchor in source
      let mut best_idx = 0
      let mut best_dist = 99999999.0
      for i, anchor in anchors {
        // Get position of this anchor in the source pane
        let src_pos = if source_name == "left" {
          // Source is preview (md-left), find preview element position
          get_offset_top(anchor.preview_el)
        } else {
          // Source is source table (md-right), find source row position
          let cell = query(
            "td[data-row=\"\{anchor.line}\"][data-col=\"1\"]:not(#md-preview *)",
          )
          if !is_null(cell) {
            get_offset_top(cell)
          } else {
            0.0
          }
        }
        let dist = (src_pos - source_mid).abs()
        if dist < best_dist {
          best_dist = dist
          best_idx = i
        }
      }
      // Get corresponding position in target
      let anchor = anchors[best_idx]
      let src_anchor_pos = if source_name == "left" {
        get_offset_top(anchor.preview_el)
      } else {
        let cell = query(
          "td[data-row=\"\{anchor.line}\"][data-col=\"1\"]:not(#md-preview *)",
        )
        if !is_null(cell) {
          get_offset_top(cell)
        } else {
          0.0
        }
      }
      let tgt_anchor_pos = if source_name == "left" {
        let cell = query(
          "td[data-row=\"\{anchor.line}\"][data-col=\"1\"]:not(#md-preview *)",
        )
        if !is_null(cell) {
          get_offset_top(cell)
        } else {
          0.0
        }
      } else {
        get_offset_top(anchor.preview_el)
      }
      let offset_in_source = source_scroll - src_anchor_pos
      let ratio_in_section = if source_max > 0.0 {
        offset_in_source / source_height
      } else {
        0.0
      }
      let target_scroll = tgt_anchor_pos +
        ratio_in_section * get_client_height(target)
      apply_scroll_clamped(target, target_scroll, target_max)
      ignore(set_timeout(fn() { scroll_active_pane.val = "" }, 100))
      return
    }
    // Fallback: Ratio-based sync
    let ratio = get_scroll_top(source) / source_max
    apply_scroll_clamped(target, ratio * target_max, target_max)
    ignore(set_timeout(fn() { scroll_active_pane.val = "" }, 100))
  })
}

///|
/// Drag selection: begin
fn begin_drag(row : Int) -> Unit {
  is_dragging.val = true
  add_class_body("dragging")
  drag_start_row.val = row
  drag_end_row.val = row
  update_selection_highlight()
}

///|
/// Drag selection: update during mouse move
fn update_drag(row : Int) -> Unit {
  if !is_dragging.val {
    return
  }
  if row == drag_end_row.val {
    return
  }
  drag_end_row.val = row
  update_selection_highlight()
}

///|
/// Drag selection: finish and open an inline comment editor
fn finish_drag() -> Unit {
  if !is_dragging.val {
    return
  }
  is_dragging.val = false
  remove_class_body("dragging")
  let start = if drag_start_row.val < drag_end_row.val {
    drag_start_row.val
  } else {
    drag_end_row.val
  }
  let end = if drag_start_row.val > drag_end_row.val {
    drag_start_row.val
  } else {
    drag_end_row.val
  }
  let key = if start == end {
    start.to_string() + ":0"
  } else {
    start.to_string() + "-" + end.to_string()
  }
  let target_el = query(
    "[data-row=\"" + start.to_string() + "\"]:not(#md-preview *)",
  )
  if !is_null(target_el) {
    show_inline_comment(target_el, key, start, 0)
  }
}

///|
/// Update visual highlight for selected rows
fn update_selection_highlight() -> Unit {
  let old_selected = query_all(".selected")
  for el in old_selected {
    remove_class(el, "selected")
  }
  if !is_dragging.val {
    return
  }
  let start = if drag_start_row.val < drag_end_row.val {
    drag_start_row.val
  } else {
    drag_end_row.val
  }
  let end = if drag_start_row.val > drag_end_row.val {
    drag_start_row.val
  } else {
    drag_end_row.val
  }
  for r = start; r <= end; r = r + 1 {
    let el = query("[data-row=\"" + r.to_string() + "\"]:not(#md-preview *)")
    if !is_null(el) {
      add_class(el, "selected")
    }
  }
}

///|
/// Setup global mouse handlers for drag selection
fn setup_drag_handlers() -> Unit {
  on_window("mousemove", fn(e) {
    if !is_dragging.val {
      return
    }
    let x = get_event_client_x(e)
    let y = get_event_client_y(e)
    let el = element_from_point(x, y)
    if !is_null(el) {
      let row_el = closest(el, "[data-row]:not(#md-preview *)")
      if !is_null(row_el) {
        let row_str = get_attr(row_el, "data-row")
        update_drag(str_to_int(row_str))
      }
    }
  })
  on_window("mouseup", fn(_e) { if is_dragging.val { finish_drag() } })
}

///|
/// Setup video timeline for a video element
fn _setup_video_timeline(video_path : String) -> Unit {
  let container = query("#video-timeline")
  if is_null(container) {
    return
  }
  let _port = get_yunomi_port()
  let url = location_origin() + "/video-timeline?path=" + video_path
  let es = new_event_source_url(url)
  sse_on_message(es, fn(data) {
    if data.contains("\"type\":\"thumbnail\"") {
      // Extract data URL from JSON
      let marker = "\"data\":\""
      let data_start = find_substring(data, marker)
      if data_start >= 0 {
        let value_start = data_start + marker.length()
        let value_end = find_char_from(data, '"', value_start)
        if value_end > value_start {
          let src = @core.safe_slice_range(data, value_start, value_end)
          let time_marker = "\"time\":"
          let time_start = find_substring(data, time_marker)
          let time_str = if time_start >= 0 {
            let ts = time_start + time_marker.length()
            let te = find_char_from(data, ',', ts)
            if te > ts {
              @core.safe_slice_range(data, ts, te)
            } else {
              "0"
            }
          } else {
            "0"
          }
          create_timeline_thumb(container, src, time_str)
        }
      }
    }
    if data.contains("\"type\":\"complete\"") {
      sse_close(es)
    }
  })
}

///|
/// Find substring index in string, returns -1 if not found
fn find_substring(haystack : String, needle : String) -> Int {
  let h = haystack.to_array()
  let n = needle.to_array()
  let hlen = h.length()
  let nlen = n.length()
  if nlen == 0 || nlen > hlen {
    return -1
  }
  for i in 0..<=(hlen - nlen) {
    let mut match_ = true
    for j in 0..<nlen {
      if h[i + j] != n[j] {
        match_ = false
        break
      }
    }
    if match_ {
      return i
    }
  }
  -1
}

///|
/// Find char from a given start position, returns -1 if not found
fn find_char_from(s : String, target : Char, start : Int) -> Int {
  let chars = s.to_array()
  for i in start..<chars.length() {
    if chars[i] == target {
      return i
    }
  }
  -1
}

// ===== Preview-to-source line mapping (cli.cjs compatible) =====

///|
/// Normalize text for comparison: collapse whitespace, trim
fn normalize_text(s : String) -> String {
  let chars = s.to_array()
  let buf = StringBuilder::new()
  let mut prev_space = true
  for ch in chars {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if !prev_space {
        buf.write_char(' ')
        prev_space = true
      }
    } else {
      buf.write_char(ch)
      prev_space = false
    }
  }
  let result = buf.to_string()
  // Trim trailing space
  let rchars = result.to_array()
  if rchars.length() > 0 && rchars[rchars.length() - 1] == ' ' {
    @core.safe_slice_range(result, 0, rchars.length() - 1)
  } else {
    result
  }
}

///|
/// Strip markdown formatting from text for comparison
fn strip_markdown(s : String) -> String {
  let chars = s.to_array()
  let buf = StringBuilder::new()
  let len = chars.length()
  let mut i = 0
  let mut at_line_start = true
  while i < len {
    if at_line_start {
      while i < len && chars[i] == ' ' {
        i = i + 1
      }
      while i < len && chars[i] == '>' {
        i = i + 1
        while i < len && chars[i] == ' ' {
          i = i + 1
        }
      }
      if i + 1 < len &&
        (chars[i] == '-' || chars[i] == '*' || chars[i] == '+') &&
        chars[i + 1] == ' ' {
        i = i + 2
      } else {
        let mut j = i
        while j < len && chars[j] >= '0' && chars[j] <= '9' {
          j = j + 1
        }
        if j > i &&
          j + 1 < len &&
          (chars[j] == '.' || chars[j] == ')') &&
          chars[j + 1] == ' ' {
          i = j + 2
        }
      }
      at_line_start = false
      if i >= len {
        break
      }
    }
    // Skip leading # for headings
    if i == 0 && chars[i] == '#' {
      while i < len && chars[i] == '#' {
        i = i + 1
      }
      if i < len && chars[i] == ' ' {
        i = i + 1
      }
      continue
    }
    // Skip ** (bold)
    if i + 1 < len && chars[i] == '*' && chars[i + 1] == '*' {
      i = i + 2
      continue
    }
    // Skip * (italic) — only if not **
    if chars[i] == '*' {
      i = i + 1
      continue
    }
    // Skip ` (inline code)
    if chars[i] == '`' {
      i = i + 1
      continue
    }
    // Skip toggle icons
    if chars[i] == '\u{25BC}' ||
      chars[i] == '\u{25B6}' ||
      chars[i] == '\u{25C0}' ||
      chars[i] == '\u{25BA}' ||
      chars[i] == '\u{25C6}' ||
      chars[i] == '\u{25C7}' {
      i = i + 1
      continue
    }
    buf.write_char(chars[i])
    at_line_start = chars[i] == '\n' || chars[i] == '\r'
    i = i + 1
  }
  normalize_text(buf.to_string())
}

///|
/// Find closest heading above the given element in the preview DOM
fn find_closest_heading_above(el : Element) -> Element {
  // Walk up and back through siblings to find nearest heading
  let mut current = el
  while !is_null(current) {
    let tag = get_tag_name(current)
    if tag == "H1" ||
      tag == "H2" ||
      tag == "H3" ||
      tag == "H4" ||
      tag == "H5" ||
      tag == "H6" {
      return current
    }
    // Check previous siblings
    let mut sib = previous_element_sibling(current)
    while !is_null(sib) {
      let sib_tag = get_tag_name(sib)
      if sib_tag == "H1" ||
        sib_tag == "H2" ||
        sib_tag == "H3" ||
        sib_tag == "H4" ||
        sib_tag == "H5" ||
        sib_tag == "H6" {
        return sib
      }
      sib = previous_element_sibling(sib)
    }
    current = parent_element(current)
  }
  // Return null element (is_null will be true)
  current
}

///|
/// Get the source line number for a heading element (0-indexed, returns -1 if not found)
fn get_heading_source_line(heading_el : Element) -> Int {
  if is_null(heading_el) {
    return -1
  }
  let text = normalize_text(get_text_content(heading_el))
  // Strip toggle icon characters
  let cleaned = strip_markdown(text)
  let data = js_get_data()
  for i, row in data {
    if row.length() > 0 {
      let src_line = row[0]
      // Check if source line is a heading
      if src_line.has_prefix("#") {
        let stripped_src = strip_markdown(src_line)
        if stripped_src == cleaned {
          return i
        }
      }
    }
  }
  -1
}

///|
/// Find source line matching text, starting from start_from (1-indexed result, -1 if not found)
fn find_source_line(text : String, _element : Element, start_from : Int) -> Int {
  let data = js_get_data()
  let search_text = normalize_preview_search_text(text)
  if search_text.length() == 0 {
    return -1
  }
  let start = if start_from >= 0 { start_from } else { 0 }
  let allow_contains = search_text.length() >= 8
  let mut fuzzy_match = -1
  for i = start; i < data.length(); i = i + 1 {
    if data[i].length() > 0 {
      if preview_source_line_matches(data[i][0], search_text, false) {
        return i + 1 // 1-indexed
      }
      if allow_contains &&
        fuzzy_match < 0 &&
        preview_source_line_matches(data[i][0], search_text, true) {
        fuzzy_match = i + 1
      }
    }
  }
  if start > 0 {
    for i = 0; i < start; i = i + 1 {
      if data[i].length() > 0 {
        if preview_source_line_matches(data[i][0], search_text, false) {
          return i + 1
        }
        if allow_contains &&
          fuzzy_match < 0 &&
          preview_source_line_matches(data[i][0], search_text, true) {
          fuzzy_match = i + 1
        }
      }
    }
  }
  fuzzy_match
}

///|
/// Find source line for table cell
fn find_table_source_line(text : String, start_from : Int) -> Int {
  let data = js_get_data()
  let search = normalize_preview_search_text(text)
  if search.length() == 0 {
    return -1
  }
  let start = if start_from >= 0 { start_from } else { 0 }
  let allow_contains = search.length() >= 8
  let mut fuzzy_match = -1
  for i = start; i < data.length(); i = i + 1 {
    if data[i].length() > 0 {
      let src = data[i][0]
      if src.contains("|") && preview_table_line_matches(src, search, false) {
        return i + 1
      }
      if allow_contains &&
        fuzzy_match < 0 &&
        src.contains("|") &&
        preview_table_line_matches(src, search, true) {
        fuzzy_match = i + 1
      }
    }
  }
  if start > 0 {
    for i = 0; i < start; i = i + 1 {
      if data[i].length() > 0 {
        let src = data[i][0]
        if src.contains("|") && preview_table_line_matches(src, search, false) {
          return i + 1
        }
        if allow_contains &&
          fuzzy_match < 0 &&
          src.contains("|") &&
          preview_table_line_matches(src, search, true) {
          fuzzy_match = i + 1
        }
      }
    }
  }
  fuzzy_match
}

///|
/// Find code block range in source (returns (start_line_1indexed, end_line_1indexed))
fn find_code_block_range(code_text : String) -> (Int, Int) {
  let data = js_get_data()
  let search = normalize_text(code_text)
  let mut i = 0
  while i < data.length() {
    if data[i].length() > 0 && data[i][0].has_prefix("\u{0060}\u{0060}\u{0060}") {
      let block_start = i
      i = i + 1
      // Collect code block content
      let code_buf = StringBuilder::new()
      while i < data.length() {
        if data[i].length() > 0 &&
          data[i][0].has_prefix("\u{0060}\u{0060}\u{0060}") {
          break
        }
        if code_buf.to_string().length() > 0 {
          code_buf.write_string("\n")
        }
        if data[i].length() > 0 {
          code_buf.write_string(data[i][0])
        }
        i = i + 1
      }
      let block_end = i
      let block_text = normalize_text(code_buf.to_string())
      if block_text.contains(search) || search.contains(block_text) {
        return (block_start + 1, block_end + 1) // 1-indexed
      }
      i = i + 1
      continue
    }
    i = i + 1
  }
  (-1, -1)
}

///|
fn get_mermaid_source_range(target : Element) -> (Int, Int) {
  let container = closest(target, ".mermaid-container")
  if is_null(container) {
    return (-1, -1)
  }
  let start_line = str_to_int(get_attr(container, "data-source-start-line"))
  let end_line = str_to_int(get_attr(container, "data-source-end-line"))
  if start_line > 0 {
    let actual_end = if end_line >= start_line { end_line } else { start_line }
    (start_line, actual_end)
  } else {
    (-1, -1)
  }
}

///|
/// Find image source line by src attribute
fn find_image_source_line(src : String, start_from : Int) -> Int {
  let data = js_get_data()
  // Extract filename from src
  let filename = extract_filename(src)
  let start = if start_from >= 0 { start_from } else { 0 }
  // Search from start_from
  for i = start; i < data.length(); i = i + 1 {
    if data[i].length() > 0 {
      let line = data[i][0]
      if line.contains(filename) || line.contains(src) {
        return i + 1
      }
    }
  }
  // Search from beginning
  if start > 0 {
    for i = 0; i < start; i = i + 1 {
      if data[i].length() > 0 {
        let line = data[i][0]
        if line.contains(filename) || line.contains(src) {
          return i + 1
        }
      }
    }
  }
  -1
}

///|
/// Extract filename from path/URL
fn extract_filename(path : String) -> String {
  let chars = path.to_array()
  let mut last_slash = -1
  for i, ch in chars {
    if ch == '/' || ch == '\\' {
      last_slash = i
    }
  }
  if last_slash >= 0 {
    @core.safe_slice(path, last_slash + 1)
  } else {
    path
  }
}

///|
fn normalize_preview_search_text(text : String) -> String {
  strip_markdown(normalize_text(text))
}

///|
fn preview_source_line_matches(
  src : String,
  search : String,
  allow_contains : Bool,
) -> Bool {
  let normalized_src = normalize_preview_search_text(src)
  if normalized_src.length() == 0 || search.length() == 0 {
    return false
  }
  if normalized_src == search {
    return true
  }
  if !allow_contains || search.length() < 8 {
    return false
  }
  normalized_src.contains(search) || search.contains(normalized_src)
}

///|
fn split_table_cells(line : String) -> Array[String] {
  let cells : Array[String] = []
  let normalized = normalize_text(line)
  let inner = if normalized.has_prefix("|") {
    @core.safe_slice(normalized, 1)
  } else {
    normalized
  }
  let trimmed = if inner.has_suffix("|") {
    @core.safe_slice_range(inner, 0, inner.length() - 1)
  } else {
    inner
  }
  for part in trimmed.split("|") {
    let cell = normalize_text(part.to_owned())
    if cell.length() > 0 {
      cells.push(cell)
    }
  }
  cells
}

///|
fn preview_table_line_matches(
  src : String,
  search : String,
  allow_contains : Bool,
) -> Bool {
  let normalized_src = normalize_preview_search_text(src)
  if normalized_src == search {
    return true
  }
  let cells = split_table_cells(src)
  for cell in cells {
    if normalize_preview_search_text(cell) == search {
      return true
    }
  }
  if !allow_contains || search.length() < 8 {
    return false
  }
  if normalized_src.contains(search) || search.contains(normalized_src) {
    return true
  }
  for cell in cells {
    let normalized_cell = normalize_preview_search_text(cell)
    if normalized_cell.contains(search) || search.contains(normalized_cell) {
      return true
    }
  }
  false
}

///|
fn find_media_source_line_in_block(block : Element, start_from : Int) -> Int {
  if is_null(block) {
    return -1
  }
  let image = query_in(block, "img")
  if !is_null(image) {
    let line = find_image_source_line(get_src(image), start_from)
    if line > 0 {
      return line
    }
  }
  let video = query_in(block, "video.video-preview")
  if !is_null(video) {
    let line = find_image_source_line(get_attr(video, "src"), start_from)
    if line > 0 {
      return line
    }
  }
  -1
}

///|
fn resolve_preview_media_anchor(block : Element) -> Element {
  if is_null(block) {
    return block
  }
  let image = query_in(block, "img")
  if !is_null(image) {
    return image
  }
  let video = query_in(block, "video.video-preview")
  if !is_null(video) {
    return video
  }
  let mermaid = query_in(block, ".mermaid-container")
  if !is_null(mermaid) {
    return mermaid
  }
  block
}

///|
fn resolve_preview_block_text(block : Element) -> String {
  if is_null(block) {
    return ""
  }
  let text = normalize_text(get_text_content_without_comment_buttons(block))
  if text.length() > 0 {
    return text
  }
  let image = query_in(block, "img")
  if !is_null(image) {
    let alt = get_attr(image, "alt")
    if alt.length() > 0 {
      return alt
    }
  }
  let video = query_in(block, "video.video-preview")
  if !is_null(video) {
    let title = get_attr(video, "title")
    if title.length() > 0 {
      return title
    }
  }
  ""
}

///|
fn resolve_preview_click_block(target : Element) -> Element {
  if is_null(target) {
    return target
  }
  let block = closest(
    target, "summary, td, th, blockquote, li, p, h1, h2, h3, h4, h5, h6",
  )
  normalize_preview_block_target(block)
}

///|
fn normalize_preview_block_target(block : Element) -> Element {
  if is_null(block) {
    return block
  }
  let tag = get_tag_name(block)
  if tag == "P" {
    let quote = closest(block, "blockquote")
    if !is_null(quote) {
      return quote
    }
    let list_item = closest(block, "li")
    if !is_null(list_item) {
      return list_item
    }
  }
  block
}

///|

///|
/// Select a source range and open its inline editor.
fn select_source_range(
  start_row : Int,
  end_row : Int,
  preview_el : Element,
  col? : Int = 0,
) -> Unit {
  if fullscreen_overlay_visible() {
    return
  }
  // Disable scroll sync for 2 seconds
  scroll_sync_disabled_until.val = date_now() + 2000.0
  // Cancel pending RAF
  if scroll_sync_raf.val != 0 {
    cancel_animation_frame(scroll_sync_raf.val)
    scroll_sync_raf.val = 0
  }
  // Update visual selection on source table
  let actual_end = if end_row > 0 { end_row } else { start_row }
  let old_selected = query_all(".selected")
  for el in old_selected {
    remove_class(el, "selected")
  }
  // Remove old preview highlight
  let old_highlights = query_all(".preview-highlight")
  for el in old_highlights {
    remove_class(el, "preview-highlight")
  }
  // Add preview highlight to clicked element
  if !is_null(preview_el) {
    add_class(preview_el, "preview-highlight")
  }
  // Highlight source rows
  for r = start_row; r <= actual_end; r = r + 1 {
    let row_idx = r - 1 // Convert 1-indexed to 0-indexed data-row
    let cell = query(
      "td[data-row=\"\{row_idx}\"][data-col=\"1\"]:not(#md-preview *)",
    )
    if !is_null(cell) {
      add_class(cell, "selected")
    }
  }
  // Scroll source pane to target row
  let md_right = query(".md-right")
  if !is_null(md_right) {
    let target_row = start_row - 1
    let target_cell = query(
      "td[data-row=\"\{target_row}\"][data-col=\"1\"]:not(#md-preview *)",
    )
    if !is_null(target_cell) {
      let cell_top = get_offset_top(target_cell)
      let container_height = get_client_height(md_right)
      let scroll_target = cell_top - container_height / 2.0
      scroll_to_instant(
        md_right,
        if scroll_target > 0.0 {
          scroll_target
        } else {
          0.0
        },
      )
    }
  }
  // Open the editor directly below the clicked preview block. Source-only
  // modes use their source row as the anchor.
  let anchor_tag = get_tag_name(preview_el).to_lower()
  let needs_tag_key = col == 0 &&
    (
      anchor_tag == "ul" ||
      anchor_tag == "ol" ||
      anchor_tag == "table" ||
      anchor_tag == "tr" ||
      anchor_tag == "details" ||
      anchor_tag == "video" ||
      (anchor_tag == "div" && has_class(preview_el, "markdown-html-block"))
    )
  let key = if start_row == actual_end {
    let base = (start_row - 1).to_string() + ":" + col.to_string()
    if needs_tag_key {
      base + ":" + anchor_tag
    } else {
      base
    }
  } else {
    (start_row - 1).to_string() + "-" + (actual_end - 1).to_string()
  }
  selected_comment_row.val = start_row - 1
  selected_comment_col.val = col
  selected_comment_el.val = preview_el
  let target = if !is_null(preview_el) {
    preview_el
  } else {
    query(
      "td[data-row=\"\{start_row - 1}\"][data-col=\"1\"]:not(#md-preview *)",
    )
  }
  if !is_null(target) {
    open_inline_comment_editor(target, key, start_row - 1, col)
  }
  // Re-enable scroll sync after 500ms
  ignore(
    set_timeout(
      fn() {
        scroll_sync_disabled_until.val = 0.0
        scroll_active_pane.val = ""
      },
      500,
    ),
  )
}

///|
fn select_comment_target_only(
  start_row : Int,
  end_row : Int,
  preview_el : Element,
  col? : Int = 0,
) -> Unit {
  scroll_sync_disabled_until.val = date_now() + 1000.0
  if scroll_sync_raf.val != 0 {
    cancel_animation_frame(scroll_sync_raf.val)
    scroll_sync_raf.val = 0
  }
  let actual_end = if end_row > 0 { end_row } else { start_row }
  let old_selected = query_all(".selected")
  for el in old_selected {
    remove_class(el, "selected")
  }
  let old_highlights = query_all(".preview-highlight")
  for el in old_highlights {
    remove_class(el, "preview-highlight")
  }
  if !is_null(preview_el) {
    add_class(preview_el, "preview-highlight")
    scroll_into_view_nearest(preview_el)
  }
  for r = start_row; r <= actual_end; r = r + 1 {
    let row_idx = r - 1
    let cell = query(
      "td[data-row=\"\{row_idx}\"][data-col=\"1\"]:not(#md-preview *)",
    )
    if !is_null(cell) {
      add_class(cell, "selected")
    }
  }
  selected_comment_row.val = start_row - 1
  selected_comment_col.val = col
  selected_comment_el.val = preview_el
  active_key.val = if start_row == actual_end {
    (start_row - 1).to_string() + ":" + col.to_string()
  } else {
    (start_row - 1).to_string() + "-" + (actual_end - 1).to_string()
  }
  ignore(
    set_timeout(
      fn() {
        scroll_sync_disabled_until.val = 0.0
        scroll_active_pane.val = ""
      },
      300,
    ),
  )
}

///|
fn open_selected_comment_target() -> Bool {
  if selected_comment_row.val < 0 {
    return false
  }
  let row = selected_comment_row.val
  let target = if !is_null(selected_comment_el.val) {
    selected_comment_el.val
  } else {
    query("td[data-row=\"\{row}\"][data-col=\"1\"]:not(#md-preview *)")
  }
  if is_null(target) {
    return false
  }
  select_source_range(row + 1, row + 1, target, col=selected_comment_col.val)
  true
}

///|
fn open_or_select_preview_comment_target(
  raw_target : Element,
  open_editor : Bool,
) -> Bool {
  if is_null(raw_target) {
    return false
  }
  let target = normalize_preview_commentable(raw_target)
  if is_null(target) {
    return false
  }
  let source_anchor = closest(
    target, "[data-source-line],[data-source-start-line]",
  )
  if !is_null(source_anchor) {
    let direct_line = str_to_int(get_attr(source_anchor, "data-source-line"))
    let start_line = if direct_line > 0 {
      direct_line
    } else {
      str_to_int(get_attr(source_anchor, "data-source-start-line"))
    }
    let stored_end = str_to_int(get_attr(source_anchor, "data-source-end-line"))
    let end_line = if stored_end >= start_line {
      stored_end
    } else {
      start_line
    }
    if start_line > 0 {
      let tag = get_tag_name(target)
      let cell_col = if tag == "TD" || tag == "TH" {
        get_cell_index(target) + 1
      } else {
        0
      }
      if open_editor {
        select_source_range(start_line, end_line, target, col=cell_col)
      } else {
        select_comment_target_only(start_line, end_line, target, col=cell_col)
      }
      return true
    }
  }
  let mermaid_range = get_mermaid_source_range(target)
  if mermaid_range.0 > 0 {
    if open_editor {
      select_source_range(
        mermaid_range.0,
        mermaid_range.1,
        closest(target, ".mermaid-container"),
      )
    } else {
      select_comment_target_only(
        mermaid_range.0,
        mermaid_range.1,
        closest(target, ".mermaid-container"),
      )
    }
    return true
  }
  let timeline = closest(target, ".timeline-thumb-wrapper")
  if !is_null(timeline) {
    let wrapper = closest(timeline, ".video-overlay-wrapper")
    let video = query_in(wrapper, "video.video-preview")
    if !is_null(video) {
      let heading = find_closest_heading_above(video)
      let h_line = get_heading_source_line(heading)
      let line = find_image_source_line(get_attr(video, "src"), h_line)
      if line > 0 {
        if open_editor {
          select_source_range(line, line, timeline)
        } else {
          select_comment_target_only(line, line, timeline)
        }
        return true
      }
    }
  }
  let tag = get_tag_name(target)
  if tag == "IMG" {
    let src = get_src(target)
    let heading = find_closest_heading_above(target)
    let h_line = get_heading_source_line(heading)
    let line = find_image_source_line(src, h_line)
    if line > 0 {
      if open_editor {
        select_source_range(line, line, target)
      } else {
        select_comment_target_only(line, line, target)
      }
      return true
    }
  }
  if tag == "VIDEO" {
    let heading = find_closest_heading_above(target)
    let h_line = get_heading_source_line(heading)
    let line = find_image_source_line(get_attr(target, "src"), h_line)
    if line > 0 {
      if open_editor {
        select_source_range(line, line, target)
      } else {
        select_comment_target_only(line, line, target)
      }
      return true
    }
  }
  let pre = closest(target, "pre")
  if !is_null(pre) {
    let code_text = get_text_content(pre)
    let range = find_code_block_range(code_text)
    if range.0 > 0 {
      if open_editor {
        select_source_range(range.0, range.1, pre)
      } else {
        select_comment_target_only(range.0, range.1, pre)
      }
      return true
    }
  }
  let block = resolve_preview_click_block(target)
  if !is_null(block) {
    let heading = find_closest_heading_above(block)
    let h_line = get_heading_source_line(heading)
    let media_line = find_media_source_line_in_block(block, h_line)
    if media_line > 0 {
      let media_anchor = resolve_preview_media_anchor(block)
      if open_editor {
        select_source_range(media_line, media_line, media_anchor)
      } else {
        select_comment_target_only(media_line, media_line, media_anchor)
      }
      return true
    }
    let text = resolve_preview_block_text(block)
    if text.length() == 0 {
      return false
    }
    let block_tag = get_tag_name(block)
    let line = if block_tag == "TD" || block_tag == "TH" {
      find_table_source_line(text, h_line)
    } else {
      find_source_line(text, block, h_line)
    }
    if line > 0 {
      let cell_col = if block_tag == "TD" || block_tag == "TH" {
        get_cell_index(block) + 1
      } else {
        0
      }
      if open_editor {
        select_source_range(line, line, block, col=cell_col)
      } else {
        select_comment_target_only(line, line, block, col=cell_col)
      }
      return true
    }
  }
  false
}

///|
/// Setup preview click handler for markdown mode
fn setup_preview_click() -> Unit {
  let preview = query("#md-preview")
  if is_null(preview) {
    return
  }
  on(preview, "click", fn(e) {
    let target = event_target(e)
    if is_null(target) {
      return
    }
    // Media owns its direct-click fullscreen behavior. Its dedicated comment
    // button stops propagation and opens the inline editor instead.
    let tag = get_tag_name(target)
    let summary = closest(target, "summary")
    if !is_null(summary) && !has_class(summary, "heading-summary") {
      prevent_default(e)
      let details = closest(summary, "details")
      if !is_null(details) {
        if has_attribute(details, "open") {
          remove_attribute(details, "open")
        } else {
          set_attribute(details, "open", "")
        }
      }
      return
    }
    if tag == "IMG" ||
      tag == "VIDEO" ||
      !is_null(closest(target, ".mermaid-container")) {
      return
    }
    ignore(open_or_select_preview_comment_target(target, true))
  })
}

///|
fn setup_preview_comment_buttons() -> Unit {
  let preview = query("#md-preview")
  if is_null(preview) {
    return
  }
  install_preview_comment_buttons(fn(target) {
    ignore(open_or_select_preview_comment_target(target, true))
  })
}

///|
fn fullscreen_overlay_visible() -> Bool {
  !is_null(
    query(
      "#image-fullscreen.visible,#mermaid-fullscreen.visible,#video-fullscreen.visible",
    ),
  )
}

///|
fn app_dialog_visible() -> Bool {
  let submit = query("#submit-modal")
  let recovery = query("#recovery-modal")
  let questions = query("#yunomi-questions-overlay")
  (!is_null(submit) && has_class(submit, "visible")) ||
  (!is_null(recovery) && has_class(recovery, "visible")) ||
  (!is_null(questions) && has_class(questions, "visible")) ||
  fullscreen_overlay_visible() ||
  inline_comment_editor_open()
}

///|
fn keyboard_shortcuts_blocked() -> Bool {
  if app_dialog_visible() {
    return true
  }
  let active = get_active_element()
  let tag = get_tag_name(active)
  tag == "INPUT" || tag == "TEXTAREA" || tag == "SELECT"
}

///|
fn index_of_comment_target(targets : Array[Element], target : Element) -> Int {
  if is_null(target) {
    return -1
  }
  let normalized = normalize_preview_commentable(target)
  for i, item in targets {
    if elem_eq(item, normalized) {
      return i
    }
  }
  -1
}

///|
fn select_preview_target_by_delta(delta : Int) -> Bool {
  let targets = get_preview_comment_targets()
  if targets.length() == 0 {
    return false
  }
  let current_idx = index_of_comment_target(targets, selected_comment_el.val)
  let next_idx = if current_idx < 0 {
    if delta < 0 {
      targets.length() - 1
    } else {
      0
    }
  } else {
    let candidate = current_idx + delta
    if candidate < 0 {
      0
    } else if candidate >= targets.length() {
      targets.length() - 1
    } else {
      candidate
    }
  }
  open_or_select_preview_comment_target(targets[next_idx], false)
}

///|
fn select_table_neighbor_or_delta(
  direction : String,
  fallback_delta : Int,
) -> Bool {
  let neighbor = table_cell_neighbor(selected_comment_el.val, direction)
  if !is_null(neighbor) {
    return open_or_select_preview_comment_target(neighbor, false)
  }
  select_preview_target_by_delta(fallback_delta)
}

///|
fn setup_comment_keyboard_shortcuts() -> Unit {
  on_doc("keydown", fn(e) {
    if keyboard_shortcuts_blocked() {
      return
    }
    let key = event_key(e)
    if event_shift_key(e) {
      match key {
        "h" | "H" => {
          prevent_default(e)
          stop_propagation(e)
          ignore(select_table_neighbor_or_delta("left", -1))
        }
        "l" | "L" => {
          prevent_default(e)
          stop_propagation(e)
          ignore(select_table_neighbor_or_delta("right", 1))
        }
        _ => ()
      }
      return
    }
    if key == "i" || key == "I" || key == "Enter" {
      if open_selected_comment_target() {
        prevent_default(e)
        stop_propagation(e)
      }
    }
  })
}

///|
/// Setup preview mouseup handler for text selection → range comment
fn setup_preview_mouseup() -> Unit {
  let preview = query("#md-preview")
  if is_null(preview) {
    return
  }
  on(preview, "mouseup", fn(_e) {
    ignore(
      set_timeout(
        fn() {
          let sel = window_get_selection()
          if is_null(sel) || selection_is_collapsed(sel) {
            return
          }
          // Get container element
          let container = selection_get_range_container(sel)
          if is_null(container) {
            return
          }
          let selection_block = resolve_preview_click_block(container)
          let meaningful_container = if is_null(selection_block) {
            container
          } else {
            selection_block
          }
          let mermaid_range = get_mermaid_source_range(container)
          if mermaid_range.0 > 0 {
            selection_remove_all_ranges(sel)
            select_source_range(
              mermaid_range.0,
              mermaid_range.1,
              closest(container, ".mermaid-container"),
            )
            return
          }
          let text = selection_to_string(sel)
          if normalize_text(text).length() == 0 {
            return
          }
          // Find heading context
          let heading = find_closest_heading_above(meaningful_container)
          let h_line = get_heading_source_line(heading)
          // Split text into lines and find start/end
          let lines_arr : Array[String] = []
          for part in text.split("\n") {
            let s = part.to_owned()
            if s.length() > 0 {
              lines_arr.push(s)
            }
          }
          let first_line = if lines_arr.length() > 0 {
            lines_arr[0]
          } else {
            ""
          }
          let last_line = if lines_arr.length() > 1 {
            lines_arr[lines_arr.length() - 1]
          } else {
            first_line
          }
          let start_line = find_source_line(
            first_line, meaningful_container, h_line,
          )
          let end_line = if lines_arr.length() > 1 {
            find_source_line(last_line, meaningful_container, h_line)
          } else {
            start_line
          }
          if start_line <= 0 {
            return
          }
          selection_remove_all_ranges(sel)
          let actual_end = if end_line > 0 { end_line } else { start_line }
          select_source_range(start_line, actual_end, meaningful_container)
        },
        10,
      ),
    )
  })
}

///|
/// Current position in the one-question-per-screen stepper (0-based, over
/// the unresolved question-cards only, in DOM order). Persisted alongside
/// answers in persist_draft() so closing the modal for ANY reason (close X,
/// Later, backdrop click, ESC, reload) and reopening it later lands back on
/// the same question, not the first one.
let question_step_index : Ref[Int] = Ref(0)

///|
/// Setup questions UI (overlay, bar, stepper navigation, auto-popup)
fn setup_questions_ui() -> Unit {
  let overlay = query("#yunomi-questions-overlay")
  if is_null(overlay) {
    return
  }
  // Close button
  let close_btn = query("#yunomi-questions-close")
  if !is_null(close_btn) {
    on(close_btn, "click", fn(_e) { close_questions_modal() })
  }
  // Later button — secondary escape valve while answering (does not advance
  // or send the current step's answer, it just closes on whatever is
  // already typed). Once every question is answered and the summary
  // confirmation screen (task #21) is showing, this same button relabels to
  // "戻る" and instead returns to the last question for editing — "answer
  // later" makes no sense once nothing is left unanswered.
  let later_btn = query("#yunomi-questions-later")
  if !is_null(later_btn) {
    on(later_btn, "click", fn(_e) {
      let cards = query_all("#yunomi-questions-stepper .question-card")
      let count = cards.length()
      if count > 0 && question_step_index.val >= count {
        question_step_index.val = count - 1
        render_question_step()
      } else {
        close_questions_modal()
      }
    })
  }
  // Next / Complete button — the primary path. Sends the current step's
  // answer live, then either advances, opens the summary confirmation
  // screen (on the last question), or — if the summary screen is already
  // showing — confirms and closes.
  let next_btn = query("#yunomi-questions-next")
  if !is_null(next_btn) {
    on(next_btn, "click", fn(_e) { advance_question_step() })
  }
  // Summary item click — jump back to that question's step to edit it,
  // without walking through every question one-by-one from the top.
  let summary_list = query("#yunomi-questions-summary")
  if !is_null(summary_list) {
    on(summary_list, "click", fn(e) {
      let item = closest(event_target(e), ".q-summary-item")
      if !is_null(item) {
        question_step_index.val = str_to_int(get_attr(item, "data-step"))
        persist_draft()
        render_question_step()
      }
    })
  }
  // Bar open button (the floating pill)
  let bar_open = query("#yunomi-questions-bar-open")
  if !is_null(bar_open) {
    on(bar_open, "click", fn(_e) { open_questions_modal() })
  }
  // Click overlay background to close
  on(overlay, "click", fn(e) {
    if elem_eq(event_target(e), overlay) {
      close_questions_modal()
    }
  })
  // Escape to close
  on_doc("keydown", fn(e) {
    if event_key(e) == "Escape" {
      let ov = query("#yunomi-questions-overlay")
      if !is_null(ov) && has_class(ov, "visible") {
        close_questions_modal()
      }
    }
  })
  // Setup option buttons
  let option_btns = query_all(".q-option-btn")
  for btn in option_btns {
    on(btn, "click", fn(e) {
      let target = event_target(e)
      let was_selected = has_class(target, "selected")
      // Deselect all options in same question
      let qi = get_attr(target, "data-qi")
      let siblings = query_all(".q-option-btn[data-qi=\"" + qi + "\"]")
      for sib in siblings {
        remove_class(sib, "selected")
      }
      if !was_selected {
        add_class(target, "selected")
      }
      // Badge only — see update_questions_badge()'s doc comment for why
      // this must never also schedule an auto-close: task #21 introduced
      // a mandatory answer-summary confirmation screen between the last
      // question and the modal actually closing, and an auto-close firing
      // 500ms after mere DOM state (an option selected, a textarea filled)
      // would silently close the dialog out from under that confirmation
      // — or even before the human clicks 完了 at all — completely
      // defeating the point of the confirmation step. Closing is now owned
      // exclusively by the explicit Next/完了/確定して閉じる button flow
      // (advance_question_step()) and the X/Later/backdrop/ESC escape
      // hatches.
      update_questions_badge()
      persist_draft()
    })
  }
  // Setup answer textareas
  let answer_areas = query_all(".q-answer")
  for area in answer_areas {
    on(area, "input", fn(_e) {
      update_questions_badge()
      persist_draft()
    })
  }
  // Resolved toggle
  let resolved_toggle = query(".yunomi-resolved-toggle")
  if !is_null(resolved_toggle) {
    on(resolved_toggle, "click", fn(_e) {
      if has_class(resolved_toggle, "open") {
        remove_class(resolved_toggle, "open")
        remove_class(query(".yunomi-resolved-list"), "visible")
      } else {
        add_class(resolved_toggle, "open")
        add_class(query(".yunomi-resolved-list"), "visible")
      }
    })
  }
  // Sync the header/footer chrome (progress text, Next-vs-Complete label) to
  // whatever step is currently marked active in the server-rendered HTML.
  render_question_step()
  // Auto-popup if any unresolved question exists — but not on top of the
  // recovery modal (check_recovery() runs synchronously right after this
  // in init_app). The recovery modal is z-index 100 and the questions
  // overlay is z-index 1100, so opening both leaves the questions overlay
  // silently blocking clicks on the recovery modal's Restore/Discard
  // buttons underneath. Defer to hide_recovery_modal(), which re-checks and
  // opens the questions modal once the human has decided.
  //
  // has_unresolved_questions() is deliberately static (does a question
  // exist at all), not "is anything still unanswered" — a question that
  // exists must be shown on load even if a restored draft (or the
  // frontmatter's own `answer:`) already fills it in. "気がついたら回答
  // する" (stumbling on it later via the pill) is not an acceptable primary
  // path; every unresolved question must be seen up front, prefilled or not.
  if has_unresolved_questions() {
    // Auto-open after short delay
    ignore(
      set_timeout(
        fn() {
          let recovery_modal = query("#recovery-modal")
          if is_null(recovery_modal) || !has_class(recovery_modal, "visible") {
            open_questions_modal()
          }
        },
        500,
      ),
    )
  }
}

///|
/// Show the .question-card at question_step_index (clamped to the actual
/// number of stepper cards, or to `count` for the answer-summary
/// confirmation screen — see task #21) and hide every other one, syncing
/// the header progress counter and the Next/Later footer labels to match.
fn render_question_step() -> Unit {
  let cards = query_all("#yunomi-questions-stepper .question-card")
  let count = cards.length()
  let progress_el = query("#yunomi-questions-progress")
  let body = query("#yunomi-questions-body")
  let next_btn = query("#yunomi-questions-next")
  let later_btn = query("#yunomi-questions-later")
  if count == 0 {
    if !is_null(progress_el) {
      set_inner_html(progress_el, "")
    }
    return
  }
  let mut idx = question_step_index.val
  if idx < 0 {
    idx = 0
  }
  // idx == count is the summary sentinel — one past the last real question.
  if idx > count {
    idx = count
  }
  question_step_index.val = idx
  if idx == count {
    // Answer-summary confirmation screen: hide every question-card (and
    // the resolved section, via .summary-active on the body) and populate
    // the recap instead.
    for card in cards {
      remove_class(card, "step-active")
    }
    if !is_null(body) {
      add_class(body, "summary-active")
    }
    render_answer_summary()
    if !is_null(progress_el) {
      set_inner_html(progress_el, count.to_string() + "/" + count.to_string())
    }
    if !is_null(next_btn) {
      set_inner_html(next_btn, "確定して閉じる")
    }
    if !is_null(later_btn) {
      set_inner_html(later_btn, "戻る")
    }
    return
  }
  if !is_null(body) {
    remove_class(body, "summary-active")
  }
  for p, card in cards {
    if p == idx {
      add_class(card, "step-active")
    } else {
      remove_class(card, "step-active")
    }
  }
  if !is_null(progress_el) {
    set_inner_html(progress_el, (idx + 1).to_string() + "/" + count.to_string())
  }
  if !is_null(next_btn) {
    set_inner_html(next_btn, if idx == count - 1 { "完了" } else { "次へ" })
  }
  if !is_null(later_btn) {
    set_inner_html(later_btn, "後で回答する")
  }
}

///|
/// Send the currently-visible step's answer (option + free text, combined
/// the same way collect_yunomi_answers() combines them for final submit) to
/// the server the instant Next/Complete is clicked — not at final Submit —
/// so an agent tailing the live log sees each answer immediately instead of
/// waiting for the whole review to finish.
fn send_current_step_answer_live(card : Element) -> Unit {
  if get_yunomi_port() <= 0 {
    return
  }
  let id = get_attr(card, "data-qid")
  if id.length() == 0 {
    return
  }
  let title_el = query_in(card, ".q-title")
  let question_text = if is_null(title_el) {
    ""
  } else {
    get_text_content(title_el)
  }
  let textarea = query_in(card, ".q-answer")
  let text = if is_null(textarea) { "" } else { get_value(textarea) }
  let selected_btn = query_in(card, ".q-option-btn.selected")
  let option = if is_null(selected_btn) {
    ""
  } else {
    let v = get_attr(selected_btn, "data-val")
    if v.length() > 0 {
      v
    } else {
      get_text_content(selected_btn)
    }
  }
  let combined = if option.length() > 0 && text.length() > 0 {
    option + "\n" + text
  } else if option.length() > 0 {
    option
  } else {
    text
  }
  send_answer_event_to_server(id, question_text, combined)
}

///|
/// POST a single answer event to the server over the same /comment
/// real-time IPC channel send_comment_to_server() already uses — type:
/// "answer" (handled by handle_answer_event in main.mbt) so it lands in the
/// live JSONL log immediately, independent of the eventual /exit submit.
fn send_answer_event_to_server(
  id : String,
  question : String,
  answer : String,
) -> Unit {
  let url = location_origin() + "/comment"
  let buf = StringBuilder::new()
  buf.write_string("{\"type\":\"answer\",\"id\":")
  buf.write_string(json_encode_string(id))
  buf.write_string(",\"question\":")
  buf.write_string(json_encode_string(question))
  buf.write_string(",\"answer\":")
  buf.write_string(json_encode_string(answer))
  buf.write_string("}")
  fetch_post(url, buf.to_string(), fn(_response) { ignore(_response) })
}

///|
/// Handle the primary "Next" / "Complete" / "確定して閉じる" action: flush
/// the current step's answer live, persist the draft (including the new
/// step position), then either move to the next question, open the
/// answer-summary confirmation screen (reaching the end of the stepper —
/// task #21: closing straight from the last question's "完了" click with
/// zero feedback read as "did that just do nothing?"), or — if the summary
/// screen is already showing — confirm and actually close.
fn advance_question_step() -> Unit {
  let cards = query_all("#yunomi-questions-stepper .question-card")
  let count = cards.length()
  if count == 0 {
    close_questions_modal()
    return
  }
  let idx = question_step_index.val
  if idx >= count {
    // Already on the summary screen — this click is "確定して閉じる".
    confirm_summary_and_close(count)
    return
  }
  let mut clamped = idx
  if clamped < 0 {
    clamped = 0
  }
  if clamped > count - 1 {
    clamped = count - 1
  }
  send_current_step_answer_live(cards[clamped])
  if clamped >= count - 1 {
    // Last question just answered — open the summary confirmation screen
    // instead of closing outright.
    question_step_index.val = count
    persist_draft()
    render_question_step()
  } else {
    question_step_index.val = clamped + 1
    persist_draft()
    render_question_step()
  }
}

///|
/// Confirm the answer-summary screen: persist (so a reload lands back on
/// the summary, not question 1), close the modal, and flash the pill as a
/// brief "all answered" acknowledgement — the concrete, minimal feedback
/// that the review actually recorded something, replacing "the dialog
/// just vanished, did anything even happen?".
fn confirm_summary_and_close(total : Int) -> Unit {
  persist_draft()
  close_questions_modal()
  flash_answered_pill(total)
}

///|
/// Briefly show the floating pill in a "done" state (check icon,
/// --success tint, "N/N" badge) for a couple of seconds, then revert it to
/// its normal unanswered-count display. Safe to call even if the pill is
/// hidden — it un-hides itself, flashes, and re-hides via the same
/// unanswered-count logic close_questions_modal() already uses.
fn flash_answered_pill(total : Int) -> Unit {
  let bar = query("#yunomi-questions-bar-open")
  if is_null(bar) {
    return
  }
  let count_el = query("#yunomi-questions-bar-count")
  if !is_null(count_el) {
    set_inner_html(count_el, total.to_string() + "/" + total.to_string())
  }
  add_class(bar, "visible")
  add_class(bar, "done")
  add_class_body("has-questions-bar")
  ignore(
    set_timeout(
      fn() {
        remove_class(bar, "done")
        update_questions_badge()
        // Only re-hide the pill if there's genuinely nothing left
        // unanswered to show it for — a fresh unresolved question could
        // in principle have appeared in the meantime via a reload.
        if count_unanswered_questions() == 0 {
          remove_class(bar, "visible")
          remove_class_body("has-questions-bar")
        }
      },
      2500,
    ),
  )
}

///|
/// Open questions modal
fn open_questions_modal() -> Unit {
  let submit = query("#submit-modal")
  if !is_null(submit) && has_class(submit, "visible") {
    return
  }
  let overlay = query("#yunomi-questions-overlay")
  if !is_null(overlay) {
    add_class(overlay, "visible")
  }
  render_question_step()
  let bar = query("#yunomi-questions-bar-open")
  if !is_null(bar) {
    remove_class(bar, "visible")
    remove_class_body("has-questions-bar")
  }
}

///|
/// Close questions modal (X, Later/戻る-while-mid-stepper, backdrop click,
/// ESC, or confirm_summary_and_close() after the answer-summary screen all
/// route here) — the step position is left untouched so reopening resumes
/// where the human left off (including the summary screen itself, if that
/// was where they were).
fn close_questions_modal() -> Unit {
  let overlay = query("#yunomi-questions-overlay")
  if !is_null(overlay) {
    remove_class(overlay, "visible")
  }
  // Show the floating pill if there are still unanswered questions
  let unanswered = count_unanswered_questions()
  let bar = query("#yunomi-questions-bar-open")
  if unanswered > 0 && !is_null(bar) {
    add_class(bar, "visible")
    add_class_body("has-questions-bar")
  }
}

///|
/// Count unanswered questions
fn count_unanswered_questions() -> Int {
  let cards = query_all(".question-card:not(.resolved)")
  let mut unanswered = 0
  for card in cards {
    let qi = get_attr(card, "data-qid")
    ignore(qi)
    // Check if any option selected
    let selected = query_in(card, ".q-option-btn.selected")
    let textarea = query_in(card, ".q-answer")
    let has_option = !is_null(selected)
    let has_text = if !is_null(textarea) {
      get_value(textarea).length() > 0
    } else {
      false
    }
    if !has_option && !has_text {
      unanswered = unanswered + 1
    }
  }
  unanswered
}

///|
/// Update the unanswered-count badge on the floating pill (bar badge only —
/// the modal header shows step position "n/total" via render_question_step(),
/// not a raw count). Safe to call from anywhere, including programmatic
/// restores, since it has no side effect beyond the badge text.
fn update_questions_badge() -> Unit {
  let unanswered = count_unanswered_questions()
  let bar_count = query("#yunomi-questions-bar-count")
  if !is_null(bar_count) {
    set_inner_html(bar_count, unanswered.to_string())
  }
}

///|
/// Setup heading toggle (collapse/expand sections)
fn _setup_heading_toggles() -> Unit {
  let headings = query_all(".md-heading-toggle")
  for heading in headings {
    let key = get_attr(heading, "data-heading-key")
    let level = str_to_int(get_attr(heading, "data-heading-level"))
    // Restore state from localStorage
    let stored = ls_get("yunomi:heading:" + key)
    if stored == "collapsed" {
      collapse_heading_section(heading, level)
      let icon = query_in(heading, ".heading-toggle-icon")
      if !is_null(icon) {
        add_class(icon, "collapsed")
        set_inner_html(icon, "\u{25B6}")
      }
    }
    // Toggle icon click handler
    let icon = query_in(heading, ".heading-toggle-icon")
    if !is_null(icon) {
      on(icon, "click", fn(e) {
        prevent_default(e)
        // Stop propagation to prevent preview click handler
        stop_propagation(e)
        let is_collapsed = has_class(icon, "collapsed")
        if is_collapsed {
          // Expand
          remove_class(icon, "collapsed")
          set_inner_html(icon, "\u{25BC}")
          expand_heading_section(heading, level)
          ls_set("yunomi:heading:" + key, "expanded")
        } else {
          // Collapse
          add_class(icon, "collapsed")
          set_inner_html(icon, "\u{25B6}")
          collapse_heading_section(heading, level)
          ls_set("yunomi:heading:" + key, "collapsed")
        }
      })
    }
  }
}

///|
/// Collapse all sibling elements until next heading of same or higher level
fn collapse_heading_section(heading : Element, level : Int) -> Unit {
  let mut sib = next_element_sibling(heading)
  while !is_null(sib) {
    let tag = get_tag_name(sib)
    // Stop at heading of same or higher level
    if tag == "H1" ||
      tag == "H2" ||
      tag == "H3" ||
      tag == "H4" ||
      tag == "H5" ||
      tag == "H6" {
      let sib_level = str_to_int(get_attr(sib, "data-heading-level"))
      if sib_level > 0 && sib_level <= level {
        break
      }
    }
    add_class(sib, "heading-collapsed")
    sib = next_element_sibling(sib)
  }
}

///|
/// Expand all sibling elements until next heading of same or higher level
fn expand_heading_section(heading : Element, level : Int) -> Unit {
  let mut sib = next_element_sibling(heading)
  while !is_null(sib) {
    let tag = get_tag_name(sib)
    if tag == "H1" ||
      tag == "H2" ||
      tag == "H3" ||
      tag == "H4" ||
      tag == "H5" ||
      tag == "H6" {
      let sib_level = str_to_int(get_attr(sib, "data-heading-level"))
      if sib_level > 0 && sib_level <= level {
        break
      }
    }
    remove_class(sib, "heading-collapsed")
    sib = next_element_sibling(sib)
  }
}

///|
/// Close a fullscreen overlay when the backdrop is clicked.
///  Closes on any click that is not on the zoomable content (content_sel),
///  the header controls, or the minimap. Clicks that follow a pan-drag
///  (pointer moved more than ~6px between mousedown and click) are ignored.
fn setup_overlay_backdrop_close(
  overlay : Element,
  content_sel : String,
  close_fn : () -> Unit,
) -> Unit {
  let down_x : Ref[Int] = Ref(0)
  let down_y : Ref[Int] = Ref(0)
  on(overlay, "mousedown", fn(e) {
    down_x.val = get_event_client_x(e)
    down_y.val = get_event_client_y(e)
  })
  on(overlay, "click", fn(e) {
    let dx = get_event_client_x(e) - down_x.val
    let dy = get_event_client_y(e) - down_y.val
    if dx * dx + dy * dy > 36 {
      return
    }
    let target = event_target(e)
    if !is_null(closest(target, content_sel)) {
      return
    }
    if !is_null(closest(target, ".fullscreen-header")) {
      return
    }
    if !is_null(closest(target, ".minimap")) {
      return
    }
    close_fn()
  })
}

///|
/// Mermaid fullscreen ZoomPanViewer handle (MoonBit native)
let fs_mermaid_zpv : Ref[ZPVState?] = Ref(None)

///|
/// Setup mermaid fullscreen with pure MoonBit ZoomPanViewer (cli.cjs L7398-7500)
fn setup_mermaid_fullscreen_moonbit() -> Unit {
  let overlay = query("#mermaid-fullscreen")
  let fs_content = query("#fs-content")
  let fs_wrapper = query("#fs-wrapper")
  let fs_zoom_info = query("#fs-zoom-info")
  if is_null(overlay) || is_null(fs_content) || is_null(fs_wrapper) {
    return
  }
  // Click handler: open mermaid fullscreen (click anywhere on the diagram, like images)
  on_doc("click", fn(e) {
    let target = event_target(e)
    if !is_null(closest(target, ".yunomi-comment-button")) {
      return
    }
    let container = closest(target, ".mermaid-container")
    if !is_null(container) {
      let svg = query_in(container, ".mermaid svg")
      if !is_null(svg) {
        // Don't open fullscreen for error SVGs
        let err_icon = query_in(svg, ".error-icon")
        if !is_null(err_icon) {
          return
        }
        open_mermaid_fullscreen_moonbit(
          svg, overlay, fs_content, fs_wrapper, fs_zoom_info,
        )
        stop_propagation(e)
      }
    }
  })
  // Controls
  let zoom_in_btn = query("#fs-zoom-in")
  let zoom_out_btn = query("#fs-zoom-out")
  let fs_reset = query("#fs-reset")
  let fs_close = query("#fs-close")
  if !is_null(zoom_in_btn) {
    on(zoom_in_btn, "click", fn(_e) {
      if fs_mermaid_zpv.val is Some(_) {
        zoom_in(fs_mermaid_zpv.val.unwrap())
      }
    })
  }
  if !is_null(zoom_out_btn) {
    on(zoom_out_btn, "click", fn(_e) {
      if fs_mermaid_zpv.val is Some(_) {
        zoom_out(fs_mermaid_zpv.val.unwrap())
      }
    })
  }
  if !is_null(fs_reset) {
    on(fs_reset, "click", fn(_e) {
      if fs_mermaid_zpv.val is Some(_) {
        reset_view(fs_mermaid_zpv.val.unwrap())
      }
    })
  }
  if !is_null(fs_close) {
    on(fs_close, "click", fn(_e) { close_mermaid_fullscreen_moonbit(overlay) })
  }
  // ESC to close + backdrop click (anything except diagram/controls; ignore pan-drags)
  setup_overlay_backdrop_close(overlay, "#fs-wrapper", fn() {
    close_mermaid_fullscreen_moonbit(overlay)
  })
  on_doc("keydown", fn(e) {
    if event_key(e) == "Escape" && has_class_visible(overlay) {
      close_mermaid_fullscreen_moonbit(overlay)
      prevent_default(e)
    }
  })
}

///|
/// Open mermaid diagram in fullscreen with pure MoonBit ZoomPanViewer
fn open_mermaid_fullscreen_moonbit(
  svg : Element,
  overlay : Element,
  fs_content : Element,
  fs_wrapper : Element,
  fs_zoom_info : Element,
) -> Unit {
  close_inline_comment_before_fullscreen()
  // Destroy previous viewer
  if fs_mermaid_zpv.val is Some(_) {
    destroy_zoom_pan_viewer(fs_mermaid_zpv.val.unwrap())
    fs_mermaid_zpv.val = None
  }
  clear_children(fs_wrapper)
  set_class_name(fs_wrapper, "mermaid-wrapper")
  let cloned = clone_node_deep(svg)
  let size = get_svg_natural_size(svg)
  let nw = size[0]
  let nh = size[1]
  set_style(fs_wrapper, "padding", "0")
  set_style(cloned, "width", nw.to_string() + "px")
  set_style(cloned, "height", nh.to_string() + "px")
  append_child(fs_wrapper, cloned)
  // Hide wrapper until fitToViewport positions it
  set_visibility(fs_wrapper, false)
  // Setup minimap: clone SVG into minimap-content
  let minimap_content = query("#fs-minimap-content")
  let minimap_viewport = query("#fs-minimap-viewport")
  if !is_null(minimap_content) {
    clear_children(minimap_content)
    let minimap_svg = clone_node_deep(svg)
    append_child(minimap_content, minimap_svg)
  }
  // Create ZoomPanViewer with padding for margin and minimap enabled
  let zpv = create_zoom_pan_viewer_moonbit(
    fs_content, fs_wrapper, nw, nh, fs_zoom_info, true, minimap_viewport, 184.0,
    134.0, 8.0, 0.1, 10.0, true,
  )
  fs_mermaid_zpv.val = Some(zpv)
  show_overlay(overlay)
  // Fit after render
  ignore(
    request_animation_frame(fn() {
      fit_to_viewport(zpv)
      set_visibility(fs_wrapper, true)
    }),
  )
}

///|
/// Close mermaid fullscreen (MoonBit native)
fn close_mermaid_fullscreen_moonbit(overlay : Element) -> Unit {
  if fs_mermaid_zpv.val is Some(_) {
    destroy_zoom_pan_viewer(fs_mermaid_zpv.val.unwrap())
    fs_mermaid_zpv.val = None
  }
  hide_overlay(overlay)
}

///|
/// Image fullscreen ZoomPanViewer handle (MoonBit native)
let fs_image_zpv : Ref[ZPVState?] = Ref(None)

///|
let current_image_index : Ref[Int] = Ref(-1)

///|
/// Setup image fullscreen with pure MoonBit ZoomPanViewer
fn setup_image_fullscreen_moonbit() -> Unit {
  let overlay = query("#image-fullscreen")
  let fs_content = query("#image-fs-content")
  let fs_wrapper = query("#image-fs-wrapper")
  let fs_zoom_info = query("#img-fs-zoom-info")
  let fs_counter = query("#img-fs-counter")
  if is_null(overlay) || is_null(fs_content) || is_null(fs_wrapper) {
    return
  }
  let preview = query("#md-preview")
  if is_null(preview) {
    return
  }
  // Click handler: open image fullscreen when clicking images in preview
  on(preview, "click", fn(e) {
    let target = event_target(e)
    if get_tag_name(target) == "IMG" {
      // Don't open if inside mermaid container
      if !is_null(closest(target, ".mermaid-container")) {
        return
      }
      let all_images = query_all_in(preview, "img")
      // Filter out mermaid images and video-timeline scene thumbnails
      let images : Array[Element] = []
      for img in all_images {
        if is_null(closest(img, ".mermaid-container")) &&
          is_null(closest(img, ".video-timeline")) {
          images.push(img)
        }
      }
      // Find index of clicked image
      let mut idx = -1
      for i, img in images {
        if elem_eq(img, target) {
          idx = i
          break
        }
      }
      if idx >= 0 {
        stop_propagation(e)
        show_image_fullscreen_moonbit(
          images, idx, overlay, fs_content, fs_wrapper, fs_zoom_info, fs_counter,
        )
      }
    }
  })
  // Controls
  let zoom_in_btn = query("#img-fs-zoom-in")
  let zoom_out_btn = query("#img-fs-zoom-out")
  let fs_reset = query("#img-fs-reset")
  let fs_close = query("#img-fs-close")
  let fs_prev = query("#img-fs-prev")
  let fs_next = query("#img-fs-next")
  if !is_null(zoom_in_btn) {
    on(zoom_in_btn, "click", fn(_e) {
      if fs_image_zpv.val is Some(_) {
        zoom_in(fs_image_zpv.val.unwrap())
      }
    })
  }
  if !is_null(zoom_out_btn) {
    on(zoom_out_btn, "click", fn(_e) {
      if fs_image_zpv.val is Some(_) {
        zoom_out(fs_image_zpv.val.unwrap())
      }
    })
  }
  if !is_null(fs_reset) {
    on(fs_reset, "click", fn(_e) {
      if fs_image_zpv.val is Some(_) {
        reset_view(fs_image_zpv.val.unwrap())
      }
    })
  }
  if !is_null(fs_close) {
    on(fs_close, "click", fn(_e) { close_image_fullscreen_moonbit(overlay) })
  }
  // Previous/Next navigation buttons
  if !is_null(fs_prev) {
    on(fs_prev, "click", fn(_e) {
      navigate_image_fullscreen_moonbit(
        -1, overlay, fs_content, fs_wrapper, fs_zoom_info, fs_counter,
      )
    })
  }
  if !is_null(fs_next) {
    on(fs_next, "click", fn(_e) {
      navigate_image_fullscreen_moonbit(
        1, overlay, fs_content, fs_wrapper, fs_zoom_info, fs_counter,
      )
    })
  }
  // ESC to close + backdrop click (anything except image/controls; ignore pan-drags) + arrow key navigation
  setup_overlay_backdrop_close(overlay, "#image-fs-wrapper", fn() {
    close_image_fullscreen_moonbit(overlay)
  })
  on_doc("keydown", fn(e) {
    if !has_class_visible(overlay) {
      return
    }
    let key = event_key(e)
    if key == "Escape" {
      close_image_fullscreen_moonbit(overlay)
      prevent_default(e)
    } else if key == "ArrowLeft" || key == "h" || key == "H" {
      navigate_image_fullscreen_moonbit(
        -1, overlay, fs_content, fs_wrapper, fs_zoom_info, fs_counter,
      )
      prevent_default(e)
    } else if key == "ArrowRight" || key == "l" || key == "L" {
      navigate_image_fullscreen_moonbit(
        1, overlay, fs_content, fs_wrapper, fs_zoom_info, fs_counter,
      )
      prevent_default(e)
    }
  })
}

///|
/// Collect images from preview (excluding mermaid)
fn collect_preview_images() -> Array[Element] {
  let preview = query("#md-preview")
  if is_null(preview) {
    return []
  }
  let all = query_all_in(preview, "img")
  let result : Array[Element] = []
  for img in all {
    if is_null(closest(img, ".mermaid-container")) &&
      is_null(closest(img, ".video-timeline")) {
      result.push(img)
    }
  }
  result
}

///|
/// Show image in fullscreen with pure MoonBit ZoomPanViewer
fn show_image_fullscreen_moonbit(
  images : Array[Element],
  index : Int,
  overlay : Element,
  fs_content : Element,
  fs_wrapper : Element,
  fs_zoom_info : Element,
  fs_counter : Element,
) -> Unit {
  if index < 0 || index >= images.length() {
    return
  }
  close_inline_comment_before_fullscreen()
  current_image_index.val = index
  // Destroy previous viewer
  if fs_image_zpv.val is Some(_) {
    destroy_zoom_pan_viewer(fs_image_zpv.val.unwrap())
    fs_image_zpv.val = None
  }
  clear_children(fs_wrapper)
  let img = images[index]
  let cloned = clone_node_deep(img)
  set_style(cloned, "maxWidth", "none")
  set_style(cloned, "maxHeight", "none")
  set_style(cloned, "cursor", "")
  set_style(cloned, "display", "block")
  set_draggable(cloned, false)
  let nw = get_natural_width(img)
  let nh = get_natural_height(img)
  let nat_w = if nw > 0.0 { nw } else { 800.0 }
  let nat_h = if nh > 0.0 { nh } else { 600.0 }
  set_style(cloned, "width", nat_w.to_string() + "px")
  set_style(cloned, "height", nat_h.to_string() + "px")
  append_child(fs_wrapper, cloned)
  // Update counter
  if !is_null(fs_counter) {
    set_text_content(
      fs_counter,
      (index + 1).to_string() + " / " + images.length().to_string(),
    )
  }
  // Hide wrapper until fit
  set_visibility(fs_wrapper, false)
  // Setup image minimap
  let img_minimap_content = query("#image-fs-minimap-content")
  let img_minimap_viewport = query("#image-fs-minimap-viewport")
  if !is_null(img_minimap_content) {
    clear_children(img_minimap_content)
    let minimap_img = clone_node_deep(cloned)
    set_style(minimap_img, "width", "100%")
    set_style(minimap_img, "height", "100%")
    set_style(minimap_img, "objectFit", "contain")
    append_child(img_minimap_content, minimap_img)
  }
  let zpv = create_zoom_pan_viewer_moonbit(
    fs_content, fs_wrapper, nat_w, nat_h, fs_zoom_info, true, img_minimap_viewport,
    184.0, 134.0, 8.0, 0.1, 20.0, true,
  )
  fs_image_zpv.val = Some(zpv)
  show_overlay(overlay)
  ignore(
    request_animation_frame(fn() {
      fit_to_viewport(zpv)
      set_visibility(fs_wrapper, true)
    }),
  )
}

///|
/// Navigate image fullscreen by direction (-1=prev, 1=next)
fn navigate_image_fullscreen_moonbit(
  direction : Int,
  overlay : Element,
  fs_content : Element,
  fs_wrapper : Element,
  fs_zoom_info : Element,
  fs_counter : Element,
) -> Unit {
  let images = collect_preview_images()
  if images.length() == 0 {
    return
  }
  let new_idx = current_image_index.val + direction
  if new_idx >= 0 && new_idx < images.length() {
    show_image_fullscreen_moonbit(
      images, new_idx, overlay, fs_content, fs_wrapper, fs_zoom_info, fs_counter,
    )
  }
}

///|
/// Close image fullscreen (MoonBit native)
fn close_image_fullscreen_moonbit(overlay : Element) -> Unit {
  // Capture the original image before resetting state
  let saved_index = current_image_index.val
  if fs_image_zpv.val is Some(_) {
    destroy_zoom_pan_viewer(fs_image_zpv.val.unwrap())
    fs_image_zpv.val = None
  }
  current_image_index.val = -1
  hide_overlay(overlay)
  // After closing, select the original image and show comment dialog
  if saved_index >= 0 {
    let images = collect_preview_images()
    if saved_index < images.length() {
      let img = images[saved_index]
      let src = get_src(img)
      let heading = find_closest_heading_above(img)
      let h_line = get_heading_source_line(heading)
      let line = find_image_source_line(src, h_line)
      if line > 0 {
        select_source_range(line, line, img)
      }
    }
  }
}

///|
/// Video fullscreen state (MoonBit native)
let fs_video_timeline : Ref[VTLState?] = Ref(None)

///|
let current_video_index : Ref[Int] = Ref(-1)

///|
let current_scene_threshold : Ref[Double] = Ref(0.01)

///|
let current_stab_threshold : Ref[Double] = Ref(0.1)

///|
let current_video_path : Ref[String] = Ref("")

///|
/// Setup video fullscreen with pure MoonBit VideoTimeline
fn setup_video_fullscreen_moonbit() -> Unit {
  let overlay = query("#video-fullscreen")
  let container = query("#video-container")
  let fs_counter = query("#vid-fs-counter")
  if is_null(overlay) || is_null(container) {
    return
  }
  let preview = query("#md-preview")
  if is_null(preview) {
    return
  }
  // Click handler: open video fullscreen when clicking video elements in preview
  on(preview, "click", fn(e) {
    let target = event_target(e)
    if get_tag_name(target) == "VIDEO" {
      let all_videos = query_all_in(preview, "video")
      let mut idx = -1
      for i, vid in all_videos {
        if elem_eq(vid, target) {
          idx = i
          break
        }
      }
      if idx >= 0 {
        show_video_fullscreen_moonbit(
          all_videos, idx, overlay, container, fs_counter,
        )
        stop_propagation(e)
      }
    }
  })
  // Add fullscreen overlay buttons to all preview videos (for mobile tap)
  add_video_fullscreen_buttons(preview, overlay, container, fs_counter)
  // Close button
  let fs_close = query("#video-close")
  if !is_null(fs_close) {
    on(fs_close, "click", fn(_e) {
      close_video_fullscreen_moonbit(overlay, container)
    })
  }
  // ESC + backdrop click (overlay or empty container area) + keyboard
  on(overlay, "click", fn(e) {
    let target = event_target(e)
    if elem_eq(target, overlay) || elem_eq(target, container) {
      close_video_fullscreen_moonbit(overlay, container)
    }
  })
  on_doc("keydown", fn(e) {
    if !has_class_visible(overlay) {
      return
    }
    let key = event_key(e)
    if key == "Escape" {
      close_video_fullscreen_moonbit(overlay, container)
      prevent_default(e)
    } else if key == "ArrowLeft" || key == "h" || key == "H" {
      if fs_video_timeline.val is Some(_) {
        navigate(fs_video_timeline.val.unwrap(), -1)
      }
      prevent_default(e)
    } else if key == "ArrowRight" || key == "l" || key == "L" {
      if fs_video_timeline.val is Some(_) {
        navigate(fs_video_timeline.val.unwrap(), 1)
      }
      prevent_default(e)
    } else if key == "ArrowUp" || key == "k" || key == "K" {
      navigate_video_fullscreen_moonbit(-1, overlay, container, fs_counter)
      prevent_default(e)
    } else if key == "ArrowDown" || key == "j" || key == "J" {
      navigate_video_fullscreen_moonbit(1, overlay, container, fs_counter)
      prevent_default(e)
    } else if key == " " {
      let vid = query_in(container, "video")
      if !is_null(vid) {
        if video_is_paused(vid) {
          video_play(vid)
        } else {
          video_pause(vid)
        }
      }
      prevent_default(e)
    }
  })
  // --- Settings panel ---
  setup_video_settings_moonbit(overlay, container, fs_counter)
}

///|
/// Add fullscreen overlay buttons to preview videos (for mobile tap)
fn add_video_fullscreen_buttons(
  preview : Element,
  overlay : Element,
  container : Element,
  fs_counter : Element,
) -> Unit {
  let videos = query_all_in(preview, "video")
  for i, vid in videos {
    // Wrap video in a container div for overlay positioning
    let parent = parent_element(vid)
    if is_null(parent) {
      continue
    }
    let wrapper = create_element("div")
    add_class(wrapper, "video-overlay-wrapper")
    insert_before(vid, wrapper)
    append_child(wrapper, vid)
    // Create fullscreen button overlay
    let btn = create_element("button")
    add_class(btn, "video-fs-overlay-btn")
    set_inner_html(btn, "&#9974;") // fullscreen icon ⛶
    set_attribute(btn, "title", "Fullscreen")
    set_attribute(btn, "data-video-index", i.to_string())
    on(btn, "click", fn(e) {
      prevent_default(e)
      stop_propagation(e)
      let all_videos = query_all_in(preview, "video")
      let idx_str = get_attribute(event_target(e), "data-video-index")
      let idx = @core.parse_int_safe(idx_str)
      if idx >= 0 && idx < all_videos.length() {
        show_video_fullscreen_moonbit(
          all_videos, idx, overlay, container, fs_counter,
        )
      }
    })
    append_child(wrapper, btn)
    // Inline scene-thumbnail timeline: reserve the element now (no layout
    // shift later) and start thumbnail loading once the video scrolls into view
    let src = get_src(vid)
    if src.length() > 0 {
      let video_path = url_to_pathname(src)
      let vtl = create_video_timeline_moonbit(
        vid,
        wrapper,
        video_path,
        current_scene_threshold.val,
        current_stab_threshold.val,
        true,
        autostart=false,
      )
      observe_visible_once(vid, fn() { start_timeline_loading(vtl) })
    }
  }
}

///|
/// Run callback once when element first becomes visible in the viewport
extern "js" fn observe_visible_once(el : Element, cb : () -> Unit) -> Unit =
  #|(el, cb) => {
  #|  if (!el) return;
  #|  if (typeof IntersectionObserver === 'undefined') { cb(); return; }
  #|  const obs = new IntersectionObserver((entries) => {
  #|    for (const en of entries) {
  #|      if (en.isIntersecting) { obs.disconnect(); cb(); return; }
  #|    }
  #|  }, { threshold: 0.1 });
  #|  obs.observe(el);
  #|}

///|
/// Setup video settings panel (scene threshold / stabilization buttons) - MoonBit native
fn setup_video_settings_moonbit(
  overlay : Element,
  container : Element,
  fs_counter : Element,
) -> Unit {
  let settings_btn = query("#video-settings-btn")
  let settings_panel = query("#video-settings-panel")
  let scene_buttons_div = query("#scene-buttons")
  let stab_buttons_div = query("#stab-buttons")
  if is_null(settings_btn) || is_null(settings_panel) {
    return
  }
  // Toggle panel
  on(settings_btn, "click", fn(e) {
    stop_propagation(e)
    toggle_class(settings_panel, "visible")
  })
  on(settings_panel, "click", fn(e) { stop_propagation(e) })
  // Scene threshold buttons
  if !is_null(scene_buttons_div) {
    let btns = query_all_in(scene_buttons_div, "button")
    for btn in btns {
      on(btn, "click", fn(_e) {
        let all = query_all_in(scene_buttons_div, "button")
        for b in all {
          remove_class(b, "selected")
        }
        add_class(btn, "selected")
        let val = get_attr(btn, "data-scene")
        current_scene_threshold.val = parse_float(val)
        regenerate_timeline_moonbit(overlay, container, fs_counter)
      })
    }
  }
  // Stabilization threshold buttons
  if !is_null(stab_buttons_div) {
    let btns = query_all_in(stab_buttons_div, "button")
    for btn in btns {
      on(btn, "click", fn(_e) {
        let all = query_all_in(stab_buttons_div, "button")
        for b in all {
          remove_class(b, "selected")
        }
        add_class(btn, "selected")
        let val = get_attr(btn, "data-stab")
        current_stab_threshold.val = parse_float(val)
        regenerate_timeline_moonbit(overlay, container, fs_counter)
      })
    }
  }
}

///|
/// Regenerate video timeline with updated thresholds (MoonBit native)
fn regenerate_timeline_moonbit(
  _overlay : Element,
  container : Element,
  _fs_counter : Element,
) -> Unit {
  if current_video_path.val.length() == 0 {
    return
  }
  let vid = query_in(container, "video")
  if is_null(vid) {
    return
  }
  // Destroy old timeline and recreate
  if fs_video_timeline.val is Some(_) {
    let new_vtl = recreate_timeline(
      fs_video_timeline.val.unwrap(),
      current_scene_threshold.val,
      current_stab_threshold.val,
    )
    fs_video_timeline.val = Some(new_vtl)
  }
}

///|
/// Show video in fullscreen with pure MoonBit VideoTimeline
fn show_video_fullscreen_moonbit(
  videos : Array[Element],
  index : Int,
  overlay : Element,
  container : Element,
  fs_counter : Element,
) -> Unit {
  if index < 0 || index >= videos.length() {
    return
  }
  close_inline_comment_before_fullscreen()
  current_video_index.val = index
  // Cleanup previous timeline
  if fs_video_timeline.val is Some(_) {
    destroy_video_timeline(fs_video_timeline.val.unwrap())
    fs_video_timeline.val = None
  }
  // Remove existing video
  let existing_vid = query_in(container, "video")
  if !is_null(existing_vid) {
    video_pause(existing_vid)
    remove_element(existing_vid)
  }
  // Create new video element dynamically
  let vid = videos[index]
  let src = get_src(vid)
  let new_video = create_video_element(src)
  append_child(container, new_video)
  // Update counter
  if !is_null(fs_counter) {
    set_text_content(
      fs_counter,
      (index + 1).to_string() + " / " + videos.length().to_string(),
    )
  }
  // Create timeline — use pathname only (get_src returns full URL)
  let video_path = url_to_pathname(src)
  current_video_path.val = video_path
  let vtl = create_video_timeline_moonbit(
    new_video,
    container,
    video_path,
    current_scene_threshold.val,
    current_stab_threshold.val,
    true,
  )
  fs_video_timeline.val = Some(vtl)
  show_overlay(overlay)
  // Close settings panel when opening new video
  let settings_panel = query("#video-settings-panel")
  if !is_null(settings_panel) {
    remove_class(settings_panel, "visible")
  }
}

///|
/// Navigate video fullscreen by direction (-1=prev, 1=next)
fn navigate_video_fullscreen_moonbit(
  direction : Int,
  overlay : Element,
  container : Element,
  fs_counter : Element,
) -> Unit {
  let preview = query("#md-preview")
  if is_null(preview) {
    return
  }
  let all_videos = query_all_in(preview, "video")
  if all_videos.length() == 0 {
    return
  }
  let new_idx = current_video_index.val + direction
  if new_idx >= 0 && new_idx < all_videos.length() {
    show_video_fullscreen_moonbit(
      all_videos, new_idx, overlay, container, fs_counter,
    )
  }
}

///|
/// Close video fullscreen and pause video (MoonBit native)
fn close_video_fullscreen_moonbit(
  overlay : Element,
  container : Element,
) -> Unit {
  // Pause and remove video
  let vid = query_in(container, "video")
  if !is_null(vid) {
    video_pause(vid)
    remove_element(vid)
  }
  // Cleanup timeline
  if fs_video_timeline.val is Some(_) {
    destroy_video_timeline(fs_video_timeline.val.unwrap())
    fs_video_timeline.val = None
  }
  current_video_index.val = -1
  current_video_path.val = ""
  hide_overlay(overlay)
}

///|
/// Entry point: auto-init on module load
fn main {
  init_app()
}
