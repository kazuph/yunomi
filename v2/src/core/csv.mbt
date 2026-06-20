///| Parse CSV/TSV content (RFC4180 compliant)

///| Returns flat 2D array: first row is headers, rest are data rows

///|
/// Empty input returns empty array
pub fn parse_csv(input : String, delimiter : Char) -> Array[Array[String]] {
  if input.is_empty() {
    return []
  }
  let rows : Array[Array[String]] = []
  let current_field = StringBuilder::new()
  let current_row : Array[String] = []
  let chars = input.to_array()
  let len = chars.length()
  let mut i = 0
  let mut in_quotes = false
  while i < len {
    let ch = chars[i]
    if in_quotes {
      if ch == '"' {
        if i + 1 < len && chars[i + 1] == '"' {
          // Escaped quote (RFC4180)
          current_field.write_char('"')
          i = i + 2
        } else {
          // End of quoted field
          in_quotes = false
          i = i + 1
        }
      } else {
        current_field.write_char(ch)
        i = i + 1
      }
    } else if ch == '"' {
      in_quotes = true
      i = i + 1
    } else if ch == delimiter {
      current_row.push(current_field.to_string())
      current_field.reset()
      i = i + 1
    } else if ch == '\r' {
      // Handle CRLF
      current_row.push(current_field.to_string())
      current_field.reset()
      let row_copy = current_row.copy()
      rows.push(row_copy)
      current_row.clear()
      if i + 1 < len && chars[i + 1] == '\n' {
        i = i + 2
      } else {
        i = i + 1
      }
    } else if ch == '\n' {
      current_row.push(current_field.to_string())
      current_field.reset()
      let row_copy = current_row.copy()
      rows.push(row_copy)
      current_row.clear()
      i = i + 1
    } else {
      current_field.write_char(ch)
      i = i + 1
    }
  }
  // Handle last field
  if current_field.to_string().length() > 0 || current_row.length() > 0 {
    current_row.push(current_field.to_string())
    rows.push(current_row.copy())
  }
  // Pop trailing empty row (cli.cjs:820-867 compat)
  if rows.length() > 0 {
    let last_row = rows[rows.length() - 1]
    if last_row.length() == 1 && last_row[0] == "" {
      ignore(rows.pop())
    }
  }
  rows
}

///|
/// Convert flat 2D CSV array to CsvData (headers + rows)
pub fn csv_data_from_flat(flat : Array[Array[String]]) -> CsvData {
  if flat.is_empty() {
    { headers: [], rows: [] }
  } else {
    let headers = flat[0]
    let data_rows : Array[Array[String]] = []
    for i in 1..<flat.length() {
      data_rows.push(flat[i])
    }
    { headers, rows: data_rows }
  }
}
