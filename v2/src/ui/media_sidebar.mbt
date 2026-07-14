///| MediaSidebar — Pure MoonBit implementation
///  Thumbnail list acts as a scroll navigator for media in the preview:
///  - Click / Enter on a thumbnail scrolls the preview to that media and
///    flashes a highlight ring around it.
///  - ArrowUp / ArrowDown move to the previous / next media.
///  - Escape clears the active selection.
///  Full-size viewing is delegated to the fullscreen viewers
///  (click an image / video / mermaid in the preview itself).

///|
/// Media item types
enum MediaType {
  Image
  Video
  Mermaid
}

///|
/// Media item data
struct MediaItem {
  type_ : MediaType
  element : Element
  src : String
  alt : String
  svg : Element // For mermaid type
}

///|
/// MediaSidebar state
struct MediaSidebarState {
  preview : Element
  sidebar : Element
  thumbs_container : Element
  // Items and state
  items : Array[MediaItem]
  mut active_idx : Int
  mut is_visible : Bool
  // Currently highlighted media element in the preview
  mut highlighted : Element
  mut highlight_seq : Int
  // Event handles (sidebar lifetime)
  handles : Array[ListenerHandle]
}

///|
/// Global sidebar instance
let global_sidebar : Ref[MediaSidebarState?] = Ref(None)

///|
/// Keep the navigation ring visible beyond the persistent scroll correction
/// window: 300ms initial delay + 8 * 250ms re-aims + the existing 3000ms dwell.
let nav_highlight_dwell_ms : Int = 5300

///|
/// Initialize media sidebar for the current page
pub fn init_media_sidebar() -> Unit {
  // Check if already initialized
  if global_sidebar.val is Some(_) {
    return
  }

  // Find required elements
  let md_layout = query(".md-layout")
  let preview = query_in(md_layout, ".md-preview")
  let sidebar = query("#media-sidebar")
  let thumbs_c = query("#media-sidebar-thumbs")
  let toggle_btn = query("#media-sidebar-toggle")
  let toggle_count = query("#media-toggle-count")

  // Check if all required elements exist
  if is_null(md_layout) ||
    is_null(preview) ||
    is_null(sidebar) ||
    is_null(thumbs_c) ||
    is_null(toggle_btn) {
    return
  }

  // Collect media items from preview
  let items = collect_media_items(preview)
  if items.is_empty() {
    return
  }

  // Create state
  let state = MediaSidebarState::{
    preview,
    sidebar,
    thumbs_container: thumbs_c,
    items,
    active_idx: -1,
    is_visible: true,
    highlighted: null_element(),
    highlight_seq: 0,
    handles: [],
  }

  // Show toggle button and sidebar
  set_style(toggle_btn, "display", "")
  add_class(toggle_btn, "has-media")
  if !is_null(toggle_count) {
    set_text_content(toggle_count, items.length().to_string())
  }
  remove_class(sidebar, "hidden")

  // Create thumbnails
  create_thumbnails(state)

  // Setup toggle button
  let h1 = on_with_handle(toggle_btn, "click", fn(_e) { toggle_sidebar(state) })
  state.handles.push(h1)

  // Setup keyboard navigation
  setup_keyboard_navigation(state)

  // Setup mermaid mutation observer
  setup_mermaid_observer(state)

  // Store global instance
  global_sidebar.val = Some(state)
}

