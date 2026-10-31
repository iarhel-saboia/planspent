# Data for the month chart: money invested in goals filling up to the monthly target
module MonthChartHelper
  Chart = Data.define(:summary, :target, :target_label, :goals) do
    def invested = summary.invested
    def hit? = target.present? && invested >= target
    def target_percent = target&.positive? ? (invested / target * 100).floor.clamp(0, 100) : nil

    # Progress scale: a little past the goal, so the dashed line sits inside the track
    def progress_max = [ target, invested ].compact.max.to_d * 1.2
    def progress_position(value) = progress_max.positive? ? (value.clamp(0, progress_max) / progress_max * 100).to_f.round(2) : 0

    # Credits, debits and balance share one scale
    def overview_position(value)
      max = [ summary.credits, summary.debits, summary.balance.abs ].max
      max.positive? ? (value.abs / max * 100).to_f.round(2) : 0
    end

    # [goal, amount] for each goal that received money this month, largest first
    def investments
      summary.invested_by_goal.filter_map { |id, amount| [ goals[id], amount ] if goals[id] && amount.nonzero? }.sort_by { -_2 }
    end

    def investment_position(amount)
      max = investments.map { _2.abs }.max
      max&.positive? ? (amount.abs / max * 100).to_f.round(2) : 0
    end
  end

  # The month's target: the first monthly goal, otherwise the month's share of the savings goals
  def month_chart(month, goals)
    summary = Entry.month_summary(month)
    monthly = goals.find(&:monthly?)
    target, target_label =
      if monthly
        [ monthly.month_result(month).target, monthly.name ]
      elsif (planned = goals.filter_map { |goal| goal.month_target(month) }.sum).positive?
        [ planned, "Planejado para suas metas de valor neste mês" ]
      end
    Chart.new(summary: summary, target: target, target_label: target_label, goals: goals.index_by(&:id))
  end
end
