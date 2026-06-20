///| HeadingToggles — Pure MoonBit implementation
///  Handles details/summary processing for collapsible sections
///  Replaces JS-based heading toggle initialization

///|
/// Toggle state for a heading section
struct HeadingToggle {
  original_heading : Element
  details_el : Element
  summary_el : Element
  content_el : Element
  mut is_open : Bool
  handles : Array[ListenerHandle]
  content_nodes : Array[Element]
}

///|
/// Configuration for heading toggles
struct ToggleConfig {
  start_level : Int // H2, H3, etc. (default: 2)
  end_level : Int // Up to H6 (default: 6)
  initially_open : Bool
}

///|
/// Default configuration
fn default_toggle_config() -> ToggleConfig {
  ToggleConfig::{ start_level: 1, end_level: 6, initially_open: true }
}

///|
/// All active toggle instances on the page
let active_toggles : Ref[Array[HeadingToggle]] = Ref([])

///|
/// Initialize heading toggles for the current page
pub fn init_heading_toggles(config? : ToggleConfig) -> Unit {
  let cfg = match config {
    Some(c) => c
    None => default_toggle_config()
  }

  // Clear existing toggles
  destroy_all_toggles()

  // Find markdown preview container
  let preview = query(".md-preview")
  if is_null(preview) {
    return
  }

  // Find all headings in the specified range
  let heading_selectors : Array[String] = []
  for level = cfg.start_level; level <= cfg.end_level; level = level + 1 {
    heading_selectors.push("h" + level.to_string() + ".md-heading-toggle")
  }
  let selector = join_strings(heading_selectors, ",")

  let headings = query_all_in(preview, selector)
  if headings.is_empty() {
    return
  }

  // Process each heading
  headings.each(fn(heading) { process_heading(heading, cfg) })

  // Setup intersection observer for auto-scroll
  setup_heading_observer()
}

///|
/// Process a single heading element
fn process_heading(heading : Element, config : ToggleConfig) -> Unit {
  let parent = parent_element(heading)
  if is_null(parent) {
    return
  }

  // Get heading level
  let tag = get_tag_name(heading)
  let level_str = tag[1:].to_owned() // "H2" -> "2"
  let level = @core.parse_int_safe(level_str)

  // Find content to wrap (siblings until next heading of same or higher level)
  let content_els = collect_toggle_content(heading, level)
  if content_els.is_empty() {
    return
  }

  // Create details/summary structure
  let details = create_element("details")
  set_class_name(details, "heading-toggle")
  set_attribute(details, "data-level", level.to_string())

  if config.initially_open {
    set_attribute(details, "open", "")
  }

  // Create summary (the heading itself becomes clickable)
  let summary = create_element("summary")
  set_class_name(summary, "heading-summary")
  let original_heading = heading

  // Create content container
  let content = create_element("div")
  set_class_name(content, "toggle-content")
  let icon = ensure_toggle_icon(heading, config.initially_open)

  // Build structure
  insert_before(heading, details)
  append_child(details, summary)
  append_child(summary, icon)
  append_child(summary, heading)
  append_child(details, content)
  content_els.each(fn(el) { append_child(content, el) })

  // Create toggle state
  let toggle = HeadingToggle::{
    original_heading,
    details_el: details,
    summary_el: summary,
    content_el: content,
    is_open: config.initially_open,
    handles: [],
    content_nodes: content_els,
  }

  let stored = ls_get(toggle_storage_key(toggle))
  if stored == "collapsed" {
    toggle.is_open = false
    remove_attribute(details, "open")
  }

  // Setup event handlers
  setup_toggle_handlers(toggle, config)
  update_toggle_state(toggle, config)

  // Store toggle
  active_toggles.val.push(toggle)
}

