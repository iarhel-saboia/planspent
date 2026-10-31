require "test_helper"

class GoalsControllerTest < ActionDispatch::IntegrationTest
  test "lists goals with progress and the sidebar item" do
    goals(:trip).contribute(amount: 1000, occurred_on: Date.current)
    get goals_path
    assert_response :success
    assert_select "aside nav a[aria-current=page][aria-label=Metas]"
    assert_select "##{ActionView::RecordIdentifier.dom_id(goals(:trip))}", text: /Viagem.*R\$ 1\.000,00.*de R\$ 5\.000,00.*20%/m
    assert_select "[role=progressbar][aria-valuenow='20']"
    assert_match "/mês", response.body
  end

  test "empty state" do
    Goal.delete_all
    get goals_path
    assert_select "p", text: "Nenhuma meta ainda"
  end

  test "creates, updates and deletes a goal" do
    assert_difference("Goal.count") do
      post goals_path, params: { goal: { name: "Reserva", target_amount: "10.000,00", target_date: "", color: "emerald" } }
    end
    assert_redirected_to goals_path
    goal = Goal.last
    assert_equal BigDecimal("10000"), goal.target_amount

    patch goal_path(goal), params: { goal: { name: "Reserva de emergência" } }
    assert_equal "Reserva de emergência", goal.reload.name

    assert_difference("Goal.count", -1) { delete goal_path(goal) }
  end

  test "invalid goals re-render the form" do
    post goals_path, params: { goal: { name: "", target_amount: "0", color: "indigo" } }, as: :turbo_stream
    assert_response :unprocessable_content
    assert_match "Nome não pode ficar em branco", response.body
    assert_match 'target="new_savings_goal_form"', response.body
  end

  test "putting money aside and taking it back" do
    goal = goals(:trip)
    assert_difference("Entry.debit.count") do
      post goal_contributions_path(goal), params: { contribution: { amount: "250,00", occurred_on: Date.current, kind: "deposit" } }
    end
    assert_equal BigDecimal("250"), goal.saved_amount

    post goal_contributions_path(goal), params: { contribution: { amount: "999", occurred_on: Date.current, kind: "withdrawal" } }, as: :turbo_stream
    assert_response :unprocessable_content
    assert_match "maior que o valor guardado", response.body

    assert_difference("Entry.credit.count") do
      post goal_contributions_path(goal), params: { contribution: { amount: "50", occurred_on: Date.current, kind: "withdrawal" } }
    end
    assert_equal BigDecimal("200"), Goal.find(goal.id).saved_amount
  end

  test "reaching the target shows a congratulation" do
    post goal_contributions_path(goals(:trip)), params: { contribution: { amount: "5.000,00", occurred_on: Date.current, kind: "deposit" } }
    assert_equal "Parabéns, você atingiu a meta Viagem!", flash[:notice]
  end

  test "goal page shows its history" do
    goals(:trip).contribute(amount: 300, occurred_on: Date.current)
    get goal_path(goals(:trip))
    assert_response :success
    assert_select "#entries li", count: 1, text: /Meta: Viagem/
    assert_select "aside nav a[aria-current=page][aria-label=Metas]"
  end

  test "creates a monthly goal" do
    assert_difference("Goal.monthly.count") do
      post goals_path, params: { goal: { kind: "monthly", name: "Investir", monthly_basis: "percent", target_percent: "25", target_amount: "", color: "teal" } }
    end
    goals(:trip).contribute(amount: 1500, occurred_on: Date.current)
    get goals_path
    assert_select "##{ActionView::RecordIdentifier.dom_id(Goal.last)}", text: /Meta mensal · investir 25% do que entra/
    assert_select "##{ActionView::RecordIdentifier.dom_id(goals(:save_monthly))}", text: /Atingida.*Investido em.*R\$ 1\.500,00.*de R\$ 1\.000,00.*Passou R\$ 500,00/m
  end

  test "monthly goal page shows the last 12 months" do
    get goal_path(goals(:save_monthly))
    assert_response :success
    assert_select "#months li", count: 12
  end
end
