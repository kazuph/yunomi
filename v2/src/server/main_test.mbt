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
    install_target_path("codex", false).contains(
      ".agents/skills/yunomi/SKILL.md",
    ),
    content="true",
  )
}

///|
test "install_target_path: claude global skill path follows claude convention" {
  debug_inspect(
    install_target_path("claude", true).contains(
      ".claude/skills/yunomi/SKILL.md",
    ),
    content="true",
  )
}

///|
test "sapling_status_paths: extracts modified and added paths" {
  debug_inspect(
    sapling_status_paths("M src/review.mbt\nA docs/PLAN.md\n"),
    content="[\"src/review.mbt\", \"docs/PLAN.md\"]",
  )
}

///|
test "sapling_status_paths: ignores blank status rows and deduplicates paths" {
  debug_inspect(
    sapling_status_paths("\nM src/review.mbt\nM src/review.mbt\n"),
    content="[\"src/review.mbt\"]",
  )
}

///|
test "summary_image_filename: includes review identifier and image index" {
  debug_inspect(
    summary_image_filename("srv/abc:123", "submit/def:456", 2, "png"),
    content="\"summary-srv-abc-123-submit-def-456-2.png\"",
  )
}

///|
test "summary_image_filename: avoids multi-file submit collisions at same index" {
  debug_inspect(
    summary_image_filename("srv-1", "submit-a", 0, "png") !=
    summary_image_filename("srv-1", "submit-b", 0, "png"),
    content="true",
  )
}