///|
/// Collect content elements between this heading and next same/higher level heading
fn collect_toggle_content(heading : Element, level : Int) -> Array[Element] {
  let content = []
  let mut current = next_element_sibling(heading)

  while !is_null(current) {
    let tag = get_tag_name(current)

    // Check if this is a heading of same or higher (lower number) level
    if tag.has_prefix("H") && tag.length() == 2 {
      let h_level = @core.parse_int_safe(tag[1:].to_owned())
      if h_level <= level {
        break
      }
    }

    // Check if this is already a toggle (avoid nesting issues)
    if has_class(current, "heading-toggle") {
      break
    }

    content.push(current)
    current = next_element_sibling(current)
  }

  content
}

///|
/// Create toggle icon element
fn create_toggle_icon(is_open : Bool) -> Element {
  let icon = create_element("span")
  set_class_name(icon, "heading-toggle-icon")
  set_text_content(icon, if is_open { "▼" } else { "▶" })
  icon
}

///|
/// Reuse the heading icon when available, otherwise inject a fallback icon
fn ensure_toggle_icon(heading : Element, is_open : Bool) -> Element {
  let icon = query_in(heading, ".heading-toggle-icon")
  if !is_null(icon) {
    set_text_content(icon, if is_open { "▼" } else { "▶" })
    remove_class(icon, "collapsed")
    icon
  } else {
    create_toggle_icon(is_open)
  }
}

///|
/// Setup event handlers for a toggle
fn setup_toggle_handlers(toggle : HeadingToggle, config : ToggleConfig) -> Unit {
  let summary_click = on_with_handle(
    toggle.summary_el,
    "click",
    fn(e) {
      let target = event_target(e)
      let icon = closest(target, ".heading-toggle-icon")
      prevent_default(e)
      if !is_null(icon) {
        stop_propagation(e)
        set_toggle_open(toggle, !toggle.is_open, config)
      }
    },
    passive=false,
  )
  toggle.handles.push(summary_click)
  let summary_keydown = on_with_handle(
    toggle.summary_el,
    "keydown",
    fn(e) {
      let key = event_key(e)
      if key == "Enter" || key == " " || key == "Spacebar" {
        prevent_default(e)
        stop_propagation(e)
        set_toggle_open(toggle, !toggle.is_open, config)
      }
    },
    passive=false,
  )
  toggle.handles.push(summary_keydown)
  let h = on_with_handle(toggle.details_el, "toggle", fn(_) {
    let is_open_now = has_attribute(toggle.details_el, "open")
    if is_open_now != toggle.is_open {
      set_toggle_open(toggle, is_open_now, config)
    }
  })
  toggle.handles.push(h)
}

///|
fn toggle_storage_key(toggle : HeadingToggle) -> String {
  let key = get_attribute(toggle.original_heading, "data-heading-key")
  if key.length() > 0 {
    "yunomi:heading:" + key
  } else {
    ""
  }
}

///|
fn set_toggle_open(
  toggle : HeadingToggle,
  is_open : Bool,
  config : ToggleConfig,
) -> Unit {
  toggle.is_open = is_open
  if is_open {
    set_attribute(toggle.details_el, "open", "")
  } else {
    remove_attribute(toggle.details_el, "open")
  }
  let storage_key = toggle_storage_key(toggle)
  if storage_key.length() > 0 {
    ls_set(storage_key, if is_open { "expanded" } else { "collapsed" })
  }
  update_toggle_state(toggle, config)
}

///|
/// Update toggle visual state
fn update_toggle_state(toggle : HeadingToggle, config : ToggleConfig) -> Unit {
  // Update icon
  update_toggle_icon(toggle)

  // Update ARIA
  set_attribute(toggle.summary_el, "aria-expanded", toggle.is_open.to_string())
  set_attribute(toggle.content_el, "aria-hidden", (!toggle.is_open).to_string())

  if toggle.is_open {
    show_content(toggle.content_el)
  } else {
    hide_content(toggle.content_el)
  }

  ignore(config)
}