///|
/// Collect media items from preview element
fn collect_media_items(preview : Element) -> Array[MediaItem] {
  let items : Array[MediaItem] = []
  let mut img_count = 0
  let mut video_count = 0
  let mut mermaid_count = 0

  // Find all images, videos, and mermaid containers
  let all_media = query_all_in(
    preview, "img,video.video-preview,.mermaid-container",
  )

  all_media.each(fn(el) {
    let tag = get_tag_name(el)
    let has_video_class = has_class(el, "video-preview")

    if tag == "IMG" {
      // Skip ghost images (empty src attribute resolves to the page URL)
      if get_attribute(el, "src") == "" {
        return
      }
      // Skip inline video-timeline scene thumbnails (not document media)
      if !is_null(closest(el, ".video-timeline")) {
        return
      }
      img_count = img_count + 1
      let src = get_src(el)
      let alt = get_attribute(el, "alt")
      let alt_text = if alt == "" {
        "Image " + img_count.to_string()
      } else {
        alt
      }
      items.push(MediaItem::{
        type_: Image,
        element: el,
        src,
        alt: alt_text,
        svg: null_element(),
      })
    } else if tag == "VIDEO" && has_video_class {
      let src = get_attribute(el, "src")
      let has_video_ext = src.to_lower().has_suffix(".mp4") ||
        src.to_lower().has_suffix(".mov") ||
        src.to_lower().has_suffix(".webm") ||
        src.to_lower().has_suffix(".avi") ||
        src.to_lower().has_suffix(".mkv") ||
        src.to_lower().has_suffix(".m4v") ||
        src.to_lower().has_suffix(".ogv")

      if has_video_ext {
        video_count = video_count + 1
        let title = get_attribute(el, "title")
        let alt_text = if title == "" {
          "Video " + video_count.to_string()
        } else {
          title
        }
        items.push(MediaItem::{
          type_: Video,
          element: el,
          src,
          alt: alt_text,
          svg: null_element(),
        })
      }
    } else if has_class(el, "mermaid-container") {
      mermaid_count = mermaid_count + 1
      let svg = query_in(el, "svg")
      items.push(MediaItem::{
        type_: Mermaid,
        element: el,
        src: "",
        alt: "Diagram " + mermaid_count.to_string(),
        svg,
      })
    }
  })

  items
}

///|
/// Create thumbnail elements
fn create_thumbnails(state : MediaSidebarState) -> Unit {
  state.items.eachi(fn(idx, item) {
    let thumb = create_element("div")
    set_class_name(thumb, "media-sidebar-thumb")
    set_attribute(thumb, "data-media-index", idx.to_string())
    set_tabindex(thumb, 0)
    set_attribute(thumb, "role", "button")
    set_aria_label(thumb, item.alt)

    // Index badge
    let badge = create_element("span")
    set_class_name(badge, "media-sidebar-thumb-index")
    set_text_content(badge, (idx + 1).to_string())
    append_child(thumb, badge)

    // Thumbnail content based on type
    match item.type_ {
      Image => {
        let img = create_element("img")
        set_attribute(img, "src", item.src)
        set_attribute(img, "alt", item.alt)
        set_attribute(img, "loading", "lazy")
        append_child(thumb, img)
      }
      Video => {
        let wrapper = create_element("div")
        set_class_name(wrapper, "media-sidebar-thumb-video")
        let vid = create_element("video")
        set_attribute(vid, "src", item.src + "#t=0.1")
        set_attribute(vid, "preload", "metadata")
        set_attribute(vid, "muted", "true")

        // Seek to 0.1s on load
        let h = on_with_handle(vid, "loadeddata", fn(_e) {
          if video_get_current_time(vid) < 0.01 {
            video_set_current_time(vid, 0.1)
          }
        })
        state.handles.push(h)

        append_child(wrapper, vid)
        append_child(thumb, wrapper)
      }
      Mermaid => {
        let wrapper = create_element("div")
        set_class_name(wrapper, "media-sidebar-thumb-mermaid")

        if !is_null(item.svg) {
          let cloned = clone_svg_for_thumbnail(item.svg, idx)
          append_child(wrapper, cloned)
        } else {
          set_text_content(wrapper, "Diagram")
          set_style(wrapper, "font-size", "9px")
          set_style(wrapper, "color", "var(--muted)")
        }

        append_child(thumb, wrapper)
      }
    }

    // Click handler: scroll preview to this media (re-click re-scrolls)
    let h = on_with_handle(thumb, "click", fn(e) {
      stop_propagation(e)
      navigate_to(state, idx)
    })
    state.handles.push(h)

    let h_key = on_with_handle(
      thumb,
      "keydown",
      fn(e) {
        let key = event_key(e)
        if key == "Enter" || key == " " {
          prevent_default(e)
          stop_propagation(e)
          navigate_to(state, idx)
        }
      },
      passive=false,
    )
    state.handles.push(h_key)

    append_child(state.thumbs_container, thumb)
  })
}

