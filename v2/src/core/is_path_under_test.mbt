///|
/// Tests for is_path_under — safe path containment without prefix bypass
///  Regression guard: `/a/b` must NOT match `/a/bad`.
test "is_path_under: exact base match is allowed" {
  debug_inspect(
    is_path_under("/a/b", "/a/b"),
    content=(
      #|true
    ),
  )
}

///|
test "is_path_under: direct child under base is allowed" {
  debug_inspect(
    is_path_under("/a/b", "/a/b/c.txt"),
    content=(
      #|true
    ),
  )
}

///|
test "is_path_under: deep descendant under base is allowed" {
  debug_inspect(
    is_path_under("/a/b", "/a/b/c/d/e.png"),
    content=(
      #|true
    ),
  )
}

///|
test "is_path_under: sibling with shared prefix is rejected" {
  debug_inspect(
    is_path_under("/a/b", "/a/bad"),
    content=(
      #|false
    ),
  )
}

///|
test "is_path_under: sibling with extended name is rejected" {
  debug_inspect(
    is_path_under("/tmp/base", "/tmp/base-evil/secret.txt"),
    content=(
      #|false
    ),
  )
}

///|
test "is_path_under: unrelated absolute path is rejected" {
  debug_inspect(
    is_path_under("/a/b", "/x/y/z"),
    content=(
      #|false
    ),
  )
}

///|
test "is_path_under: empty child is rejected" {
  debug_inspect(
    is_path_under("/a/b", ""),
    content=(
      #|false
    ),
  )
}

///|
test "is_path_under: windows-style separator under base is allowed" {
  debug_inspect(
    is_path_under("C:\\base", "C:\\base\\file.txt"),
    content=(
      #|true
    ),
  )
}

///|
test "is_path_under: windows prefix bypass is rejected" {
  debug_inspect(
    is_path_under("C:\\base", "C:\\base-evil\\file.txt"),
    content=(
      #|false
    ),
  )
}
