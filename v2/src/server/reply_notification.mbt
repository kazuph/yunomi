///|
/// Additional context only; the existing reply notification lines stay intact.
fn reply_notification_context(
  review_json : String,
  id : String,
  review_path : String,
) -> String {
  js_reply_notification_context(
    review_json,
    id,
    path_resolve(review_path),
    @core.comment_display_quote,
    @core.expand_notify_escapes,
  )
}

///|
extern "js" fn js_reply_notification_context(
  json : String,
  id : String,
  review_path : String,
  display_quote : (String, String, String) -> String,
  expand_text : (String) -> String,
) -> String =
  #|(json, id, reviewPath, displayQuote, expandText) => {
  #|  const path = process.getBuiltinModule("node:path");
  #|  const attachmentPath = ref => path.isAbsolute(ref) ? ref : path.resolve(path.dirname(reviewPath), ref);
  #|  const isRecord = value => value !== null && typeof value === "object" && !Array.isArray(value);
  #|  const review = JSON.parse(json || "{}");
  #|  const comment = (Array.isArray(review.comments) ? review.comments : []).find(c => isRecord(c) && c.id === id);
  #|  if (!comment) return "";
  #|  const lines = [];
  #|  if (comment.scope !== "round") {
  #|    const file = String(comment.file || "");
  #|    const line = Number(comment.line || (Number(comment.row || 0) + 1));
  #|    const isTableCell = [comment.value, comment.element_text].some(value => String(value || "").startsWith("Markdown table cell"));
  #|    lines.push(comment.unanchored
  #|      ? `location: (位置不明。元は ${file}:${line})`
  #|      : `location: ${file}:${line}${isTableCell && comment.col ? ` col=${comment.col}` : ""}`);
  #|    const quote = displayQuote(String(comment.quote || ""), String(comment.value || ""), String(comment.element_text || ""));
  #|    if (quote) lines.push(...quote.split("\n").map(line => "> " + line));
  #|  }
  #|  const replies = comment.replies === undefined ? [] : Array.isArray(comment.replies) ? comment.replies : [null];
  #|  const messages = [{ ...comment, author: comment.author || "human" }, ...replies].map(message => {
  #|    if (!isRecord(message)) return { unreadable: true, text: "", attachments: [] };
  #|    const text = typeof message.text === "string" ? message.text : "";
  #|    const refs = message.attachments === undefined ? [] : message.attachments;
  #|    const attachments = Array.isArray(refs) ? refs.filter(ref => typeof ref === "string") : [];
  #|    const unreadable = (message.text !== undefined && typeof message.text !== "string")
  #|      || !Array.isArray(refs) || attachments.length !== refs.length;
  #|    return { author: message.author, text, attachments, unreadable };
  #|  }).filter(message => message.unreadable || message.text.length > 0 || message.attachments.length > 0);
  #|  // The human-approved limit in TASK-2: ten earlier messages, never cut a body.
  #|  const historyLimit = 10;
  #|  const earlier = messages.slice(-historyLimit);
  #|  if (earlier.length > 0) {
  #|    lines.push(`history (${earlier.length} earlier messages, oldest first):`);
  #|    if (messages.length > earlier.length) lines.push(`  | (古い ${messages.length - earlier.length} 件は省略。全履歴: ${reviewPath})`);
  #|    for (const message of earlier) {
  #|      if (message.unreadable) lines.push("  | (読めない履歴 1 件)");
  #|      if (!message.text && message.attachments.length === 0) continue;
  #|      const author = message.author === "human" ? "human" : "agent";
  #|      lines.push(...(`${author}: ${expandText(String(message.text || ""))}`).split("\n").map(line => "  | " + line));
  #|      for (const ref of message.attachments || []) lines.push("  |   attachment: " + attachmentPath(String(ref)));
  #|    }
  #|  }
  #|  return lines.length ? "\n" + lines.join("\n") : "";
  #|}