///|
/// Clone SVG for thumbnail with proper ID handling
fn clone_svg_for_thumbnail(svg : Element, idx : Int) -> Element {
  let cloned = clone_node_deep(svg)
  let orig_id = get_attribute(svg, "id")

  if orig_id != "" {
    let new_id = orig_id + "-sb-thumb-" + idx.to_string()
    set_attribute(cloned, "id", new_id)

    // Update style references
    let style_el = query_in(cloned, "style")
    if !is_null(style_el) {
      let style_text = get_text_content(style_el)
      let updated = replace_all_text(style_text, orig_id, new_id)
      set_text_content(style_el, updated)
    }
  }

  // Set viewBox if needed
  if get_attribute(cloned, "viewBox") == "" {
    let w = get_attribute(cloned, "width")
    let h = get_attribute(cloned, "height")
    if w != "" && h != "" {
      set_attribute(cloned, "viewBox", "0 0 " + w + " " + h)
    }
  }

  remove_attribute(cloned, "width")
  remove_attribute(cloned, "height")
  set_attribute(cloned, "preserveAspectRatio", "xMidYMid meet")
  set_style(cloned, "width", "100%")
  set_style(cloned, "height", "100%")

  cloned
}

///|
/// Scroll the preview to the media item and flash a highlight ring
fn navigate_to(state : MediaSidebarState, idx : Int) -> Unit {
  if idx < 0 || idx >= state.items.length() {
    return
  }

  let item = state.items[idx]
  state.active_idx = idx

  // Update thumbnail active state
  update_thumbnail_active_state(state, idx)

  // Clear previous highlight immediately
  if !is_null(state.highlighted) {
    remove_class(state.highlighted, "media-nav-highlight")
  }

  // Smooth-scroll the preview to the media element.
  // Persistent variant: lazy-loaded media above can shift layout mid-scroll,
  // so keep correcting until the target is really on screen.
  let target = item.element
  scroll_into_view_persistent(target)

  // Flash highlight; seq guards against stale timers when navigating quickly
  add_class(target, "media-nav-highlight")
  state.highlighted = target
  state.highlight_seq = state.highlight_seq + 1
  let seq = state.highlight_seq
  ignore(
    set_timeout(
      fn() {
        if state.highlight_seq == seq {
          remove_class(target, "media-nav-highlight")
        }
      },
      nav_highlight_dwell_ms,
    ),
  )
}

///|
/// Update thumbnail active state
fn update_thumbnail_active_state(state : MediaSidebarState, idx : Int) -> Unit {
  let all_thumbs = query_all_in(state.thumbs_container, ".media-sidebar-thumb")

  all_thumbs.eachi(fn(i, thumb) {
    if i == idx {
      add_class(thumb, "active")
      scroll_into_view_nearest(thumb)
    } else {
      remove_class(thumb, "active")
    }
  })
}

///|
/// Clear active selection and highlight
fn clear_active(state : MediaSidebarState) -> Unit {
  state.active_idx = -1

  if !is_null(state.highlighted) {
    remove_class(state.highlighted, "media-nav-highlight")
    state.highlighted = null_element()
  }

  let all_thumbs = query_all_in(state.thumbs_container, ".media-sidebar-thumb")
  all_thumbs.each(fn(thumb) { remove_class(thumb, "active") })
}

