///| ZoomPanViewer — Pure MoonBit implementation
///  Replaces JS-based window.__createZPV with native MoonBit logic
///  Features: mouse drag, wheel zoom, touch pinch, minimap support

///|
/// State for a single ZoomPanViewer instance
struct ZPVState {
  viewport : Element
  wrapper : Element
  natural_width : Double
  natural_height : Double
  zoom_info_el : Element
  has_minimap : Bool
  minimap_viewport_el : Element
  zoom_min : Double
  zoom_max : Double
  use_ctrl_for_zoom : Bool
  // Runtime state
  mut current_zoom : Double
  mut pan_x : Double
  mut pan_y : Double
  mut is_dragging : Bool
  mut drag_start_x : Double
  mut drag_start_y : Double
  mut pinch_start_dist : Double
  mut pinch_center_x : Double
  mut pinch_center_y : Double
  // Event handles for cleanup
  handles : Array[ListenerHandle]
}

///|
/// Create a new ZoomPanViewer with the given configuration
///  This replaces the JS window.__createZPV function
pub fn create_zoom_pan_viewer_moonbit(
  viewport : Element,
  wrapper : Element,
  natural_width : Double,
  natural_height : Double,
  zoom_info_el : Element,
  has_minimap : Bool,
  minimap_viewport_el : Element,
  _mm_max_w : Double,
  _mm_max_h : Double,
  _mm_pad : Double,
  zoom_min : Double,
  zoom_max : Double,
  use_ctrl_for_zoom : Bool,
) -> ZPVState {
  let state = ZPVState::{
    viewport,
    wrapper,
    natural_width,
    natural_height,
    zoom_info_el,
    has_minimap,
    minimap_viewport_el,
    zoom_min,
    zoom_max,
    use_ctrl_for_zoom,
    current_zoom: 1.0,
    pan_x: 0.0,
    pan_y: 0.0,
    is_dragging: false,
    drag_start_x: 0.0,
    drag_start_y: 0.0,
    pinch_start_dist: 0.0,
    pinch_center_x: 0.0,
    pinch_center_y: 0.0,
    handles: [],
  }

  set_style(state.viewport, "cursor", "grab")
  set_style(state.viewport, "touch-action", "none")

  // Setup event listeners using ListenerHandle pattern
  setup_mouse_events(state)
  setup_wheel_events(state)
  setup_touch_events(state)
  setup_double_click(state)

  // Initial fit: wait until the viewport has a real size.
  request_fit_to_viewport_when_ready(state, fn() {  })

  // Setup minimap if enabled
  if has_minimap {
    setup_minimap(state)
  }

  state
}

///|
/// Setup mouse drag events
fn setup_mouse_events(state : ZPVState) -> Unit {
  // Pointer down on viewport
  let h1 = on_with_handle(state.viewport, "pointerdown", fn(e) {
    let button = get_event_button(e)
    if button != 0 {
      return
    }
    prevent_default(e)
    state.is_dragging = true
    state.drag_start_x = get_event_client_x(e).to_double() - state.pan_x
    state.drag_start_y = get_event_client_y(e).to_double() - state.pan_y
    set_style(state.viewport, "cursor", "grabbing")
    set_style(state.viewport, "touch-action", "none")
  })
  state.handles.push(h1)

  // Pointer move on document
  let h2 = on_with_handle(query_body(), "pointermove", fn(e) {
    if !state.is_dragging {
      return
    }
    prevent_default(e)
    let client_x = get_event_client_x(e).to_double()
    let client_y = get_event_client_y(e).to_double()
    state.pan_x = client_x - state.drag_start_x
    state.pan_y = client_y - state.drag_start_y
    update_transform(state)
  })
  state.handles.push(h2)

  // Pointer up on document
  let h3 = on_with_handle(query_body(), "pointerup", fn(_) {
    if !state.is_dragging {
      return
    }
    state.is_dragging = false
    set_style(state.viewport, "cursor", "grab")
  })
  state.handles.push(h3)

  // Pointer leave/cancel
  let h4 = on_with_handle(query_body(), "pointercancel", fn(_) {
    if !state.is_dragging {
      return
    }
    state.is_dragging = false
    set_style(state.viewport, "cursor", "grab")
  })
  state.handles.push(h4)

  // Lost pointer capture
  let h5 = on_with_handle(state.viewport, "lostpointercapture", fn(_) {
    state.is_dragging = false
    set_style(state.viewport, "cursor", "grab")
  })
  state.handles.push(h5)
}

