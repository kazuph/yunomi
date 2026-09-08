///|
test "notification quote keeps every line quoted within the existing limit" {
  debug_inspect(
    format_notification_quote("first\nsecond") == "\n> first\n> second",
    content="true",
  )
  let long = StringBuilder::new()
  for _ in 0..<201 {
    long.write_string("a")
  }
  debug_inspect(
    notification_quote(long.to_string()).to_array().length(),
    content="201",
  )
  debug_inspect(
    notification_quote(long.to_string()).has_suffix("…"),
    content="true",
  )
}
