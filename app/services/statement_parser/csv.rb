# CSV statements. Each bank uses its own layout, so the columns are found by their header names
# (data, descrição/histórico, valor, crédito/débito...) or, without a header, by their contents.
class StatementParser::Csv
  HEADERS = {
    date: /\A(data|date|dt)\b/,
    description: /descri|historico|lancamento|estabelecimento|\Atitle\z|titulo|\Amemo\z|detalhe|identificacao/,
    amount: /\A(valor|amount|quantia|vlr|montante)\b/,
    credit: /\A(credito|entrada)s?\b/,
    debit: /\A(debito|saida)s?\b/,
    type: %r{\A(tipo|natureza|d/c|c/d|dc)\z}
  }.freeze

  def initialize(content)
    @content = content
  end

  def transactions
    rows = ::CSV.parse(@content, col_sep: separator, liberal_parsing: true).map { |row| row.map { |cell| cell.to_s.strip } }
    rows.reject! { |row| row.all?(&:empty?) }
    raise StatementParser::Error, "O arquivo CSV está vazio." if rows.empty?

    header_index = rows.first(20).index { |row| header_columns(row) }
    columns = header_index ? header_columns(rows[header_index]) : guess_columns(rows)
    raise StatementParser::Error, "Não foi possível identificar as colunas de data e valor neste CSV." unless columns

    build(rows.drop(header_index ? header_index + 1 : 0), columns)
  rescue ::CSV::MalformedCSVError
    raise StatementParser::Error, "Não foi possível ler o arquivo CSV."
  end

  private

  # ";" is the most common separator in Brazil, since "," is the decimal separator
  def separator
    sample = @content.lines.map(&:strip).reject(&:empty?).first(10)
    [ ";", "\t", "," ].find { |sep| sample.any? && sample.all? { |line| line.include?(sep) } } || ","
  end

  def header_columns(row)
    names = row.map { |cell| I18n.transliterate(cell).downcase.squish }
    date = names.index { |name| name.match?(HEADERS[:date]) }
    # "Data Lançamento" is a date, not a description
    columns = HEADERS.keys.to_h { |key| [ key, names.each_index.find { |i| i != date && names[i].match?(HEADERS[key]) } ] }
    columns[:date] = date

    columns if columns[:date] && (columns[:amount] || columns[:credit] || columns[:debit])
  end

  # Without a header: the date column is the one that parses as dates, the amount column the last
  # one that parses as numbers and the description the one with the longest texts
  def guess_columns(rows)
    width = rows.map(&:size).max
    share = ->(i, &test) { rows.count { |row| test.(row[i]) }.fdiv(rows.size) }

    date = (0...width).find { |i| share.(i) { |cell| StatementParser.parse_date(cell) } >= 0.6 }
    return unless date

    amount = (0...width).to_a.reverse.find do |i|
      i != date && share.(i) { |cell| cell.to_s.match?(/\d/) && cell.to_s.match?(/\A[-+(R$\s\d.,)DC]+\z/i) } >= 0.6
    end
    return unless amount

    description = ((0...width).to_a - [ date, amount ]).max_by { |i| rows.sum { |row| row[i].to_s.length } }
    { date: date, description: description, amount: amount }
  end

  def build(rows, columns)
    cells = columns[:amount] ? rows.map { |row| row[columns[:amount]].to_s } : []
    signed = cells.filter_map { |cell| StatementParser.parse_amount(cell) }
    # Credit card exports list purchases as positive values and payments as negative ones, unless
    # the file marks entries with an explicit "+"
    positive_is_debit = columns[:type].nil? && cells.none? { |cell| cell.include?("+") } &&
      signed.count(&:positive?) > signed.size / 2.0

    rows.filter_map do |row|
      amount, credit = amount_and_kind(row, columns, positive_is_debit)
      StatementParser.build(
        date: StatementParser.parse_date(row[columns[:date]]),
        description: columns[:description] ? row[columns[:description]] : nil,
        amount: amount,
        credit: credit
      )
    end
  end

  def amount_and_kind(row, columns, positive_is_debit)
    if columns[:credit] || columns[:debit]
      credit = StatementParser.parse_amount(row[columns[:credit]]) if columns[:credit]
      return [ credit, true ] if credit&.nonzero?

      debit = StatementParser.parse_amount(row[columns[:debit]]) if columns[:debit]
      return [ debit, false ] if debit&.nonzero?
      return [ nil, false ] unless columns[:amount]
    end

    amount = StatementParser.parse_amount(row[columns[:amount]])
    return [ nil, false ] unless amount

    if columns[:type]
      [ amount, row[columns[:type]].to_s.strip.upcase.start_with?("C") ]
    else
      [ amount, positive_is_debit ? amount.negative? : amount.positive? ]
    end
  end
end