///|
/// Setup wheel zoom events
fn setup_wheel_events(state : ZPVState) -> Unit {
  let h = on_with_handle(
    state.viewport,
    "wheel",
    fn(e) {
      prevent_default(e)

      let delta_x = get_event_delta_x(e)
      let delta_y = get_event_delta_y(e)
      let client_x = get_event_client_x(e).to_double()
      let client_y = get_event_client_y(e).to_double()

      if state.use_ctrl_for_zoom {
        let ctrl_pressed = event_ctrl_key(e) || event_meta_key(e)
        if ctrl_pressed {
          // Zoom at cursor
          let factor = if delta_y > 0.0 { 0.9 } else { 1.1 }
          zoom_at_point(state, factor, client_x, client_y)
        } else {
          // Pan
          state.pan_x -= delta_x
          state.pan_y -= delta_y
          update_transform(state)
        }
      } else {
        // Always zoom
        let factor = if delta_y > 0.0 { 0.9 } else { 1.1 }
        zoom_at_point(state, factor, client_x, client_y)
      }
    },
    capture=false,
    passive=false,
  )
  state.handles.push(h)
}

///|
/// Setup touch pinch events
fn setup_touch_events(state : ZPVState) -> Unit {
  // Touch start for pinch detection
  let h1 = on_with_handle(
    state.viewport,
    "touchstart",
    fn(e) {
      let touches = get_touches(e)
      if touches.length() == 2 {
        prevent_default(e)
        let t1 = touches[0]
        let t2 = touches[1]
        let dx = touch_get_client_x(t2) - touch_get_client_x(t1)
        let dy = touch_get_client_y(t2) - touch_get_client_y(t1)
        state.pinch_start_dist = math_sqrt(dx * dx + dy * dy)
        state.pinch_center_x = (touch_get_client_x(t1) + touch_get_client_x(t2)) /
          2.0
        state.pinch_center_y = (touch_get_client_y(t1) + touch_get_client_y(t2)) /
          2.0
      }
    },
    capture=false,
    passive=false,
  )
  state.handles.push(h1)

  // Touch move for pinch zoom
  let h2 = on_with_handle(
    state.viewport,
    "touchmove",
    fn(e) {
      let touches = get_touches(e)
      if touches.length() == 2 {
        prevent_default(e)
        let t1 = touches[0]
        let t2 = touches[1]
        let dx = touch_get_client_x(t2) - touch_get_client_x(t1)
        let dy = touch_get_client_y(t2) - touch_get_client_y(t1)
        let current_dist = math_sqrt(dx * dx + dy * dy)

        if state.pinch_start_dist > 0.0 {
          let scale = current_dist / state.pinch_start_dist
          if math_abs(scale - 1.0) > 0.01 {
            zoom_at_point(
              state,
              scale,
              state.pinch_center_x,
              state.pinch_center_y,
            )
            state.pinch_start_dist = current_dist
          }
        }

        // Update pan based on center movement
        let new_center_x = (touch_get_client_x(t1) + touch_get_client_x(t2)) /
          2.0
        let new_center_y = (touch_get_client_y(t1) + touch_get_client_y(t2)) /
          2.0
        state.pan_x += new_center_x - state.pinch_center_x
        state.pan_y += new_center_y - state.pinch_center_y
        state.pinch_center_x = new_center_x
        state.pinch_center_y = new_center_y

        update_transform(state)
      }
    },
    capture=false,
    passive=false,
  )
  state.handles.push(h2)

  // Touch end/cancel
  let h3 = on_with_handle(state.viewport, "touchend", fn(_) {
    state.pinch_start_dist = 0.0
  })
  state.handles.push(h3)

  let h4 = on_with_handle(state.viewport, "touchcancel", fn(_) {
    state.pinch_start_dist = 0.0
  })
  state.handles.push(h4)
}

///|
/// Setup double-click to reset
fn setup_double_click(state : ZPVState) -> Unit {
  let h = on_with_handle(state.viewport, "dblclick", fn(_) {
    fit_to_viewport(state)
  })
  state.handles.push(h)
}

///|
/// Update CSS transform on wrapper
fn update_transform(state : ZPVState) -> Unit {
  let transform = "translate(\{state.pan_x}px, \{state.pan_y}px) scale(\{state.current_zoom})"
  set_style(state.wrapper, "transform", transform)
  set_style(state.wrapper, "transform-origin", "0 0")

  // Update zoom info display
  if !is_null(state.zoom_info_el) {
    let pct = math_round(state.current_zoom * 100.0).to_int()
    set_text_content(state.zoom_info_el, "\{pct}%")
  }

  // Update minimap
  if state.has_minimap && !is_null(state.minimap_viewport_el) {
    update_minimap_viewport(state)
  }
}

