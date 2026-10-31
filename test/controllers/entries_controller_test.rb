require "test_helper"

class EntriesControllerTest < ActionDispatch::IntegrationTest
  test "index shows current month totals" do
    get root_path
    assert_response :success
    assert_select "p", text: "R$ 5.000,00"
    assert_select "p", text: "R$ 1.500,00"
    assert_select "p", text: "R$ 3.500,00"
    assert_select "#entries li", count: 2
  end

  test "index shows another month via select param" do
    month = Date.current.beginning_of_month << 2
    get root_path(month: month.strftime("%Y-%m"))
    assert_response :success
    assert_select "#entries li", count: 1
    assert_select "#entries li", text: /Mercado antigo/
  end

  test "creates a debit and categorizes it" do
    assert_difference "Entry.debit.count" do
      post entries_path, params: { entry: { kind: "debit", amount: "45,90", description: "Pizza", occurred_on: Date.current } }
    end
    assert Entry.last.categorization_automatic?
    assert_equal categories(:food), Entry.last.category
    assert_redirected_to root_path(month: Date.current.strftime("%Y-%m"))
    assert_equal BigDecimal("45.90"), Entry.last.amount
  end

  test "creates a credit" do
    assert_difference "Entry.credit.count" do
      post entries_path, params: { entry: { kind: "credit", amount: "200", description: "Freela", occurred_on: Date.current } }
    end
  end

  test "invalid entry re-renders form via turbo stream" do
    assert_no_difference "Entry.count" do
      post entries_path, params: { entry: { kind: "debit", amount: "", description: "", occurred_on: Date.current } },
        as: :turbo_stream
    end
    assert_response :unprocessable_content
    assert_match "debit_form", response.body
  end

  test "destroys an entry" do
    assert_difference "Entry.count", -1 do
      delete entry_path(entries(:rent))
    end
  end

  test "month select lists 6 previous months, current month and 5 next months in order" do
    travel_to Date.new(2026, 10, 15) do
      get root_path
      values = css_select("select#month option").map { |o| o["value"] }
      assert_equal %w[2026-04 2026-05 2026-06 2026-07 2026-08 2026-09 2026-10 2026-11 2026-12 2027-01 2027-02 2027-03], values
      assert_select "select#month option[selected]", text: "Outubro de 2026"
    end
  end

  test "index accepts year and month_number params, even outside the header select range" do
    get root_path(year: 2020, month_number: 3)
    assert_response :success
    assert_select "h1", text: "Março de 2020"
  end

  test "changing the category from the entry row" do
    patch entry_path(entries(:salary)), params: { entry: { category_id: categories(:other).id } }, as: :turbo_stream
    assert_response :success
    assert entries(:salary).reload.categorization_manual?
    assert_equal categories(:other), entries(:salary).category
  end

  test "entry rows show the category selector" do
    get root_path
    assert_select "##{ActionView::RecordIdentifier.dom_id(entries(:rent))} select[name='entry[category_id]'] option[selected]", text: "Moradia"
  end

  test "home shows the goals block" do
    goals(:trip).contribute(amount: 500, occurred_on: Date.current)
    get root_path
    assert_select "#home_goals li", count: 2
    assert_select "#home_goals li", text: /Guardar todo mês.*R\$ 500,00.*de R\$ 1\.000,00/m
    assert_select "#home_goals li", text: /Viagem.*R\$ 500,00.*de R\$ 5\.000,00/m
    assert_select "button[data-controller=goal-link]"
    assert_select "dialog#goal_link_modal select[name='entry[goal_id]'] option", text: "Viagem"
  end

  test "linking an entry to a savings goal and unlinking it" do
    entry = Entry.create!(description: "Aplicação CDB", amount: 800, kind: :debit, occurred_on: Date.current)

    patch entry_path(entry), params: { entry: { goal_id: goals(:trip).id } }
    assert_redirected_to root_path(month: Date.current.strftime("%Y-%m"))
    assert_equal "Lançamento vinculado à meta Viagem.", flash[:notice]
    assert_equal BigDecimal("800"), Goal.find(goals(:trip).id).saved_amount

    get root_path
    assert_select "##{ActionView::RecordIdentifier.dom_id(entry)} a[href='#{goal_path(goals(:trip))}']", text: /Viagem/

    patch entry_path(entry), params: { entry: { goal_id: "" } }
    assert_nil entry.reload.goal
  end

  test "a linked credit can't take back more than was saved" do
    patch entry_path(entries(:salary)), params: { entry: { goal_id: goals(:trip).id } }
    assert_match "maior que o valor guardado", flash[:alert]
    assert_nil entries(:salary).reload.goal
  end

  test "month chart: income, expenses and balance, then money invested filling up to the dashed monthly target" do
    month_name = I18n.l(Date.current, format: "%B").downcase
    goals(:trip).contribute(amount: 1500, occurred_on: Date.current)
    get root_path
    assert_select "dialog#month_chart_modal h2", text: "Resumo de #{month_name}"
    assert_select "#month_chart" do
      assert_select "dt", text: "Entradas"
      assert_select "dd", text: "R$ 5.000,00"
      assert_select "dt", text: "Saídas"
      assert_select "dd", text: "R$ 3.000,00" # rent 1500 + 1500 put aside
      assert_select "dt", text: "Saldo"
      assert_select "dd", text: "R$ 2.000,00"
      assert_select "p", text: /As saídas incluem R\$ 1\.500,00 guardados em metas/
      assert_select "[role=progressbar][aria-label=?]", "Investido em #{month_name}: R$ 1.500,00 de R$ 1.000,00"
      assert_select ".border-dashed", 1
      assert_select "p", text: /Você passou da meta em R\$ 500,00/
      assert_select "dt", text: /Viagem/
      assert_select "dd", text: "R$ 1.500,00", count: 1
    end
  end

  test "home layout: totals and add buttons in one row on top, then entries and goals, chart in a dialog" do
    get root_path
    body = response.body
    assert_operator body.index('id="month_totals"'), :<, body.index('id="entries"')
    assert_operator body.index('id="entries"'), :<, body.index('id="home_goals"')
    assert_select "#month_totals > div", count: 4
    assert_select "#month_totals > div:last-child button", count: 2
    assert_select "button[data-modal-trigger-dialog-value=month_chart_modal]", text: /Ver gráfico/
    assert_select "dialog#month_chart_modal.max-w-2xl #month_chart"
  end
end
