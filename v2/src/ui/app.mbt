///|
/// Comment stored in the app
struct AppComment {
  row : Int
  col : Int
  mut text : String
  mut image : String
}

///|
struct Rect {
  left : Double
  top : Double
  width : Double
  height : Double
}

///|
struct CardPlacement {
  left : Double
  top : Double
  overlap_area : Double
  overflow_penalty : Double
}

///|
/// Application state
let comments : Map[String, AppComment] = {}

///|
/// Currently active comment card target
let active_key : Ref[String] = Ref("")

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
let review_tab_id : Ref[String] = Ref("")

///|
let page_instance_id : Ref[String] = Ref("")

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
fn rect_right(rect : Rect) -> Double {
  rect.left + rect.width
}

///|
fn rect_bottom(rect : Rect) -> Double {
  rect.top + rect.height
}

///|
fn viewport_rect() -> Rect {
  Rect::{
    left: 0.0,
    top: 0.0,
    width: window_inner_width().to_double(),
    height: window_inner_height().to_double(),
  }
}

///|
fn rect_from_element(el : Element) -> Rect {
  let rect = get_bounding_rect(el)
  Rect::{ left: rect[0], top: rect[1], width: rect[2], height: rect[3] }
}

///|
fn clamp_card_coord(
  value : Double,
  min_value : Double,
  max_value : Double,
) -> Double {
  if value < min_value {
    min_value
  } else if value > max_value {
    max_value
  } else {
    value
  }
}

///|
fn rect_intersection_area(a : Rect, b : Rect) -> Double {
  let overlap_left = if a.left > b.left { a.left } else { b.left }
  let overlap_top = if a.top > b.top { a.top } else { b.top }
  let overlap_right = if rect_right(a) < rect_right(b) {
    rect_right(a)
  } else {
    rect_right(b)
  }
  let overlap_bottom = if rect_bottom(a) < rect_bottom(b) {
    rect_bottom(a)
  } else {
    rect_bottom(b)
  }
  let overlap_width = overlap_right - overlap_left
  let overlap_height = overlap_bottom - overlap_top
  if overlap_width > 0.0 && overlap_height > 0.0 {
    overlap_width * overlap_height
  } else {
    0.0
  }
}

///|
fn rect_union(a : Rect, b : Rect) -> Rect {
  let left = if a.left < b.left { a.left } else { b.left }
  let top = if a.top < b.top { a.top } else { b.top }
  let right = if rect_right(a) > rect_right(b) {
    rect_right(a)
  } else {
    rect_right(b)
  }
  let bottom = if rect_bottom(a) > rect_bottom(b) {
    rect_bottom(a)
  } else {
    rect_bottom(b)
  }
  Rect::{ left, top, width: right - left, height: bottom - top }
}

///|
fn bounds_overflow_penalty(
  rect : Rect,
  bounds : Rect,
  margin : Double,
) -> Double {
  let overflow_left = if rect.left < bounds.left + margin {
    bounds.left + margin - rect.left
  } else {
    0.0
  }
  let overflow_top = if rect.top < bounds.top + margin {
    bounds.top + margin - rect.top
  } else {
    0.0
  }
  let overflow_right = if rect_right(rect) > rect_right(bounds) - margin {
    rect_right(rect) - (rect_right(bounds) - margin)
  } else {
    0.0
  }
  let overflow_bottom = if rect_bottom(rect) > rect_bottom(bounds) - margin {
    rect_bottom(rect) - (rect_bottom(bounds) - margin)
  } else {
    0.0
  }
  overflow_left + overflow_top + overflow_right + overflow_bottom
}

///|
fn make_card_candidate(
  _anchor : Rect,
  keepout : Rect,
  bounds : Rect,
  card_width : Double,
  card_height : Double,
  desired_left : Double,
  desired_top : Double,
  margin : Double,
) -> CardPlacement {
  let min_left = bounds.left + margin
  let min_top = bounds.top + margin
  let max_left = rect_right(bounds) - card_width - margin
  let max_top = rect_bottom(bounds) - card_height - margin
  let left = clamp_card_coord(
    desired_left,
    min_left,
    if max_left > min_left {
      max_left
    } else {
      min_left
    },
  )
  let top = clamp_card_coord(
    desired_top,
    min_top,
    if max_top > min_top {
      max_top
    } else {
      min_top
    },
  )
  let rect = Rect::{ left, top, width: card_width, height: card_height }
  CardPlacement::{
    left,
    top,
    overlap_area: rect_intersection_area(keepout, rect),
    overflow_penalty: bounds_overflow_penalty(rect, bounds, margin),
  }
}