///|
/// Update toggle icon
fn update_toggle_icon(toggle : HeadingToggle) -> Unit {
  let icon = query_in(toggle.summary_el, ".heading-toggle-icon")
  if !is_null(icon) {
    set_text_content(icon, if toggle.is_open { "▼" } else { "▶" })
    if toggle.is_open {
      remove_class(icon, "collapsed")
    } else {
      add_class(icon, "collapsed")
    }
  }
}

///|
/// Show section content and clear any stale collapsed styles
fn show_content(content : Element) -> Unit {
  set_style(content, "display", "")
  set_style(content, "height", "")
  set_style(content, "opacity", "")
  set_style(content, "overflow", "")
  set_style(content, "transition", "")
}

///|
/// Hide section content deterministically so details state and drawing stay aligned
fn hide_content(content : Element) -> Unit {
  set_style(content, "display", "none")
  set_style(content, "height", "0")
  set_style(content, "opacity", "0")
  set_style(content, "overflow", "hidden")
  set_style(content, "transition", "")
}

///|
/// Setup intersection observer for heading visibility tracking
fn setup_heading_observer() -> Unit {
  // Track which heading is currently in view
  // This is useful for TOC highlighting and auto-expansion

  let callback = fn(entries : Array[Element]) { ignore(entries) }

  setup_intersection_observer(
    query(".md-preview"),
    callback,
    null_element(),
    "-20% 0px -60% 0px",
    0.0,
  )
}

///|
/// Toggle all sections open/closed
pub fn toggle_all_sections(open : Bool) -> Unit {
  active_toggles.val.each(fn(toggle) {
    if toggle.is_open != open {
      set_toggle_open(toggle, open, default_toggle_config())
    }
  })
}

///|
/// Expand specific section by ID
pub fn expand_section_by_id(id : String) -> Unit {
  active_toggles.val.each(fn(toggle) {
    let toggle_id = get_attribute(toggle.original_heading, "id")
    if toggle_id == id && !toggle.is_open {
      set_toggle_open(toggle, true, default_toggle_config())
      scroll_into_view(toggle.details_el)
    }
  })
}

///|
/// Collapse specific section by ID
pub fn collapse_section_by_id(id : String) -> Unit {
  active_toggles.val.each(fn(toggle) {
    let toggle_id = get_attribute(toggle.original_heading, "id")
    if toggle_id == id && toggle.is_open {
      set_toggle_open(toggle, false, default_toggle_config())
    }
  })
}

///|
/// Get all section IDs and their open state
pub fn get_sections_state() -> Array[(String, Bool)] {
  let states : Array[(String, Bool)] = []
  active_toggles.val.each(fn(toggle) {
    let id = get_attribute(toggle.original_heading, "id")
    if id != "" {
      states.push((id, toggle.is_open))
    }
  })
  states
}

///|
/// Restore sections state from saved data
pub fn restore_sections_state(states : Array[(String, Bool)]) -> Unit {
  states.each(fn(state) {
    let (id, should_open) = state
    if should_open {
      expand_section_by_id(id)
    } else {
      collapse_section_by_id(id)
    }
  })
}

///|
/// Destroy all toggle instances and restore original DOM
pub fn destroy_all_toggles() -> Unit {
  // Remove all event listeners
  active_toggles.val.each(fn(toggle) {
    toggle.handles.each(fn(h) { unlisten(h) })

    let parent = parent_element(toggle.details_el)
    if !is_null(parent) {
      insert_before(toggle.details_el, toggle.original_heading)
      toggle.content_nodes.each(fn(node) {
        insert_before(toggle.details_el, node)
      })
    }
    remove_element(toggle.details_el)
  })

  active_toggles.val.clear()
}

///|
/// Re-initialize toggles (useful after dynamic content changes)
pub fn refresh_toggles(config? : ToggleConfig) -> Unit {
  destroy_all_toggles()
  init_heading_toggles(config?)
}
