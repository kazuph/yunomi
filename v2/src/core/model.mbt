///|
/// File format modes
pub(all) enum FileMode {
  Csv
  Tsv
  Markdown
  Diff
  Text
} derive(Debug, Eq)

///|
pub fn FileMode::to_string(self : FileMode) -> String {
  match self {
    Csv => "csv"
    Tsv => "tsv"
    Markdown => "markdown"
    Diff => "diff"
    Text => "text"
  }
}

///|
pub fn FileMode::from_extension(ext : String) -> FileMode {
  match ext {
    "csv" => Csv
    "tsv" | "tab" => Tsv
    "md" | "markdown" => Markdown
    "diff" | "patch" => Diff
    _ => Text
  }
}

///|
/// A single review comment
pub(all) struct Comment {
  row : Int
  col : Int
  text : String
  value : String
} derive(Debug, Eq)

///|
/// A mermaid diagram error
pub(all) struct MermaidError {
  line : Int
  message : String
} derive(Debug, Eq)

///|
/// Review action: handoff (send to AI) or final submit
pub(all) enum ReviewAction {
  Handoff
  FinalApprove
  FinalRequestChanges
} derive(Debug, Eq)

///|
pub fn ReviewAction::to_string(self : ReviewAction) -> String {
  match self {
    Handoff => "handoff"
    FinalApprove => "final_approve"
    FinalRequestChanges => "final_request_changes"
  }
}

///|
pub fn ReviewAction::from_string(s : String) -> ReviewAction? {
  match s {
    "handoff" => Some(Handoff)
    "final_approve" => Some(FinalApprove)
    "final_request_changes" => Some(FinalRequestChanges)
    _ => None
  }
}

///|
/// Review decision: approve or request changes
pub(all) enum ReviewDecision {
  Approve
  RequestChanges
} derive(Debug, Eq)

///|
pub fn ReviewDecision::to_string(self : ReviewDecision) -> String {
  match self {
    Approve => "approve"
    RequestChanges => "request_changes"
  }
}

///|
pub fn ReviewDecision::from_string(s : String) -> ReviewDecision? {
  match s {
    "approve" => Some(Approve)
    "request_changes" => Some(RequestChanges)
    _ => None
  }
}

///|
/// Review result for one file
pub(all) struct ReviewResult {
  file : String
  mode : FileMode
  comments : Array[Comment]
  summary : String
  answers : String
  mermaid_errors : Array[MermaidError]
  decision : ReviewDecision?
  action : ReviewAction?
} derive(Debug)

///|
/// Parsed CSV data
pub(all) struct CsvData {
  headers : Array[String]
  rows : Array[Array[String]]
} derive(Debug)

///|
/// A single diff hunk
pub(all) struct DiffHunk {
  old_start : Int
  old_count : Int
  new_start : Int
  new_count : Int
  context : String
  lines : Array[DiffLine]
} derive(Debug)

///|
/// A line in a diff
pub(all) struct DiffLine {
  kind : DiffLineKind
  content : String
} derive(Debug, Eq)

///|
/// Type of diff line
pub(all) enum DiffLineKind {
  Context
  Addition
  Deletion
} derive(Debug, Eq)

///|
/// A parsed diff file entry
pub(all) struct DiffFile {
  old_path : String
  new_path : String
  is_new : Bool
  is_deleted : Bool
  is_binary : Bool
  hunks : Array[DiffHunk]
} derive(Debug)

///|
/// Parsed diff data
pub(all) struct DiffData {
  files : Array[DiffFile]
} derive(Debug)

///|
/// A yunomi question from frontmatter
pub(all) struct YunomiQuestion {
  id : String
  question : String
  // Judgment material / premises shown under the question text (frontmatter
  // `context:`, single-line or a `|` block scalar). Empty when the author
  // didn't supply one — fully backward compatible with pre-context
  // questions.
  context : String
  resolved : Bool
  answer : String
  options : Array[String]
} derive(Debug)

///|
/// Parsed markdown data
pub(all) struct MarkdownData {
  source : String
  html : String
  frontmatter : Map[String, String]
  questions : Array[YunomiQuestion]
} derive(Debug)