///|
fn placement_score(candidate : CardPlacement) -> Double {
  candidate.overlap_area * 1000.0 + candidate.overflow_penalty
}

///|
fn choose_card_placement(
  anchor : Rect,
  keepout : Rect,
  bounds : Rect,
  card_width : Double,
  card_height : Double,
  prefer_below : Bool,
) -> CardPlacement {
  let margin = 12.0
  let mid_left = anchor.left + (anchor.width - card_width) / 2.0
  let below = make_card_candidate(
    anchor,
    keepout,
    bounds,
    card_width,
    card_height,
    mid_left,
    rect_bottom(anchor) + margin,
    margin,
  )
  let above = make_card_candidate(
    anchor,
    keepout,
    bounds,
    card_width,
    card_height,
    mid_left,
    anchor.top - card_height - margin,
    margin,
  )
  let right_side = make_card_candidate(
    anchor,
    keepout,
    bounds,
    card_width,
    card_height,
    rect_right(anchor) + margin,
    anchor.top,
    margin,
  )
  let left_side = make_card_candidate(
    anchor,
    keepout,
    bounds,
    card_width,
    card_height,
    anchor.left - card_width - margin,
    anchor.top,
    margin,
  )
  let center = make_card_candidate(
    anchor,
    keepout,
    bounds,
    card_width,
    card_height,
    bounds.left + (bounds.width - card_width) / 2.0,
    bounds.top + (bounds.height - card_height) / 2.0,
    margin,
  )
  let candidates = if prefer_below {
    [below, above, right_side, left_side, center]
  } else {
    [right_side, left_side, below, above, center]
  }
  let mut best = candidates[0]
  let mut best_score = placement_score(best)
  for candidate in candidates {
    let score = placement_score(candidate)
    if score < best_score {
      best = candidate
      best_score = score
    }
  }
  best
}

///|
fn choose_keepout_escape_placement(
  keepout : Rect,
  bounds : Rect,
  card_width : Double,
  card_height : Double,
  fallback : CardPlacement,
) -> CardPlacement {
  if fallback.overlap_area == 0.0 {
    return fallback
  }
  let margin = 12.0
  let centered_left = keepout.left + (keepout.width - card_width) / 2.0
  let centered_top = keepout.top + (keepout.height - card_height) / 2.0
  let candidates = [
    make_card_candidate(
      keepout,
      keepout,
      bounds,
      card_width,
      card_height,
      centered_left,
      keepout.top - card_height - margin,
      margin,
    ),
    make_card_candidate(
      keepout,
      keepout,
      bounds,
      card_width,
      card_height,
      centered_left,
      rect_bottom(keepout) + margin,
      margin,
    ),
    make_card_candidate(
      keepout,
      keepout,
      bounds,
      card_width,
      card_height,
      keepout.left - card_width - margin,
      centered_top,
      margin,
    ),
    make_card_candidate(
      keepout,
      keepout,
      bounds,
      card_width,
      card_height,
      rect_right(keepout) + margin,
      centered_top,
      margin,
    ),
    fallback,
  ]
  let mut best = candidates[0]
  let mut best_score = placement_score(best)
  for candidate in candidates {
    let score = placement_score(candidate)
    if score < best_score {
      best = candidate
      best_score = score
    }
  }
  best
}

///|
fn position_comment_card_for_rects(
  card : Element,
  anchor : Rect,
  keepout : Rect,
  bounds : Rect,
  prefer_below : Bool,
) -> Unit {
  set_style(card, "display", "block")
  set_style(card, "visibility", "hidden")
  let card_width = get_bounding_rect_width(card)
  let card_height = get_bounding_rect_height(card)
  let placement = choose_card_placement(
    anchor, keepout, bounds, card_width, card_height, prefer_below,
  )
  let resolved = choose_keepout_escape_placement(
    keepout, bounds, card_width, card_height, placement,
  )
  set_style(card, "top", "\{resolved.top.to_int()}px")
  set_style(card, "left", "\{resolved.left.to_int()}px")
  set_style(card, "visibility", "visible")
}

