require "test_helper"

class GoalTest < ActiveSupport::TestCase
  setup { Category.find_or_create_by!(name: "Investimentos") }

  def goal(target_date: Date.new(2027, 12, 31), created_on: Date.new(2026, 1, 1))
    Goal.create!(name: "Carro", target_amount: "12.000,00", target_date: target_date, created_at: created_on)
  end

  test "parses Brazilian amounts and validates the deadline" do
    assert_equal BigDecimal("12000"), Goal.new(target_amount: "12.000,00").target_amount
    past = Goal.new(name: "X", target_amount: 10, target_date: Date.yesterday)
    assert_not past.valid?
    assert_includes past.errors.full_messages, "Prazo deve ser uma data futura"
  end

  test "contributions are entries: debits put money aside and credits take it back" do
    trip = goals(:trip)
    deposit = trip.contribute(amount: "1.500,00", occurred_on: Date.current)
    trip.contribute(amount: "200", occurred_on: Date.current, withdrawal: true)

    assert deposit.debit?
    assert_equal "Meta: Viagem", deposit.description
    assert_equal "Investimentos", deposit.category.name
    assert_equal BigDecimal("1300"), Goal.find(trip.id).saved_amount
    assert_equal 26, Goal.find(trip.id).progress_percent
  end

  test "cannot take back more than what was saved" do
    trip = goals(:trip)
    trip.contribute(amount: 100, occurred_on: Date.current)
    withdrawal = trip.contribute(amount: 150, occurred_on: Date.current, withdrawal: true)
    assert_not withdrawal.persisted?
    assert_includes withdrawal.errors.full_messages, "Valor é maior que o valor guardado na meta"
  end

  test "months left, monthly amount needed and pace" do
    g = goal
    today = Date.new(2026, 10, 30)
    assert_equal 15, g.months_left(today)
    assert_equal BigDecimal("800"), g.monthly_needed(today)
    assert_equal :behind, g.status(today)

    g.contribute(amount: 9_000, occurred_on: today)
    g = Goal.find(g.id)
    assert_equal :on_track, g.status(today)
    assert_equal BigDecimal("214.29"), g.monthly_needed(today) # october is done: 3000 over the 14 months left

    g.contribute(amount: 3_000, occurred_on: today)
    g = Goal.find(g.id)
    assert g.completed?
    assert_equal :completed, g.status(today)
    assert_nil g.monthly_needed(today)
  end

  test "goals without a deadline and overdue goals" do
    g = goal(target_date: nil)
    assert_equal :no_deadline, g.status
    assert_nil g.monthly_needed

    g.update_column(:target_date, Date.new(2026, 5, 1))
    assert_equal :overdue, g.status(Date.new(2026, 10, 30))
  end

  test "deleting a goal keeps its entries" do
    trip = goals(:trip)
    entry = trip.contribute(amount: 100, occurred_on: Date.current)
    trip.destroy
    assert_nil entry.reload.goal
  end

  test "monthly goals compare what was invested in goals with a share of the income or a fixed amount" do
    month = Date.current.beginning_of_month
    goal = goals(:save_monthly) # 20% of what comes in; fixtures this month: salary 5000 in, rent 1500 out
    result = goal.month_result(month)
    assert_equal BigDecimal("5000"), result.income
    assert_equal BigDecimal("1000"), result.target
    assert_equal 0, result.invested
    assert_not result.hit?

    # Only money put aside in goals counts, minus withdrawals
    goals(:trip).contribute(amount: 1500, occurred_on: month)
    goals(:trip).contribute(amount: 200, occurred_on: month, withdrawal: true)
    result = Goal.find(goal.id).month_result(month)
    assert_equal BigDecimal("1300"), result.invested
    assert result.hit?
    assert_equal BigDecimal("300"), result.surplus

    fixed = Goal.create!(kind: :monthly, name: "Fixo", monthly_basis: "amount", target_amount: "1.100,00", target_percent: "10")
    assert_nil fixed.target_percent
    goals(:trip).contribute(amount: 200, occurred_on: month)
    assert_equal BigDecimal("400"), Goal.find(fixed.id).month_result(month).surplus # invested 1500, target 1100
  end

  test "monthly goals keep only the chosen basis and need a value" do
    goal = Goal.create!(kind: :monthly, name: "Percentual", monthly_basis: "percent", target_amount: "500", target_percent: "15,5")
    assert_nil goal.target_amount
    assert_equal BigDecimal("15.5"), goal.target_percent
    assert_equal "percent", Goal.find(goal.id).monthly_basis

    assert_not Goal.new(kind: :monthly, name: "X", monthly_basis: "percent", target_percent: "150").valid?
    assert_not Goal.new(kind: :monthly, name: "X", monthly_basis: "amount").valid?
  end

  test "monthly streak counts months in a row the goal was hit" do
    goal = Goal.create!(kind: :monthly, name: "Mil", target_amount: 1000)
    current = Date.current.beginning_of_month
    [ current << 2, current << 1 ].each { |m| goals(:trip).contribute(amount: 1000, occurred_on: m) }

    assert_equal 2, goal.streak(current)
    goals(:trip).contribute(amount: 1000, occurred_on: current)
    assert_equal 3, Goal.find(goal.id).streak(current)
  end

  test "a percent goal isn't hit in a month with no income and nothing invested" do
    goal = goals(:save_monthly)
    empty_month = Date.current.beginning_of_month << 6
    result = goal.month_result(empty_month)
    assert result.empty?
    assert_not result.hit?
    assert_equal 0, result.percent
    assert_equal 0, goal.streak(empty_month)

    goals(:trip).contribute(amount: 100, occurred_on: empty_month)
    result = Goal.find(goal.id).month_result(empty_month)
    assert result.hit?
    assert_not result.empty?
  end

  test "monthly goals don't take contributions" do
    entry = entries(:rent)
    assert_not entry.update(goal: goals(:save_monthly))
  end

  test "a month's target is fixed at the start of the month, so contributions don't lower it" do
    goal = Goal.create!(name: "Viagem", target_amount: 6000, target_date: Date.new(2027, 1, 31))
    october = Date.new(2026, 10, 1)
    assert_equal BigDecimal("1500"), goal.month_target(october) # 6000 over oct, nov, dec, jan

    goal.contribute(amount: 1500, occurred_on: Date.new(2026, 10, 15))
    assert_equal BigDecimal("1500"), Goal.find(goal.id).month_target(october)
    assert_equal BigDecimal("1500"), Goal.find(goal.id).month_target(Date.new(2026, 11, 1)) # 4500 over nov, dec, jan
    assert_nil Goal.find(goal.id).month_target(Date.new(2027, 2, 1))
  end
end
