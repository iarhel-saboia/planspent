module ReportsHelper
  def report_year_options(selected = Date.current.year)
    first_year = [ Entry.minimum(:occurred_on)&.year, Date.current.year - 10 ].compact.min
    years = (first_year..Date.current.year + 1).to_a.reverse
    options_for_select(years, selected)
  end

  def report_month_options(selected = (Date.current << 1).month)
    options_for_select((1..12).map { |n| [ t("date.month_names")[n].capitalize, n ] }, selected)
  end
end