///|
fn position_comment_card(
  card : Element,
  target : Element,
  prefer_below : Bool,
) -> Unit {
  let anchor = rect_from_element(target)
  let bounds = viewport_rect()
  position_comment_card_for_rects(card, anchor, anchor, bounds, prefer_below)
}

///|
fn rect_union_of_elements(elements : Array[Element]) -> Rect? {
  let mut union_rect : Rect? = None
  for el in elements {
    if !is_null(el) {
      let rect = rect_from_element(el)
      union_rect = match union_rect {
        Some(existing) => Some(rect_union(existing, rect))
        None => Some(rect)
      }
    }
  }
  union_rect
}

///|
fn populate_comment_card(
  target : Element,
  key : String,
  row : Int,
  col : Int,
  textarea : Element,
) -> Unit {
  active_key.val = key
  let card_title = query("#card-title")
  let cell_preview = query("#cell-preview")
  if !is_null(card_title) {
    if col > 0 {
      set_text_content(card_title, "Comment on R\{row} C\{col}")
    } else if row > 0 {
      set_text_content(card_title, "Comment on line \{row}")
    } else {
      set_text_content(card_title, "Cell Comment")
    }
  }
  if !is_null(cell_preview) {
    let content = resolve_comment_target_preview(target)
    if content.length() > 0 {
      let preview = if col > 0 {
        "Cell value: " + truncate(content, 80)
      } else {
        truncate(content, 80)
      }
      set_text_content(cell_preview, preview)
    } else {
      set_text_content(cell_preview, "(empty)")
    }
  }
  match comments.get(key) {
    Some(comment) => {
      set_value(textarea, comment.text)
      current_comment_image.val = comment.image
    }
    None => {
      set_value(textarea, "")
      current_comment_image.val = ""
      comments.set(key, { row, col, text: "", image: "" })
    }
  }
  render_comment_image_preview()
}

///|
fn resolve_comment_target_preview(target : Element) -> String {
  if is_null(target) {
    return ""
  }
  let content = get_text_content(target)
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
  if has_class(target, "mermaid-container") {
    return "Mermaid diagram"
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
    return "Mermaid diagram"
  }
  ""
}