///|
/// Zoom at specific point
fn zoom_at_point(
  state : ZPVState,
  factor : Double,
  client_x : Double,
  client_y : Double,
) -> Unit {
  let old_zoom = state.current_zoom
  let new_zoom = clamp_double(old_zoom * factor, state.zoom_min, state.zoom_max)

  // Calculate viewport-relative position
  let rect = get_bounding_rect(state.viewport)
  let vp_left = rect[0]
  let vp_top = rect[1]
  let rel_x = client_x - vp_left
  let rel_y = client_y - vp_top

  // Adjust pan to zoom at point
  let ratio = new_zoom / old_zoom
  state.pan_x = rel_x - (rel_x - state.pan_x) * ratio
  state.pan_y = rel_y - (rel_y - state.pan_y) * ratio
  state.current_zoom = new_zoom

  update_transform(state)
}

///|
/// Zoom by factor at center
fn zoom_at_center(state : ZPVState, factor : Double) -> Unit {
  let rect = get_bounding_rect(state.viewport)
  let center_x = rect[0] + rect[2] / 2.0
  let center_y = rect[1] + rect[3] / 2.0
  zoom_at_point(state, factor, center_x, center_y)
}

///|
/// Fit content to viewport
fn fit_to_viewport_now(state : ZPVState) -> Bool {
  let rect = get_bounding_rect(state.viewport)
  let vp_w = rect[2]
  let vp_h = rect[3]
  if vp_w <= 0.0 ||
    vp_h <= 0.0 ||
    state.natural_width <= 0.0 ||
    state.natural_height <= 0.0 {
    return false
  }

  let scale_w = vp_w / state.natural_width
  let scale_h = vp_h / state.natural_height
  let scale = min_double(scale_w, scale_h)

  state.current_zoom = scale
  // Center the content
  let scaled_w = state.natural_width * scale
  let scaled_h = state.natural_height * scale
  state.pan_x = (vp_w - scaled_w) / 2.0
  state.pan_y = (vp_h - scaled_h) / 2.0

  update_transform(state)
  true
}

///|
/// Fit content to viewport when layout is stable
pub fn request_fit_to_viewport_when_ready(
  state : ZPVState,
  on_ready : () -> Unit,
) -> Unit {
  request_fit_to_viewport_when_ready_impl(state, on_ready, 0)
}

///|
fn request_fit_to_viewport_when_ready_impl(
  state : ZPVState,
  on_ready : () -> Unit,
  attempt : Int,
) -> Unit {
  if fit_to_viewport_now(state) {
    on_ready()
    return
  }
  if attempt >= 60 {
    return
  }
  ignore(
    set_timeout(
      fn() {
        request_fit_to_viewport_when_ready_impl(state, on_ready, attempt + 1)
      },
      16,
    ),
  )
}

///|
/// Fit content to viewport
pub fn fit_to_viewport(state : ZPVState) -> Unit {
  ignore(fit_to_viewport_now(state))
}

///|
/// Fit content to viewport width (may overflow vertically)
pub fn fit_to_width(state : ZPVState) -> Unit {
  let rect = get_bounding_rect(state.viewport)
  let vp_w = rect[2]
  let vp_h = rect[3]
  if vp_w <= 0.0 || state.natural_width <= 0.0 {
    return
  }
  let scale = vp_w / state.natural_width
  state.current_zoom = scale
  let scaled_h = state.natural_height * scale
  state.pan_x = 0.0
  // If image fits vertically, center it; otherwise top-align
  state.pan_y = if scaled_h <= vp_h { (vp_h - scaled_h) / 2.0 } else { 0.0 }
  update_transform(state)
}

///|
/// Setup minimap indicators
fn setup_minimap(state : ZPVState) -> Unit {
  // Minimap is drawn via CSS/marker elements in the HTML
  // This function initializes the viewport indicator position
  update_minimap_viewport(state)
}

