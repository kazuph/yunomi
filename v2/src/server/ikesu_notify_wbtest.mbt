///|
test "ikesu actual 0.4.7 help contracts and absent prompt" {
  let agent =
    #|ikesu agent commands:
    #|  ikesu agent list
    #|  ikesu agent attach <target> [--takeover]
    #|  ikesu agent get <target>
    #|  ikesu agent explain <target> [--json]
    #|  ikesu agent explain --file PATH --agent LABEL [--json]
    #|  ikesu agent read <target> [--source visible|recent|recent-unwrapped] [--lines N]
    #|  ikesu agent send <target> <text>
    #|  ikesu agent prompt <target> <text> [--wait] [--until STATUS]... [--timeout MS]
    #|  ikesu agent rename <target> <name>
    #|  ikesu agent focus <target>
    #|  ikesu agent wait <target> --status <idle|working|blocked|done|unknown> [--timeout MS]
    #|  ikesu agent start <name> [--cwd PATH] [--workspace ID] [--tab ID] [--split right|down] [--env KEY=VALUE] [--focus|--no-focus] -- <argv...>
    #|  ikesu agent restore [--dry-run]
    #|targets accept pane ids (pN), unique agent names, and detected/reported agent labels
  let no_prompt =
    #|ikesu agent commands:
    #|  ikesu agent list
    #|  ikesu agent attach <target> [--takeover]
    #|  ikesu agent get <target>
    #|  ikesu agent explain <target> [--json]
    #|  ikesu agent explain --file PATH --agent LABEL [--json]
    #|  ikesu agent read <target> [--source visible|recent|recent-unwrapped] [--lines N]
    #|  ikesu agent send <target> <text>
    #|  ikesu agent rename <target> <name>
    #|  ikesu agent focus <target>
    #|  ikesu agent wait <target> --status <idle|working|blocked|done|unknown> [--timeout MS]
    #|  ikesu agent start <name> [--cwd PATH] [--workspace ID] [--tab ID] [--split right|down] [--env KEY=VALUE] [--focus|--no-focus] -- <argv...>
    #|  ikesu agent restore [--dry-run]
    #|targets accept pane ids (pN), unique agent names, and detected/reported agent labels
  let room =
    #|usage: ikesu send <to> <text> [--room R] [--reply-to ID] [--from NAME]
    #|sends a message to an agent or pane; --room selects the room (default "default")
    #|  --reply-to links this message to a received dispatch id
    #|  --from overrides the sender name (default: your pane's reported name)
  assert_true(ikesu_help_supported(0, agent, false))
  assert_false(ikesu_help_supported(1, agent, false))
  assert_false(ikesu_help_supported(0, no_prompt, false))
  assert_false(
    ikesu_help_supported(0, "ikesu agent send <target> <text>", false),
  )
  assert_true(ikesu_help_supported(0, room, true))
  assert_false(ikesu_help_supported(0, "ikesu send <to> <text>", true))
  assert_false(ikesu_help_supported(0, agent, true))
}

///|
test "notify route precedence preserves legacy environments and isolates ikesu" {
  assert_eq(
    resolve_notify_targets("", "", "", "p167", "p167", "%1"),
    ("", "p167", ""),
  )
  assert_eq(resolve_notify_targets("", "", "", "", "p2", "%1"), ("p2", "", ""))
  assert_eq(resolve_notify_targets("", "", "", "", "", "%1"), ("", "", "%1"))
  assert_eq(
    resolve_notify_targets("p3", "", "", "p167", "p2", "%1"),
    ("p3", "", ""),
  )
  assert_eq(
    resolve_notify_targets("", "p4", "", "p167", "p2", "%1"),
    ("p2", "p4", ""),
  )
  assert_eq(
    resolve_notify_targets("", "", "%2", "p167", "p2", "%1"),
    ("p2", "", "%2"),
  )
  assert_eq(
    resolve_notify_targets("p3", "p4", "%2", "p167", "p2", "%1"),
    ("p3", "p4", "%2"),
  )
}
