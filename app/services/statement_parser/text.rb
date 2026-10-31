# Transactions from the plain text of a PDF or photo. Statements list one transaction per line,
# starting with a date and ending with the amount (sometimes followed by the running balance):
#
#   01/10/2026  PIX ENVIADO MARIA            -150,00     1.234,56
#   05 OUT      IFOOD *RESTAURANTE              58,90
#
# Some banks (e.g. Banco do Brasil) split the description over the lines around the dated one,
# with the type above and the counterparty below, plus internal lot/document numbers:
#
#                                                    Pix - Recebido
#   01/09/2026  14397  1201751422  01/09 20:17 77469020306 FULANO DE TAL   1.351,00 (+)
class StatementParser::Text
  PAGE_BREAK = :page_break
  MONTHS = %w[jan fev mar abr mai jun jul ago set out nov dez].freeze
  MONTH_NAMES = %w[janeiro fevereiro marco março abril maio junho julho agosto setembro outubro novembro dezembro] + MONTHS
  # "01/10/2026", "01/10/26", "01/10", "05 OUT", "05 out. 2026", "5 de outubro"
  DATE = %r{\A(?<day>\d{1,2})(?:[/.-](?<month>\d{1,2})(?:[/.-](?<year>\d{2,4}))?|\s+(?:de\s+)?(?<month_name>#{MONTH_NAMES.join("|")})\.?(?:[/\s](?<year>\d{4}))?)(?=[\s/]|\z)}i
  # "-150,00", "+ R$ 4.200,00", "(-) R$ 150,00", "R$ -150,00", "150,00-", "150,00 D", "150,00 (-)"
  AMOUNT = /(?:\(?[-+]\)?\s*)?(?:R\$\s*)?(?:[-+]\s*)?\d{1,3}(?:\.\d{3})*,\d{2}(?:[-+]|\s?[DC]\b|\s?\([-+]\))?/i
  # Date and time of a Pix/transfer printed in the description: "01/09 20:17"
  DETAIL_PREFIX = %r{\A\d{1,2}/\d{1,2}(?:/\d{2,4})?\s+\d{1,2}:\d{2}\b}
  CREDIT_WORDS = /recebid|credito|salario|deposito|estorno|reembolso|rendimento|resgate|devolucao|pagamento (recebido|efetuado)/
  SKIP_WORDS = /\A(total|subtotal|limite|saldo|pagamento minimo|valor total|informacoes)\b/

  def initialize(text)
    # PDFs often use the Unicode minus or dashes for negative amounts; pages are separated by \f
    @lines = text.to_s.tr("−–—", "---").lines
      .map { |line| line.include?("\f") ? PAGE_BREAK : line.squish }
      .reject { |line| line == "" }
  end

  def transactions
    rows = merged_rows
    raise StatementParser::Error, "Nenhuma transação foi encontrada no arquivo. Confira se o texto está legível." if rows.empty?

    # Statements that mark entries with "+" sign both ways: "+" is money in and "-" money out.
    # Account statements sign most lines (the debits), so unsigned amounts are credits. Credit card
    # bills leave purchases unsigned and only sign payments and refunds.
    account = rows.any? { |row| row[:plus] } || rows.count { |row| row[:amount].negative? } >= rows.size / 2.0
    rows.filter_map do |row|
      description = [ row[:before], row[:description], row[:after] ].compact_blank.join(" ")
      normalized = I18n.transliterate(description).downcase
      credit = account ? row[:amount].positive? : row[:amount].negative? || normalized.match?(CREDIT_WORDS)
      StatementParser.build(date: date_for(row), description: description, amount: row[:amount], credit: credit)
    end
  end

  private

  # Dated lines with an amount become rows; the loose lines between two rows complete their
  # descriptions. The last loose line goes down when it is a type header ("Pix - Enviado") and the
  # next row has none; the first one goes up as the continuation of the previous row.
  def merged_rows
    rows = []
    loose = []
    @lines.each do |line|
      if line == PAGE_BREAK
        loose = [] # page headers and footers
      elsif (row = parse_line(line))
        row[:before] = loose.pop if loose.any? && header_for?(loose.last, row)
        rows.last[:after] ||= loose.first if rows.any? && loose.any?
        rows << row
        loose = []
      elsif loose_description?(line)
        loose << line
      end
    end
    rows.last[:after] ||= loose.first if rows.any? && loose.any?
    rows.reject { |row| row[:skip] }.each { |row| row[:after] = clean(row[:after]) if row[:after] }
  end

  def parse_line(line)
    date = line.match(DATE) or return
    rest = line[date.end(0)..]
    amounts = rest.to_enum(:scan, AMOUNT).map { Regexp.last_match }
    return if amounts.empty? || rest[amounts.last.end(0)..].match?(/[[:alpha:]]{3,}/)

    # With two or more trailing amounts, the last one is the running balance
    amount_match = amounts.size >= 2 ? amounts[-2] : amounts.last
    # Lot and document numbers that come before the description
    text = rest[0...amounts.first.begin(0)].squish.delete_suffix("R$").strip.sub(/\A(?:\d{3,}\s+)*\d{3,}(?:\s+|\z)/, "")
    normalized = I18n.transliterate(text).downcase

    {
      date: date,
      description: clean(text),
      detail_only: text.empty? || text.match?(DETAIL_PREFIX),
      amount: StatementParser.parse_amount(amount_match[0]),
      plus: amount_match[0].include?("+"),
      # Balance lines, including "S A L D O"
      skip: normalized.match?(SKIP_WORDS) || normalized.delete(" ").start_with?("saldo")
    }
  end

  # A short line with no numbers, such as "Pix - Recebido" or "Cobrança de Juros"
  def header_for?(line, row)
    row[:detail_only] && line.length <= 40 && !line.match?(/\d/)
  end

  def loose_description?(line)
    normalized = I18n.transliterate(line).downcase
    line.length <= 60 && !line.match?(AMOUNT) && !line.include?("%") && !normalized.match?(SKIP_WORDS)
  end

  # "01/09 20:17 77469020306 FULANO" -> "FULANO" (date/time of the Pix, CPF/CNPJ, second date column)
  def clean(text)
    text.sub(%r{\A\d{1,2}/\d{1,2}(?:/\d{2,4})?(?:\s+\d{1,2}:\d{2})?(?:\s+|\z)}, "")
      .sub(/\A(?:\d{11}|\d{14}|[\d.*-]{14,18})(?:\s+|\z)/, "")
      .strip
  end

  def date_for(row)
    match = row[:date]
    month = match[:month_name] ? MONTHS.index(I18n.transliterate(match[:month_name][0, 3]).downcase).to_i + 1 : match[:month].to_i
    year = match[:year] ? match[:year].to_i : nil
    year += 2000 if year && year < 100
    date = Date.new(year || statement_year, month, match[:day].to_i)
    # A December purchase on a January statement without years belongs to the previous year
    !year && date > Date.current + 31 ? date.prev_year : date
  rescue Date::Error
    nil
  end

  # The year printed most often in the statement (period, issue date), or the current year
  def statement_year
    @statement_year ||= @lines.grep(String).join(" ").scan(/\b(20\d{2})\b/).flatten.tally.max_by(&:last)&.first&.to_i || Date.current.year
  end
end
