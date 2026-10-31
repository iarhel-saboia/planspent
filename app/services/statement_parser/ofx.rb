# OFX (Open Financial Exchange), the standard export offered by Brazilian banks, sometimes called
# "Money" or "Quicken". Handles both OFX 1.x (SGML, tags without closing) and 2.x (XML).
class StatementParser::Ofx
  def initialize(content)
    @content = content
  end

  def transactions
    blocks = @content.scan(%r{<STMTTRN>(.*?)(?=</STMTTRN>|<STMTTRN>|</BANKTRANLIST>|\z)}mi).flatten
    raise StatementParser::Error, "Nenhuma transação foi encontrada neste arquivo OFX." if blocks.empty?

    blocks.filter_map do |block|
      # OFX amounts are signed: negative is money out, also on credit card statements
      amount = StatementParser.parse_amount(field(block, "TRNAMT"))
      StatementParser.build(
        date: StatementParser.parse_date(field(block, "DTPOSTED")),
        description: field(block, "MEMO").presence || field(block, "NAME"),
        amount: amount,
        credit: amount&.positive?
      )
    end
  end

  private

  def field(block, tag)
    CGI.unescapeHTML(block[/<#{tag}>([^<\r\n]*)/i, 1].to_s.strip)
  end
end
