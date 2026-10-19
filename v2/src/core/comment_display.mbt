///|
/// Presentation only: source quotes remain unchanged for anchoring and diffs.
pub fn comment_display_quote(
  quote : String,
  value : String,
  element_text : String,
) -> String {
  js_comment_display_quote(quote, value, element_text, fn(source) { quote_source_line([source], 0) })
}

///|
extern "js" fn js_comment_display_quote(
  quote : String,
  value : String,
  element_text : String,
  stored_source_quote : (String) -> String,
) -> String =
  #|(quote, value, elementText, storedSourceQuote) => {
  #|  const descriptor = [value, elementText].map(v => String(v || "")).find(v => /^Markdown table cell\b/.test(v));
  #|  if (!descriptor) return String(quote || "");
  #|  const sourceIndex = descriptor.indexOf(" | source:");
  #|  const source = sourceIndex >= 0 ? descriptor.slice(sourceIndex + " | source:".length).trim() : "";
  #|  if (quote && String(quote).trim() !== source && String(quote).trim() !== storedSourceQuote(source)) return String(quote);
  #|  const image = descriptor.match(/^Markdown table cell: source line \d+, column \d+, image "([^"]*)"/);
  #|  if (image) return `画像「${image[1]}」`;
  #|  return descriptor.replace(/^Markdown table cell: source line \d+, column \d+: /, "").split(" | source:")[0].trim();
  #|}