///|
/// Toggle sidebar visibility
fn toggle_sidebar(state : MediaSidebarState) -> Unit {
  state.is_visible = !state.is_visible

  if state.is_visible {
    remove_class(state.sidebar, "hidden")
  } else {
    add_class(state.sidebar, "hidden")
    clear_active(state)
  }
}

///|
/// Navigate thumbnails (scrolls preview to prev/next media)
fn navigate_thumbs(state : MediaSidebarState, direction : Int) -> Unit {
  let total = state.items.length()
  if total == 0 {
    return
  }

  let new_idx = if state.active_idx == -1 {
    if direction > 0 {
      0
    } else {
      total - 1
    }
  } else {
    state.active_idx + direction
  }

  let clamped_idx = if new_idx < 0 {
    0
  } else if new_idx >= total {
    total - 1
  } else {
    new_idx
  }

  if clamped_idx != state.active_idx {
    navigate_to(state, clamped_idx)
  }
}

///|
/// Move within the active inline video timeline, if the active media is video.
fn navigate_active_video_timeline(
  state : MediaSidebarState,
  direction : Int,
) -> Bool {
  if state.active_idx < 0 || state.active_idx >= state.items.length() {
    return false
  }
  let item = state.items[state.active_idx]
  match item.type_ {
    Video => ()
    _ => return false
  }

  let wrapper = closest(item.element, ".video-overlay-wrapper")
  if is_null(wrapper) {
    return false
  }
  let thumbs = query_all_in(wrapper, ".video-timeline .timeline-thumb")
  if thumbs.length() < 2 {
    return false
  }

  let current = video_get_current_time(item.element)
  let mut current_idx = 0
  let mut closest_dist = 1000000000.0
  for i, thumb in thumbs {
    let time = parse_float(get_dataset(thumb, "time"))
    let delta = time - current
    let dist = if delta < 0.0 { 0.0 - delta } else { delta }
    if dist < closest_dist {
      closest_dist = dist
      current_idx = i
    }
  }

  let raw_target = current_idx + direction
  let target_idx = if raw_target < 0 {
    0
  } else if raw_target >= thumbs.length() {
    thumbs.length() - 1
  } else {
    raw_target
  }

  let target = thumbs[target_idx]
  let target_time = parse_float(get_dataset(target, "time"))
  video_set_current_time(item.element, target_time)
  scroll_into_view_nearest(target)
  true
}

///|
/// Resolve the document media index for a focused inline video timeline.
fn media_index_for_timeline_focus(
  state : MediaSidebarState,
  active : Element,
) -> Int {
  let timeline = closest(active, ".video-timeline")
  if is_null(timeline) {
    return -1
  }

  let wrapper = closest(timeline, ".video-overlay-wrapper")
  if is_null(wrapper) {
    return -1
  }

  let video = query_in(wrapper, "video.video-preview")
  if is_null(video) {
    return -1
  }

  let mut found = -1
  state.items.eachi(fn(idx, item) {
    if found == -1 && elem_eq(item.element, video) {
      found = idx
    }
  })
  found
}

///|
fn media_nav_key(key : String) -> String {
  match key {
    "h" | "H" => "ArrowLeft"
    "j" | "J" => "ArrowDown"
    "k" | "K" => "ArrowUp"
    "l" | "L" => "ArrowRight"
    _ => key
  }
}

///|
fn review_dialog_visible() -> Bool {
  let submit = query("#submit-modal")
  let recovery = query("#recovery-modal")
  let questions = query("#yunomi-questions-overlay")
  let comment = query("#comment-card")
  (!is_null(submit) && has_class(submit, "visible")) ||
  (!is_null(recovery) && has_class(recovery, "visible")) ||
  (!is_null(questions) && has_class(questions, "visible")) ||
  (!is_null(comment) && get_computed_style(comment, "display") != "none")
}

