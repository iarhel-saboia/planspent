# Reads a bank statement (OFX, CSV, PDF or image) and returns the transactions found in it.
# Everything runs locally: no external service is involved.
class StatementParser
  class Error < StandardError; end

  MAX_FILE_SIZE = 20.megabytes
  EXTENSIONS = %w[.ofx .qfx .csv .txt .pdf .jpg .jpeg .png .webp].freeze

  Transaction = Data.define(:occurred_on, :description, :amount, :kind)

  def self.call(file, password: nil)
    new.call(file, password: password)
  end

  def call(file, password: nil)
    raise Error, "Arquivo muito grande (máximo de 20 MB)." if file.size > MAX_FILE_SIZE

    bytes = file.read
    transactions =
      if bytes.start_with?("%PDF")
        Text.new(Pdf.new(bytes, password: password).text).transactions
      elsif image?(bytes)
        Text.new(Ocr.image(bytes)).transactions
      else
        content = decode(bytes)
        if ofx?(content)
          Ofx.new(content).transactions
        elsif File.extname(file.original_filename.to_s).downcase.in?(%w[.csv .txt])
          Csv.new(content).transactions
        else
          raise Error, "Formato não suportado. Envie o extrato em OFX, CSV, PDF ou imagem (JPG, PNG, WEBP)."
        end
      end

    transactions.reject { |t| balance_line?(t.description) }
  end

  # "1.234,56", "-1234.56", "R$ 1.234,56 D", "(12,50)" -> BigDecimal (signed)
  def self.parse_amount(value)
    text = value.to_s.strip
    return if text.empty?

    # Leading or trailing minus, accounting parentheses or a trailing "D" (débito) marker
    negative = text.include?("-") || text.match?(/\A\(.*\)\z/) || text.match?(/\d\s*D\z/i)
    digits = text.gsub(/[^\d.,]/, "")
    return if digits.empty?

    decimal = digits.rindex(",").to_i > digits.rindex(".").to_i ? "," : "."
    if decimal == "." && digits.match?(/\A\d{1,3}(\.\d{3})+\z/)
      decimal = "," # "1.234" with no cents: dots are thousand separators
    end
    thousands = decimal == "," ? "." : ","
    number = BigDecimal(digits.delete(thousands).tr(",", "."))
    negative ? -number : number
  rescue ArgumentError
    nil
  end

  # "31/10/2026", "31/10/26", "2026-10-31", "20261031" -> Date
  def self.parse_date(value)
    text = value.to_s.strip
    case text
    when %r{\A(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})}
      year = $3.length == 2 ? 2000 + $3.to_i : $3.to_i
      Date.new(year, $2.to_i, $1.to_i)
    when /\A(\d{4})-?(\d{2})-?(\d{2})/
      Date.new($1.to_i, $2.to_i, $3.to_i)
    end
  rescue Date::Error
    nil
  end

  def self.build(date:, description:, amount:, credit:)
    return if date.nil? || amount.nil? || amount.zero? || description.blank?

    Transaction.new(
      occurred_on: date,
      description: description.squish.truncate(120),
      amount: amount.abs.round(2),
      kind: credit ? "credit" : "debit"
    )
  end

  private

  # Brazilian banks often export in Windows-1252 (Latin-1) instead of UTF-8
  def decode(bytes)
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    text = bytes.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8) unless text.valid_encoding?
    text.delete_prefix("﻿")
  rescue EncodingError
    raise Error, "Não foi possível ler o arquivo. Verifique se é um extrato em OFX ou CSV."
  end

  def image?(bytes)
    bytes.start_with?("\x89PNG".b, "\xFF\xD8".b) || (bytes.start_with?("RIFF") && bytes[8, 4] == "WEBP")
  end

  def ofx?(content)
    content.match?(/OFXHEADER|<OFX>/i)
  end

  def balance_line?(description)
    I18n.transliterate(description).match?(/\Asaldo\b|\bsaldo (anterior|do dia|final|atual|em conta)\b/i)
  end
end
