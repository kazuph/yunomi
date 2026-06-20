///| VideoTimeline — Pure MoonBit implementation
///  Replaces JS-based window.__createVTL with native MoonBit logic
///  Features: SSE-based thumbnails, scene detection, keyboard navigation

///|
/// State for a single VideoTimeline instance
struct VTLState {
  video_el : Element
  container : Element
  timeline_el : Element
  video_path : String
  scene_threshold : Double
  stabilization_threshold : Double
  prevent_bubble : Bool
  // Runtime state
  thumbs : Array[ThumbData]
  mut event_source : EventSource
  mut is_loading : Bool
  mut active_thumb_idx : Int
  mut started : Bool
  // Event handles for cleanup
  handles : Array[ListenerHandle]
}

///|
/// Thumbnail data entry
struct ThumbData {
  element : Element
  time : Double
}

///|
/// Format seconds to MM:SS
fn format_time(seconds : Double) -> String {
  let m = (seconds / 60.0).to_int()
  let s = (seconds % 60.0).to_int()
  if s < 10 {
    "\{m}:0\{s}"
  } else {
    "\{m}:\{s}"
  }
}

///|
/// Create a new VideoTimeline with the given configuration.
///  With autostart=false the timeline element (and its height) is created
///  immediately but thumbnail loading waits for start_timeline_loading —
///  used for inline timelines so lazy loading causes no layout shift.
pub fn create_video_timeline_moonbit(
  video_el : Element,
  container : Element,
  video_path : String,
  scene_threshold : Double,
  stabilization_threshold : Double,
  prevent_bubble : Bool,
  autostart? : Bool = true,
) -> VTLState {
  // Create timeline element
  let timeline_el = create_element("div")
  set_class_name(timeline_el, "video-timeline")
  set_tabindex(timeline_el, 0)
  set_aria_label(timeline_el, "Video scene timeline")
  append_child(container, timeline_el)

  // Add loading indicator
  let loading_el = create_element("div")
  set_class_name(loading_el, "timeline-loading")
  set_text_content(loading_el, "Loading timeline...")
  append_child(timeline_el, loading_el)

  let state = VTLState::{
    video_el,
    container,
    timeline_el,
    video_path,
    scene_threshold,
    stabilization_threshold,
    prevent_bubble,
    thumbs: [],
    event_source: create_null_event_source(),
    is_loading: true,
    active_thumb_idx: -1,
    started: false,
    handles: [],
  }

  // Setup click handler to prevent bubble if needed
  if prevent_bubble {
    let h = on_with_handle(timeline_el, "click", fn(e) { stop_propagation(e) })
    state.handles.push(h)
  }

  // Start SSE connection (deferred when autostart=false)
  if autostart {
    start_timeline_loading(state)
  }

  // Setup video time update listener
  setup_timeupdate_listener(state)
  setup_timeline_keyboard_navigation(state)

  state
}

///|
/// Begin thumbnail loading for a timeline created with autostart=false.
///  Safe to call multiple times; only the first call connects.
pub fn start_timeline_loading(state : VTLState) -> Unit {
  if state.started {
    return
  }
  state.started = true
  start_sse_connection(state)
}

///|
/// Start SSE connection for thumbnail streaming
fn start_sse_connection(state : VTLState) -> Unit {
  let encoded_path = url_encode(state.video_path)
  let url = "/video-timeline?path=" +
    encoded_path +
    "&scene=" +
    state.scene_threshold.to_string() +
    "&stabilization=" +
    state.stabilization_threshold.to_string()

  let es = new_event_source_url(url)
  state.event_source = es

  // Setup SSE message handler
  sse_on_message(es, fn(data) { handle_sse_message(state, data) })

  // Setup error handler
  sse_on_error(es, fn() { handle_sse_error(state) })
}