///|
/// Update minimap viewport indicator position
fn update_minimap_viewport(state : ZPVState) -> Unit {
  if is_null(state.minimap_viewport_el) || state.current_zoom <= 0.0 {
    return
  }
  let vp_rect = get_bounding_rect(state.viewport)
  if vp_rect[2] <= 0.0 || vp_rect[3] <= 0.0 {
    return
  }
  let minimap = closest(state.minimap_viewport_el, ".minimap")
  if is_null(minimap) {
    return
  }
  let minimap_content = query_in(minimap, ".minimap-content")
  if is_null(minimap_content) {
    return
  }
  let minimap_subject = query_in(minimap_content, "svg, img")
  if is_null(minimap_subject) {
    return
  }

  let minimap_rect = get_bounding_rect(minimap)
  let subject_rect = get_bounding_rect(minimap_subject)
  let world_x = -state.pan_x / state.current_zoom
  let world_y = -state.pan_y / state.current_zoom
  let visible_w = vp_rect[2] / state.current_zoom
  let visible_h = vp_rect[3] / state.current_zoom
  let visible_left = clamp_double(world_x, 0.0, state.natural_width)
  let visible_top = clamp_double(world_y, 0.0, state.natural_height)
  let visible_right = clamp_double(
    world_x + visible_w,
    0.0,
    state.natural_width,
  )
  let visible_bottom = clamp_double(
    world_y + visible_h,
    0.0,
    state.natural_height,
  )
  let scale_x = subject_rect[2] / state.natural_width
  let scale_y = subject_rect[3] / state.natural_height
  let offset_x = subject_rect[0] - minimap_rect[0]
  let offset_y = subject_rect[1] - minimap_rect[1]
  let mut mm_x = offset_x + visible_left * scale_x
  let mut mm_y = offset_y + visible_top * scale_y
  let mut mm_w = max_double(0.0, visible_right - visible_left) * scale_x
  let mut mm_h = max_double(0.0, visible_bottom - visible_top) * scale_y
  let max_x = max_double(offset_x, offset_x + subject_rect[2] - mm_w)
  let max_y = max_double(offset_y, offset_y + subject_rect[3] - mm_h)

  mm_x = clamp_double(mm_x, offset_x, max_x)
  mm_y = clamp_double(mm_y, offset_y, max_y)
  mm_w = min_double(subject_rect[2], max_double(12.0, mm_w))
  mm_h = min_double(subject_rect[3], max_double(8.0, mm_h))

  // Apply styles to minimap viewport element
  set_style(state.minimap_viewport_el, "width", "\{mm_w}px")
  set_style(state.minimap_viewport_el, "height", "\{mm_h}px")
  set_style(state.minimap_viewport_el, "left", "\{mm_x}px")
  set_style(state.minimap_viewport_el, "top", "\{mm_y}px")
}

///|
/// Destroy a ZoomPanViewer instance and clean up all listeners
pub fn destroy_zoom_pan_viewer(state : ZPVState) -> Unit {
  // Remove all event listeners
  state.handles.each(fn(h) { unlisten(h) })
}

///|
/// Zoom in by 25%
pub fn zoom_in(state : ZPVState) -> Unit {
  zoom_at_center(state, 1.25)
}

///|
/// Zoom out by 20%
pub fn zoom_out(state : ZPVState) -> Unit {
  zoom_at_center(state, 0.8)
}

///|
/// Get current zoom level
pub fn get_zoom(state : ZPVState) -> Double {
  state.current_zoom
}

///|
/// Reset to fit viewport
pub fn reset_view(state : ZPVState) -> Unit {
  fit_to_viewport(state)
}

///|
/// Configuration struct for creating viewer (kept for API compatibility)
pub(all) struct ZoomPanConfig {
  viewport : Element
  wrapper : Element
  natural_width : Double
  natural_height : Double
  zoom_info_el : Element
  has_minimap : Bool
  minimap_viewport_el : Element
  mm_max_w : Double
  mm_max_h : Double
  mm_pad : Double
  zoom_min : Double
  zoom_max : Double
  use_ctrl_for_zoom : Bool
}

///|
/// Create viewer from config (convenience function)
pub fn new_zoom_pan_viewer(config : ZoomPanConfig) -> ZPVState {
  create_zoom_pan_viewer_moonbit(
    config.viewport,
    config.wrapper,
    config.natural_width,
    config.natural_height,
    config.zoom_info_el,
    config.has_minimap,
    config.minimap_viewport_el,
    config.mm_max_w,
    config.mm_max_h,
    config.mm_pad,
    config.zoom_min,
    config.zoom_max,
    config.use_ctrl_for_zoom,
  )
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn clamp_double(value : Double, min_ : Double, max_ : Double) -> Double {
  if value < min_ {
    min_
  } else if value > max_ {
    max_
  } else {
    value
  }
}
