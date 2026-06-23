///| Tests for cli.cjs-compatible markdown HTML structure

///| Mirrors markdown.test.js E2E requirements at the MoonBit level

///| Plan G3: Markdown HTML structure incompatibilities

///| Tests for md-layout/md-left/md-right will FAIL until build_markdown_html

///|
/// is updated to the cli.cjs-compatible structure (TDD red phase)
test "markdown html: has header tag with filename" {
  // markdown.test.js:53 locator('header h1').toContainText('sample.md')
  let md : MarkdownData = {
    source: "# Hello",
    html: "<h1>Hello</h1>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "sample.md", 4989)
  debug_inspect(
    html.contains("<header"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("sample.md"),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: uses md-layout wrapper" {
  // markdown.test.js scroll sync uses .md-layout (not .md-container)
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("md-layout"),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: has md-left panel" {
  // markdown.test.js:172 locator('.md-left') for scroll sync
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("md-left"),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: has md-right panel" {
  // markdown.test.js:173 locator('.md-right') for scroll sync
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("md-right"),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: preview pane has md-preview class" {
  // markdown.test.js:54 locator('.md-preview') is visible
  let md : MarkdownData = {
    source: "# Title",
    html: "<h1>Title</h1>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("md-preview"),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: preview contains rendered html" {
  // markdown.test.js:56 preview.locator('h1').toContainText('Sample Document')
  let md : MarkdownData = {
    source: "# Sample Document",
    html: "<h1>Sample Document</h1>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("Sample Document</h1>"),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: right panel has csv-table id" {
  // markdown.test.js:57 locator('#csv-table').toBeVisible()
  // Source table in right panel uses same #csv-table id as CSV mode
  let md : MarkdownData = {
    source: "line1\nline2",
    html: "<p>content</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("id=\"csv-table\""),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: source table has tbody with data-row and data-col" {
  // markdown.test.js:59 td[data-row="1"][data-col="1"] for cell click
  let md : MarkdownData = {
    source: "line0\nline1\nline2",
    html: "<p>content</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("data-row="),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("data-col=\"1\""),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: has pill-comments button" {
  // cli.cjs uses pill-comments for comment toggle
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("id=\"pill-comments\""),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: has comment-list panel" {
  // cli.cjs uses comment-list aside
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("comment-list"),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: has mermaid-fullscreen overlay" {
  // markdown.test.js:101 locator('#mermaid-fullscreen')
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("id=\"mermaid-fullscreen\""),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: has image-fullscreen overlay" {
  // markdown.test.js:111 locator('#image-fullscreen')
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("id=\"image-fullscreen\""),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: has view-toggle button" {
  // preview-only.test.js expects #view-toggle to switch view modes
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("id=\"view-toggle\""),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: has recovery modal" {
  // Recovery modal for localStorage restore on page reload
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("id=\"recovery-modal\""),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: mermaid fullscreen has zoom controls and minimap CSS" {
  // Verify Mermaid fullscreen overlay includes zoom in/out, reset, close controls
  // and the CSS includes minimap styling for ZoomPanViewer
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  // Fullscreen controls
  debug_inspect(
    html.contains("id=\"fs-zoom-in\""),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("id=\"fs-zoom-out\""),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("id=\"fs-reset\""),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("id=\"fs-close\""),
    content=(
      #|true
    ),
  )
  // ZoomPanViewer content area (where minimap is dynamically added)
  debug_inspect(
    html.contains("id=\"fs-content\""),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("id=\"fs-wrapper\""),
    content=(
      #|true
    ),
  )
  // CSS includes minimap styling
  debug_inspect(
    html.contains(".minimap"),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: mermaid opens fullscreen from container without a fullscreen button" {
  // Mermaid opens fullscreen from the diagram itself; no extra overlay button.
  let md : MarkdownData = {
    source: "```mermaid\ngraph LR\n  A-->B\n```",
    html: "<div class=\"mermaid-container\"><pre class=\"mermaid\">graph LR\n  A--&gt;B</pre></div>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("mermaid-fullscreen-btn"),
    content=(
      #|false
    ),
  )
  debug_inspect(
    html.contains("mermaid-container"),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: has video-fullscreen overlay" {
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("id=\"video-fullscreen\""),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: has media-sidebar" {
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("id=\"media-sidebar\""),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("media-sidebar-thumbs"),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: video elements have preview class for sidebar detection" {
  // Videos rendered from markdown should have video-preview class
  // so init_media_sidebar_js() can detect them as media items
  let md : MarkdownData = {
    source: "![video](test.mp4)",
    html: "<video src=\"test.mp4\" controls preload=\"metadata\" class=\"video-preview\"></video>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("video-preview"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    html.contains("preload=\"metadata\""),
    content=(
      #|true
    ),
  )
}

///|
test "markdown html: media-sidebar-thumb CSS classes exist" {
  // CSS should contain media-sidebar-thumb-video styles for video thumbnails
  let md : MarkdownData = {
    source: "text",
    html: "<p>text</p>",
    frontmatter: {},
    questions: [],
  }
  let html = build_markdown_html(md, "test.md", 4989)
  debug_inspect(
    html.contains("media-sidebar-thumb-video"),
    content=(
      #|true
    ),
  )
  // Play button overlay (::before and ::after pseudo-elements)
  debug_inspect(
    html.contains("media-sidebar-thumb-video::after"),
    content=(
      #|true
    ),
  )
}
