require "test_helper"

class MonthChartHelperTest < ActionView::TestCase
  test "uses the first monthly goal as the target and counts money invested in goals" do
    goals(:trip).contribute(amount: 1500, occurred_on: Date.current)
    chart = month_chart(Date.current, Goal.by_creation.to_a)
    assert_equal BigDecimal("1000"), chart.target # 20% of 5000
    assert_equal "Guardar todo mês", chart.target_label
    assert_equal BigDecimal("1500"), chart.invested
    assert chart.hit?
    assert_equal [ [ goals(:trip), BigDecimal("1500") ] ], chart.investments
  end

  test "without a monthly goal, the target is the savings goals' share for the month" do
    chart = month_chart(Date.current, [ goals(:trip) ])
    assert_equal goals(:trip).month_target, chart.target
    assert_equal "Planejado para suas metas de valor neste mês", chart.target_label
    assert_nil month_chart(Date.current, []).target
  end

  test "progress scale leaves room past the larger of invested and target" do
    goals(:trip).contribute(amount: 1500, occurred_on: Date.current)
    chart = month_chart(Date.current, Goal.by_creation.to_a)
    assert_equal BigDecimal("1800"), chart.progress_max
    assert_in_delta 55.56, chart.progress_position(1000), 0.01
    assert_equal 0, chart.progress_position(-50)
  end

  test "withdrawals reduce what was invested" do
    goals(:trip).contribute(amount: 300, occurred_on: Date.current)
    goals(:trip).contribute(amount: 100, occurred_on: Date.current, withdrawal: true)
    assert_equal BigDecimal("200"), month_chart(Date.current, []).invested
  end
end
