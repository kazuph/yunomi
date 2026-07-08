///|
fn builtin_template_names() -> Array[String] {
  ["bugfix", "default", "feature"]
}

///|
fn user_templates_dir() -> String {
  let override_dir = get_env_var("YUNOMI_TEMPLATE_DIR")
  if override_dir.length() > 0 {
    override_dir
  } else {
    path_join(path_join(os_homedir(), ".yunomi"), "templates")
  }
}

///|
fn builtin_templates_dir() -> String {
  let mut dir = get_script_dir()
  for _i = 0; _i < 8; _i = _i + 1 {
    let candidate = path_join(dir, "src/templates")
    if exists_sync(candidate) {
      return candidate
    }
    let candidate_v2 = path_join(dir, "v2/src/templates")
    if exists_sync(candidate_v2) {
      return candidate_v2
    }
    dir = path_dirname(dir)
  }
  path_join(process_cwd(), "v2/src/templates")
}

///|
fn template_path(name : String) -> String {
  let user_path = path_join(user_templates_dir(), name + ".md")
  if exists_sync(user_path) {
    user_path
  } else {
    path_join(builtin_templates_dir(), name + ".md")
  }
}

///|
fn available_template_names() -> Array[String] {
  let names = builtin_template_names()
  let dir = user_templates_dir()
  if exists_sync(dir) {
    for entry in readdir_sync(dir) {
      if entry.has_suffix(".md") {
        let name = strip_md_suffix(entry)
        if !array_contains_string(names, name) {
          names.push(name)
        }
      }
    }
  }
  names
}

///|
fn array_contains_string(items : Array[String], value : String) -> Bool {
  for item in items {
    if item == value {
      return true
    }
  }
  false
}

///|
fn current_feature_slug() -> String {
  let branch = current_branch()
  let raw = if branch.has_prefix("feature/") {
    @core.safe_slice(branch, 8)
  } else if branch.length() > 0 && branch != "main" && branch != "detached" {
    branch
  } else {
    path_basename(process_cwd())
  }
  sanitize_branch_name(raw)
}

///|
extern "js" fn strip_md_suffix(name : String) -> String =
  #|(name) => String(name || "").replace(/\.md$/i, "")

///|
fn report_output_path() -> String {
  path_join(path_join(path_join(process_cwd(), ".artifacts"), current_feature_slug()), "REPORT.md")
}

///|
fn render_template(content : String, name : String) -> String {
  js_render_template(content, current_feature_slug(), name, iso_now())
}

///|
extern "js" fn js_render_template(
  content : String,
  slug : String,
  name : String,
  timestamp : String,
) -> String =
  #|(content, slug, name, timestamp) => String(content || "")
  #|  .replaceAll("{{title}}", slug)
  #|  .replaceAll("{{feature}}", slug)
  #|  .replaceAll("{{template}}", name)
  #|  .replaceAll("{{timestamp}}", timestamp)

///|
fn handle_init_command(args : Array[String]) -> Unit {
  let mut template = "default"
  let mut list = false
  let mut json_output = false
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--template" && i + 1 < args.length() {
      template = args[i + 1]
      i = i + 1
    } else if arg == "--list-templates" {
      list = true
    } else if arg == "--json" {
      json_output = true
    }
    i = i + 1
  }
  if list {
    print_template_list(json_output)
    return
  }
  let path = template_path(template)
  if !exists_sync(path) {
    console_error("yunomi init: template not found: " + template)
    exit_process("template missing", 1)
  }
  let out = report_output_path()
  if exists_sync(out) {
    console_error("yunomi init: REPORT.md already exists: " + out)
    exit_process("report exists", 1)
  }
  let dir = path_dirname(out)
  if !exists_sync(dir) {
    mkdir_sync(dir, mkdir_recursive_opts())
  }
  write_file_secure(out, render_template(read_file_safe(path), template))
  if json_output {
    process_stdout_write("{\"ok\":true,\"template\":" + json_encode_value(template) + ",\"path\":" + json_encode_value(out) + "}\n")
  } else {
    process_stdout_write("Created " + out + " from template " + template + "\n")
  }
}

///|
fn print_template_list(json_output : Bool) -> Unit {
  let names = available_template_names()
  if json_output {
    let buf = StringBuilder::new()
    buf.write_string("{\"templates\":[")
    for i, name in names {
      if i > 0 {
        buf.write_string(",")
      }
      buf.write_string(json_encode_value(name))
    }
    buf.write_string("]}\n")
    process_stdout_write(buf.to_string())
  } else {
    process_stdout_write("Available yunomi templates:\n")
    for name in names {
      process_stdout_write("- " + name + "\n")
    }
  }
}
