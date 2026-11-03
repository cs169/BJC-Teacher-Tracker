# frozen_string_literal: true

# Helpers for CSV exports that admins open in Excel / Google Sheets.
module SafeCsv
  # Cells starting with these are run as formulas by spreadsheet apps.
  FORMULA_PREFIXES = ["=", "+", "-", "@", "\t", "\r"].freeze

  # Prefix a single quote so spreadsheets show the text instead of running it
  # (OWASP "CSV injection"). Non-strings (numbers, dates, nil) pass through.
  def self.escape(value)
    return value unless value.is_a?(String) && value.start_with?(*FORMULA_PREFIXES)
    "'#{value}"
  end

  def self.row(values)
    values.map { |v| escape(v) }
  end
end