///|
fn show_comment_card_in_rects(
  target : Element,
  key : String,
  row : Int,
  col : Int,
  anchor : Rect,
  keepout : Rect,
  bounds : Rect,
  prefer_below : Bool,
) -> Unit {
  let card = query("#comment-card")
  let textarea = query("#comment-input")
  if is_null(card) || is_null(textarea) {
    return
  }
  populate_comment_card(target, key, row, col, textarea)
  position_comment_card_for_rects(card, anchor, keepout, bounds, prefer_below)
  focus_element(textarea)
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
  // Restore theme from localStorage
  let saved_theme = local_storage_get("yunomi:theme")
  if saved_theme.length() > 0 {
    set_theme(saved_theme)
    toggle_hljs_theme(saved_theme)
    update_theme_button(saved_theme)
  }
  // Setup theme toggle with localStorage persistence
  let theme_btn = query("#theme-toggle")
  if !is_null(theme_btn) {
    on(theme_btn, "click", fn(_e) {
      let current = get_theme()
      if current == "dark" {
        set_theme("light")
        toggle_hljs_theme("light")
        local_storage_set("yunomi:theme", "light")
        update_theme_button("light")
      } else {
        set_theme("dark")
        toggle_hljs_theme("dark")
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
  // Setup comment card buttons
  let close_btn = query("#close-card")
  if !is_null(close_btn) {
    on(close_btn, "click", fn(_e) { hide_comment_card() })
  }
  let clear_btn = query("#clear-comment")
  if !is_null(clear_btn) {
    on(clear_btn, "click", fn(_e) {
      let textarea = query("#comment-input")
      if !is_null(textarea) {
        set_value(textarea, "")
      }
      save_comment()
    })
  }
  let save_btn = query("#save-comment")
  if !is_null(save_btn) {
    on(save_btn, "click", fn(_e) { save_comment() })
  }
  let comment_input = query("#comment-input")
  if !is_null(comment_input) {
    on(comment_input, "keydown", fn(e) {
      if event_key(e) == "Enter" && (event_meta_key(e) || event_ctrl_key(e)) {
        prevent_default(e)
        stop_propagation(e)
        save_comment()
      }
    })
  }
  // Copy selection button (cli.cjs compatible)
  let copy_btn = query("#copy-selection")
  if !is_null(copy_btn) {
    on(copy_btn, "click", fn(_e) {
      let cell_preview = query("#cell-preview")
      let text = if !is_null(cell_preview) {
        get_text_content(cell_preview)
      } else {
        ""
      }
      if text.length() > 0 {
        copy_to_clipboard(text)
        show_toast("Copied!")
      } else {
        show_toast("No content to copy")
      }
    })
  }
  // Setup modal buttons
  let modal_cancel = query("#modal-cancel")
  if !is_null(modal_cancel) {
    on(modal_cancel, "click", fn(_e) { hide_submit_modal() })
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
      // If comment card is open, save comment
      let card = query("#comment-card")
      if !is_null(card) && !is_element_hidden(card) {
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
    }
    if event_key(e) == "Escape" {
      hide_comment_card()
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
    "csv" => {
      setup_csv_clicks()
      init_csv_resizers_and_filters()
    }
    "diff" => setup_diff_clicks()
    "markdown" => setup_csv_clicks()
    _ => setup_text_clicks()
  }
  // Setup scroll sync and preview click for markdown mode
  if mode == "markdown" {
    setup_scroll_sync()
    setup_preview_click()
    setup_preview_mouseup()
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
fn setup_csv_clicks() -> Unit {
  let cells = query_all("td[data-row]")
  for cell in cells {
    on(cell, "click", fn(e) {
      if is_dragging.val {
        return
      }
      let target = event_target(e)
      let row_str = get_attr(target, "data-row")
      let col_str = get_attr(target, "data-col")
      let key = "\{row_str}:\{col_str}"
      show_comment_card(target, key, str_to_int(row_str), str_to_int(col_str))
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
  for line in lines {
    on(line, "click", fn(e) {
      let target = closest(event_target(e), ".diff-line")
      if !is_null(target) {
        let file = get_attr(target, "data-file")
        let content = get_text_content(target)
        let key = "\{file}:\{truncate(content, 20)}"
        show_comment_card(target, key, 0, 0)
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
        show_comment_card(target, key, str_to_int(row_str), 0)
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
/// Check for saved comments and show recovery modal (with TTL validation)
fn check_recovery() -> Unit {
  let key = get_storage_key()
  let stored = ls_get(key)
  if stored.length() == 0 {
    return
  }
  if is_storage_expired(stored) {
    ls_remove(key)
    return
  }
  let modal = query("#recovery-modal")
  if !is_null(modal) {
    add_class(modal, "visible")
    remove_class(modal, "hidden")
  }
}

///|
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
        if text.length() > 0 {
          comments.set(k, { row, col, text, image: "" })
        }
      }
    }
    update_comment_indicators()
  }
  hide_recovery_modal()
}

///|
fn discard_comments() -> Unit {
  ls_remove(get_storage_key())
  hide_recovery_modal()
}

///|
fn hide_recovery_modal() -> Unit {
  let modal = query("#recovery-modal")
  if !is_null(modal) {
    remove_class(modal, "visible")
    add_class(modal, "hidden")
  }
}

///|
fn show_comment_card(
  target : Element,
  key : String,
  row : Int,
  col : Int,
) -> Unit {
  let card = query("#comment-card")
  let textarea = query("#comment-input")
  if is_null(card) || is_null(textarea) {
    return
  }
  populate_comment_card(target, key, row, col, textarea)
  position_comment_card(card, target, true)
  focus_element(textarea)
}

///|
fn hide_comment_card() -> Unit {
  let card = query("#comment-card")
  if !is_null(card) {
    set_style(card, "display", "none")
  }
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
  let line_cell = query("td[data-row=\"\{comment.row}\"][data-col=\"1\"]")
  if !is_null(line_cell) {
    return line_cell
  }
  let text_line = query(".text-line[data-row=\"\{comment.row}\"]")
  if !is_null(text_line) {
    return text_line
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
            show_comment_card(comment_target, key, comment.row, comment.col)
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
        // Send real-time comment to server
        send_comment_to_server(
          comment.row,
          comment.col,
          text,
          if is_delete {
            "delete"
          } else {
            "comment"
          },
          key,
          current_comment_image.val.length() > 0,
        )
        comment.text = text
        comment.image = current_comment_image.val
      }
      None =>
        // New comment that's being deleted immediately — still send delete
        if is_delete {
          send_comment_to_server(0, 0, "", "delete", key, false)
        }
    }
    if is_delete {
      ignore(comments.remove(key))
    }
  }
  current_comment_image.val = ""
  hide_comment_card()
  update_comment_indicators()
  persist_comments()
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
  let mut count = 0
  comments.each(fn(_key, comment) {
    if comment_has_content(comment) {
      count = count + 1
      let el = resolve_comment_indicator_target(comment)
      if !is_null(el) {
        add_class(el, "has-comment")
      }
    }
  })
  // Update comment count badge
  let count_el = query("#comment-count")
  if !is_null(count_el) {
    set_text_content(count_el, count.to_string())
  }
  render_comment_list()
}

///|
fn show_submit_modal() -> Unit {
  let modal = query("#submit-modal")
  let list = query("#modal-summary")
  if is_null(modal) || is_null(list) {
    return
  }
  let buf = StringBuilder::new()
  comments.each(fn(key, comment) {
    if comment.text.length() > 0 {
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
      if text.length() == 0 && current_comment_image.val.length() == 0 {
        ignore(comments.remove(key))
      }
    }
    None => ()
  }
  update_comment_indicators()
  persist_comments()
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
    if comment.text.length() > 0 {
      if !first.val {
        buf.write_char(',')
      }
      buf.write_string("{\"row\":")
      buf.write_string(comment.row.to_string())
      buf.write_string(",\"col\":")
      buf.write_string(comment.col.to_string())
      buf.write_string(",\"text\":")
      buf.write_string(json_encode_string(comment.text))
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
  fetch_post(url, build_review_payload(), fn(_response) {
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

///| Server instance id from the first SSE hello; a different id on reconnect
/// means a NEW server reused this port. A lingering old tab must not join the
/// new review, otherwise closing one tab can make other stale tabs reappear.
let sse_server_instance : Ref[String] = Ref("")

///|
fn setup_sse(_port : Int) -> Unit {
  let url = location_origin() + "/sse"
  let es = new_event_source(url)
  sse_on(es, "reload", fn(_e) { location_reload() })
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
/// Save comments to localStorage in cli.cjs-compatible { comments, timestamp } format
fn persist_comments() -> Unit {
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
    buf.write_char('}')
    first.val = false
  })
  buf.write_string("},\"timestamp\":")
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
    let comment_card = query("#comment-card")
    let submit_visible = !is_null(submit_modal) &&
      (
        get_attr(submit_modal, "class").contains("visible") ||
        get_computed_style(submit_modal, "display") != "none"
      )
    let comment_visible = !is_null(comment_card) &&
      (
        get_attr(comment_card, "class").contains("visible") ||
        get_computed_style(comment_card, "display") != "none"
      )
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
          let cell = query("td[data-row=\"\{anchor.line}\"][data-col=\"1\"]")
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
        let cell = query("td[data-row=\"\{anchor.line}\"][data-col=\"1\"]")
        if !is_null(cell) {
          get_offset_top(cell)
        } else {
          0.0
        }
      }
      let tgt_anchor_pos = if source_name == "left" {
        let cell = query("td[data-row=\"\{anchor.line}\"][data-col=\"1\"]")
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
/// Drag selection: finish and open comment card
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
  let target_el = query("[data-row=\"" + start.to_string() + "\"]")
  if !is_null(target_el) {
    show_comment_card(target_el, key, start, 0)
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
    let el = query("[data-row=\"" + r.to_string() + "\"]")
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
      let row_el = closest(el, "[data-row]")
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
  let text = normalize_text(get_text_content(block))
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
fn get_comment_bounds_rect(source_hidden : Bool) -> Rect {
  if source_hidden {
    // In preview-only mode the card must never cover the selected preview target,
    // so allow it to escape to the full viewport instead of trapping it in the pane.
    viewport_rect()
  } else {
    let md_right = query(".md-right")
    if !is_null(md_right) && !is_element_hidden(md_right) {
      rect_from_element(md_right)
    } else {
      viewport_rect()
    }
  }
}

///|
fn get_selected_source_rect() -> Rect? {
  rect_union_of_elements(query_all(".md-right td.selected"))
}

///|
/// Select source range and open comment card (mirrors cli.cjs selectSourceRange)
fn select_source_range(
  start_row : Int,
  end_row : Int,
  preview_el : Element,
  col? : Int = 0,
) -> Unit {
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
    let cell = query("td[data-row=\"\{row_idx}\"][data-col=\"1\"]")
    if !is_null(cell) {
      add_class(cell, "selected")
    }
  }
  // Scroll source pane to target row
  let md_right = query(".md-right")
  if !is_null(md_right) {
    let target_row = start_row - 1
    let target_cell = query("td[data-row=\"\{target_row}\"][data-col=\"1\"]")
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
  // Open comment card
  let key = if start_row == actual_end {
    (start_row - 1).to_string() + ":" + col.to_string()
  } else {
    (start_row - 1).to_string() + "-" + (actual_end - 1).to_string()
  }
  let source_target = query("td[data-row=\"\{start_row - 1}\"][data-col=\"1\"]")
  // Position card: check if source is hidden (preview-only mode)
  let is_source_hidden = !is_null(md_right) && is_element_hidden(md_right)
  if is_source_hidden && !is_null(preview_el) {
    let preview_rect = rect_from_element(preview_el)
    let bounds = get_comment_bounds_rect(true)
    show_comment_card_in_rects(
      preview_el,
      key,
      start_row - 1,
      col,
      preview_rect,
      preview_rect,
      bounds,
      true,
    )
  } else {
    let target = if !is_null(source_target) {
      source_target
    } else if !is_null(preview_el) {
      preview_el
    } else {
      source_target
    }
    if !is_null(target) {
      let keepout = match get_selected_source_rect() {
        Some(rect) => rect
        None => rect_from_element(target)
      }
      let bounds = get_comment_bounds_rect(false)
      show_comment_card_in_rects(
        target,
        key,
        start_row - 1,
        col,
        keepout,
        keepout,
        bounds,
        true,
      )
    }
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
/// Show comment card below element (for preview-only mode)
fn _show_comment_card_below(
  target : Element,
  key : String,
  row : Int,
  col : Int,
) -> Unit {
  let target_rect = rect_from_element(target)
  show_comment_card_in_rects(
    target,
    key,
    row,
    col,
    target_rect,
    target_rect,
    viewport_rect(),
    true,
  )
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
    if !is_null(closest(target, ".mermaid-fullscreen-btn")) {
      return
    }
    let mermaid_range = get_mermaid_source_range(target)
    if mermaid_range.0 > 0 {
      select_source_range(
        mermaid_range.0,
        mermaid_range.1,
        closest(target, ".mermaid-container"),
      )
      return
    }
    let tag = get_tag_name(target)
    // Image click
    if tag == "IMG" {
      let src = get_src(target)
      let heading = find_closest_heading_above(target)
      let h_line = get_heading_source_line(heading)
      let line = find_image_source_line(src, h_line)
      if line > 0 {
        select_source_range(line, line, target)
      }
      return
    }
    // Code block click (<pre> or <code> inside <pre>)
    let pre = closest(target, "pre")
    if !is_null(pre) {
      let code_text = get_text_content(pre)
      let range = find_code_block_range(code_text)
      if range.0 > 0 {
        select_source_range(range.0, range.1, pre)
      }
      return
    }
    // Generic block element click
    let block = resolve_preview_click_block(target)
    if !is_null(block) {
      let heading = find_closest_heading_above(block)
      let h_line = get_heading_source_line(heading)
      let media_line = find_media_source_line_in_block(block, h_line)
      if media_line > 0 {
        let media_anchor = resolve_preview_media_anchor(block)
        select_source_range(media_line, media_line, media_anchor)
        return
      }
      let text = resolve_preview_block_text(block)
      if text.length() == 0 {
        return
      }
      let block_tag = get_tag_name(block)
      let line = if block_tag == "TD" || block_tag == "TH" {
        find_table_source_line(text, h_line)
      } else {
        find_source_line(text, block, h_line)
      }
      if line > 0 {
        let cell_col = if block_tag == "TD" || block_tag == "TH" {
          get_cell_index(block) + 1 // 1-indexed: col=0 is line comment, col>=1 is cell comment
        } else {
          0
        }
        select_source_range(line, line, block, col=cell_col)
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
/// Setup questions UI (overlay, bar, auto-popup, answer tracking)
fn setup_questions_ui() -> Unit {
  let overlay = query("#yunomi-questions-overlay")
  let _bar = query("#yunomi-questions-bar")
  if is_null(overlay) {
    return
  }
  // Close button
  let close_btn = query("#yunomi-questions-close")
  if !is_null(close_btn) {
    on(close_btn, "click", fn(_e) { close_questions_modal(false) })
  }
  // Later button
  let later_btn = query("#yunomi-questions-later")
  if !is_null(later_btn) {
    on(later_btn, "click", fn(_e) { close_questions_modal(false) })
  }
  // Bar open button
  let bar_open = query("#yunomi-questions-bar-open")
  if !is_null(bar_open) {
    on(bar_open, "click", fn(_e) { open_questions_modal() })
  }
  // Click overlay background to close
  on(overlay, "click", fn(e) {
    if elem_eq(event_target(e), overlay) {
      close_questions_modal(false)
    }
  })
  // Escape to close
  on_doc("keydown", fn(e) {
    if event_key(e) == "Escape" {
      let ov = query("#yunomi-questions-overlay")
      if !is_null(ov) && has_class(ov, "visible") {
        close_questions_modal(false)
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
      update_questions_count()
    })
  }
  // Setup answer textareas
  let answer_areas = query_all(".q-answer")
  for area in answer_areas {
    on(area, "input", fn(_e) { update_questions_count() })
  }
  // Resolved toggle
  let resolved_toggle = query(".yunomi-resolved-toggle")
  if !is_null(resolved_toggle) {
    on(resolved_toggle, "click", fn(_e) {
      if has_class(resolved_toggle, "open") {
        remove_class(resolved_toggle, "open")
      } else {
        add_class(resolved_toggle, "open")
      }
    })
  }
  // Auto-popup if there are unresolved questions
  let count_el = query("#yunomi-questions-bar-count")
  if !is_null(count_el) {
    let count_text = get_text_content(count_el)
    if count_text != "0" {
      // Auto-open after short delay
      ignore(set_timeout(fn() { open_questions_modal() }, 500))
    }
  }
}

///|
/// Open questions modal
fn open_questions_modal() -> Unit {
  let overlay = query("#yunomi-questions-overlay")
  if !is_null(overlay) {
    add_class(overlay, "visible")
  }
  let bar = query("#yunomi-questions-bar")
  if !is_null(bar) {
    remove_class(bar, "visible")
    remove_class_body("has-questions-bar")
  }
}

///|
/// Close questions modal
fn close_questions_modal(_all_answered : Bool) -> Unit {
  let overlay = query("#yunomi-questions-overlay")
  if !is_null(overlay) {
    remove_class(overlay, "visible")
  }
  // Show bar if there are unanswered questions
  let unanswered = count_unanswered_questions()
  let bar = query("#yunomi-questions-bar")
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
/// Update questions count display
fn update_questions_count() -> Unit {
  let unanswered = count_unanswered_questions()
  let count_el = query("#yunomi-questions-count")
  if !is_null(count_el) {
    if unanswered > 0 {
      set_inner_html(count_el, "(" + unanswered.to_string() + ")")
    } else {
      set_inner_html(count_el, "")
    }
  }
  let bar_count = query("#yunomi-questions-bar-count")
  if !is_null(bar_count) {
    set_inner_html(bar_count, unanswered.to_string())
  }
  // Auto-close if all answered
  if unanswered == 0 {
    ignore(set_timeout(fn() { close_questions_modal(true) }, 500))
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