///|
/// Handle SSE message
fn handle_sse_message(state : VTLState, data : String) -> Unit {
  // Parse JSON message
  let msg_type = parse_sse_type(data)

  match msg_type {
    "thumbnail" => {
      // Remove loading indicator on first thumbnail
      if state.is_loading {
        let loading = query_in(state.timeline_el, ".timeline-loading")
        if !is_null(loading) {
          remove_element(loading)
        }
        state.is_loading = false
      }

      // Extract thumbnail data
      let thumb_time = parse_sse_time(data)
      let thumb_src = parse_sse_src(data)

      // Create thumbnail element
      let wrapper = create_element("div")
      set_class_name(wrapper, "timeline-thumb-wrapper")

      let img = create_element("img")
      set_class_name(img, "timeline-thumb")
      set_attribute(img, "src", thumb_src)
      set_dataset(img, "time", thumb_time.to_string())
      set_attribute(img, "title", "Jump to " + format_time(thumb_time))

      // Click to jump
      let h = on_with_handle(img, "click", fn(e) {
        stop_propagation(e)
        focus_element(state.timeline_el)
        let t = parse_float(get_dataset(img, "time"))
        video_set_current_time(state.video_el, t)
      })
      state.handles.push(h)

      let label = create_element("span")
      set_class_name(label, "timeline-time")
      set_text_content(label, format_time(thumb_time))

      append_child(wrapper, img)
      append_child(wrapper, label)
      append_child(state.timeline_el, wrapper)

      // Store thumb data
      state.thumbs.push(ThumbData::{ element: img, time: thumb_time })
    }
    "complete" => {
      // Close SSE connection
      sse_close(state.event_source)
      state.event_source = create_null_event_source()

      // Show "no scenes" message if no thumbnails
      if state.thumbs.is_empty() {
        let loading = query_in(state.timeline_el, ".timeline-loading")
        if !is_null(loading) {
          set_text_content(loading, "No scene changes detected")
        }
      }
    }
    "error" => {
      // Close SSE and remove timeline
      sse_close(state.event_source)
      state.event_source = create_null_event_source()
      remove_element(state.timeline_el)
    }
    _ => ()
  }
}

///|
/// Handle SSE error
fn handle_sse_error(state : VTLState) -> Unit {
  // Close connection
  if !is_event_source_null(state.event_source) {
    sse_close(state.event_source)
    state.event_source = create_null_event_source()
  }

  // Remove timeline on error
  remove_element(state.timeline_el)
}

///|
/// Setup video time update listener
fn setup_timeupdate_listener(state : VTLState) -> Unit {
  let h = on_with_handle(state.video_el, "timeupdate", fn(_e) {
    let current = video_get_current_time(state.video_el)
    update_active_thumb(state, current)
  })
  state.handles.push(h)
}

///|
/// Update active thumbnail highlighting
fn update_active_thumb(state : VTLState, current_time : Double) -> Unit {
  if state.thumbs.is_empty() {
    return
  }

  // Find closest thumbnail
  let mut closest_idx = -1
  let mut closest_dist = 1000000000.0

  state.thumbs.eachi(fn(idx, thumb) {
    let dist = (thumb.time - current_time).abs()
    if dist < closest_dist {
      closest_dist = dist
      closest_idx = idx
    }
  })

  if closest_idx != state.active_thumb_idx {
    // Remove active from previous
    if state.active_thumb_idx >= 0 &&
      state.active_thumb_idx < state.thumbs.length() {
      let prev = state.thumbs[state.active_thumb_idx].element
      remove_class(prev, "active")
    }

    // Set active on new
    if closest_idx >= 0 && closest_idx < state.thumbs.length() {
      let curr = state.thumbs[closest_idx].element
      add_class(curr, "active")
      // Scroll into view
      scroll_into_view_nearest(curr)
    }

    state.active_thumb_idx = closest_idx
  }
}

///|
/// Setup keyboard navigation for scene thumbnails.
///  Left / Right stay within the timeline. Up / Down intentionally bubble to
///  the media sidebar so document media navigation keeps one clear owner.
fn setup_timeline_keyboard_navigation(state : VTLState) -> Unit {
  let h = on_with_handle(
    state.timeline_el,
    "keydown",
    fn(e) {
      let key = event_key(e)
      if key == "ArrowLeft" {
        prevent_default(e)
        stop_propagation(e)
        navigate(state, -1)
      } else if key == "ArrowRight" {
        prevent_default(e)
        stop_propagation(e)
        navigate(state, 1)
      }
    },
    passive=false,
  )
  state.handles.push(h)
}