///|
/// Setup keyboard navigation
fn setup_keyboard_navigation(state : MediaSidebarState) -> Unit {
  let h = on_with_handle(
    query_body(),
    "keydown",
    fn(e) {
      if !state.is_visible {
        return
      }

      // Check if fullscreen overlays are visible
      let img_fs = query("#image-fullscreen")
      let vid_fs = query("#video-fullscreen")
      let mermaid_fs = query("#mermaid-fullscreen")

      if (!is_null(img_fs) && has_class(img_fs, "visible")) ||
        (!is_null(vid_fs) && has_class(vid_fs, "visible")) ||
        (!is_null(mermaid_fs) && has_class(mermaid_fs, "visible")) {
        return
      }

      // Ignore if typing in input
      let active = get_active_element()
      let tag = get_tag_name(active)
      if tag == "INPUT" || tag == "TEXTAREA" {
        return
      }

      if review_dialog_visible() {
        return
      }

      if event_shift_key(e) {
        return
      }

      let key = media_nav_key(event_key(e))

      // Escape to clear active selection
      if key == "Escape" && state.active_idx != -1 {
        prevent_default(e)
        clear_active(state)
        return
      }

      // Arrow navigation
      let focused_thumb = has_class(active, "media-sidebar-thumb")
      let focused_timeline_idx = media_index_for_timeline_focus(state, active)
      if key == "ArrowUp" {
        prevent_default(e)
        if focused_timeline_idx != -1 {
          state.active_idx = focused_timeline_idx
        }
        navigate_thumbs(state, -1)
      } else if key == "ArrowDown" {
        prevent_default(e)
        if focused_timeline_idx != -1 {
          state.active_idx = focused_timeline_idx
        }
        navigate_thumbs(state, 1)
      } else if focused_thumb || state.active_idx != -1 || focused_timeline_idx != -1 {
        if key == "ArrowLeft" {
          if navigate_active_video_timeline(state, -1) {
            prevent_default(e)
          }
        } else if key == "ArrowRight" {
          if navigate_active_video_timeline(state, 1) {
            prevent_default(e)
          }
        }
      }
    },
    passive=false,
  )
  state.handles.push(h)
}

///|
/// Setup mermaid mutation observer
fn setup_mermaid_observer(state : MediaSidebarState) -> Unit {
  let check_mermaid = fn() {
    state.items.eachi(fn(idx, item) {
      if !is_mermaid_type(item.type_) {
        return
      }

      let svg = query_in(item.element, "svg")
      if is_null(svg) {
        return
      }

      // Check if SVG has content
      let has_content = query_in(
        svg, ".node,.cluster,.edgePath,.label,path,rect,circle,text",
      )
      if is_null(has_content) {
        return
      }

      if get_dataset(item.element, "updated") == "true" {
        return
      }

      set_dataset(item.element, "updated", "true")

      // Update thumbnail
      let thumb = query_in(
        state.thumbs_container,
        "[data-media-index='" + idx.to_string() + "']",
      )
      if is_null(thumb) {
        return
      }

      let mw = query_in(thumb, ".media-sidebar-thumb-mermaid")
      if is_null(mw) {
        return
      }

      clear_children(mw)
      let cloned = clone_svg_for_thumbnail(svg, idx)
      append_child(mw, cloned)
    })
  }

  // Initial check
  check_mermaid()

  // Setup mutation observer via FFI
  let _h = setup_mutation_observer(state.preview, check_mermaid)

  // Periodic checks
  let _ = set_timeout(check_mermaid, 1000)
  let _ = set_timeout(check_mermaid, 3000)
}

///|
/// Setup mutation observer (returns handle)
extern "js" fn setup_mutation_observer(
  target : Element,
  callback : () -> Unit,
) -> ListenerHandle =
  #|(target, callback) => {
  #|  const observer = new MutationObserver(callback);
  #|  observer.observe(target, { childList: true, subtree: true, attributes: true });
  #|  return { disconnect: () => observer.disconnect() };
  #|}

///|
fn is_mermaid_type(type_ : MediaType) -> Bool {
  match type_ {
    Mermaid => true
    _ => false
  }
}
