module EntriesHelper
  def brl(value)
    number_to_currency(value, unit: "R$", separator: ",", delimiter: ".", format: "%u %n")
  end

  def month_label(date)
    l(date, format: "%B de %Y").capitalize
  end

  def default_entry_date(month)
    month == Date.current.beginning_of_month ? Date.current : month
  end
end
