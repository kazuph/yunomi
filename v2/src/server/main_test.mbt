///|
/// Tests for is_within_correlation_window — the pure predicate behind
/// looks_like_reload_in_flight(). Regression guard for M-b/L-a: the window
/// must be symmetric (either timestamp can be the larger one) AND bounded
/// (an index GET far outside the window must NOT be treated as correlated,
/// even though it is still numerically ">"-comparable to the close signal).
test "is_within_correlation_window: identical timestamps are within window" {
  debug_inspect(
    is_within_correlation_window(1000.0, 1000.0, 3000.0),
    content=(
      #|true
    ),
  )
}

///|
test "is_within_correlation_window: index GET slightly after close signal is within window" {
  debug_inspect(
    is_within_correlation_window(1500.0, 1000.0, 3000.0),
    content=(
      #|true
    ),
  )
}

///|
test "is_within_correlation_window: index GET slightly before close signal is within window (symmetric)" {
  debug_inspect(
    is_within_correlation_window(1000.0, 1500.0, 3000.0),
    content=(
      #|true
    ),
  )
}

///|
test "is_within_correlation_window: exactly at the window boundary is within window (inclusive)" {
  debug_inspect(
    is_within_correlation_window(4000.0, 1000.0, 3000.0),
    content=(
      #|true
    ),
  )
}

///|
/// L-a negative case: an index GET just outside the correlation window must
/// NOT be treated as reload-in-flight, even though (before the M-b fix) an
/// unbounded lower-only check would have kept matching forever once
/// last_index_get_ms grew past last_close_signal_ms.
test "is_within_correlation_window: index GET just outside the window is rejected" {
  debug_inspect(
    is_within_correlation_window(4000.1, 1000.0, 3000.0),
    content=(
      #|false
    ),
  )
}

///|
/// L-a negative case, far side: an old index GET long before a much later
/// close signal (e.g. a page that sat open for minutes before the tab was
/// finally abandoned) must not be mistaken for a reload happening right
/// now — this is the case the old lower-bound-only check got right, and
/// the symmetric fix must not regress it.
test "is_within_correlation_window: stale old index GET far before close signal is rejected" {
  debug_inspect(
    is_within_correlation_window(1000.0, 600000.0, 3000.0),
    content=(
      #|false
    ),
  )
}

///|
/// L-a negative case mirroring the regression this fix closes: an index GET
/// that arrives long AFTER the close signal (well outside the window) must
/// not be treated as correlated. Before the M-b fix, the lower-bound-only
/// check (`last_index_get_ms > last_close_signal_ms - window_ms`) matched
/// this forever once last_index_get_ms grew past that threshold, so a
/// genuinely-abandoned tab's close could incorrectly keep being deferred by
/// an unrelated, much-later index GET (e.g. a completely different tab
/// loading the same file).
test "is_within_correlation_window: index GET long after close signal is rejected" {
  debug_inspect(
    is_within_correlation_window(600000.0, 1000.0, 3000.0),
    content=(
      #|false
    ),
  )
}

///|
test "parse_comment_target: splits file and positive line" {
  debug_inspect(comment_target_file("REPORT.md:42"), content="\"REPORT.md\"")
  debug_inspect(comment_target_line("REPORT.md:42"), content="42")
}

///|
test "sanitize_branch_name: produces review-directory-safe branch name" {
  debug_inspect(
    sanitize_branch_name("feature/agent interop:cli"),
    content="\"feature-agent-interop-cli\"",
  )
}

///|
test "install_target_path: codex project skill path follows agents convention" {
  debug_inspect(
    install_target_path("codex", false).contains(".agents/skills/yunomi/SKILL.md"),
    content="true",
  )
}

///|
test "install_target_path: claude global skill path follows claude convention" {
  debug_inspect(
    install_target_path("claude", true).contains(".claude/skills/yunomi/SKILL.md"),
    content="true",
  )
}