///|
/// Navigate to next/prev scene
pub fn navigate(state : VTLState, direction : Int) -> Unit {
  if state.thumbs.is_empty() {
    return
  }

  let current = video_get_current_time(state.video_el)

  // Find current position in thumbs
  let mut current_idx = -1
  let mut min_dist = 1000000000.0

  state.thumbs.eachi(fn(idx, thumb) {
    let dist = (thumb.time - current).abs()
    if dist < min_dist {
      min_dist = dist
      current_idx = idx
    }
  })

  // Calculate target index
  let target_idx = current_idx + direction
  if target_idx >= 0 && target_idx < state.thumbs.length() {
    let target_time = state.thumbs[target_idx].time
    video_set_current_time(state.video_el, target_time)
  }
}

///|
/// Destroy a VideoTimeline instance
pub fn destroy_video_timeline(state : VTLState) -> Unit {
  // Close SSE if open
  if !is_event_source_null(state.event_source) {
    sse_close(state.event_source)
  }

  // Remove all event listeners
  state.handles.each(fn(h) { unlisten(h) })

  // Remove timeline element
  remove_element(state.timeline_el)
}

///|
/// Recreate timeline with new parameters
pub fn recreate_timeline(
  state : VTLState,
  new_scene_threshold : Double,
  new_stabilization_threshold : Double,
) -> VTLState {
  let video_el = state.video_el
  let container = state.container
  let video_path = state.video_path
  let prevent_bubble = state.prevent_bubble

  // Destroy old timeline
  destroy_video_timeline(state)

  // Create new one with updated params
  create_video_timeline_moonbit(
    video_el, container, video_path, new_scene_threshold, new_stabilization_threshold,
    prevent_bubble,
  )
}

// =============================================================================
// SSE Parsing helpers (JSON parsing via FFI)
// =============================================================================

///|
/// Parse SSE message type from JSON
extern "js" fn parse_sse_type(json : String) -> String =
  #|(json) => {
  #|  try {
  #|    const data = JSON.parse(json);
  #|    return data.type || '';
  #|  } catch(e) { return ''; }
  #|}

///|
/// Parse SSE time from JSON
extern "js" fn parse_sse_time(json : String) -> Double =
  #|(json) => {
  #|  try {
  #|    const data = JSON.parse(json);
  #|    return parseFloat(data.time) || 0;
  #|  } catch(e) { return 0; }
  #|}

///|
/// Parse SSE src from JSON
extern "js" fn parse_sse_src(json : String) -> String =
  #|(json) => {
  #|  try {
  #|    const data = JSON.parse(json);
  #|    return data.data || '';
  #|  } catch(e) { return ''; }
  #|}

///|
/// URL encode string
extern "js" fn url_encode(s : String) -> String =
  #|(s) => encodeURIComponent(s)

///|
/// Null event source
extern "js" fn create_null_event_source() -> EventSource =
  #|() => null

///|
/// Check if event source is null
extern "js" fn is_event_source_null(es : EventSource) -> Bool =
  #|(es) => es == null || es == undefined

///|
/// SSE on error handler
extern "js" fn sse_on_error(es : EventSource, handler : () -> Unit) -> Unit =
  #|(es, handler) => {
  #|  if (es) es.onerror = handler;
  #|}

///|
/// Video get current time
extern "js" fn video_get_current_time(el : Element) -> Double =
  #|(el) => el?.currentTime || 0

///|
/// Video set current time
extern "js" fn video_set_current_time(el : Element, time : Double) -> Unit =
  #|(el, time) => { if (el) el.currentTime = time; }

///|
/// Scroll element into view (nearest block/inline)
extern "js" fn scroll_into_view_nearest(el : Element) -> Unit =
  #|(el) => {
  #|  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
  #|}
