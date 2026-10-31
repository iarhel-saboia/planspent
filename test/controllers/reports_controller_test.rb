require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "lists previous months with entries and their balance" do
    get reports_path
    assert_response :success
    assert_select "h1", text: "Relatórios Passados"
    assert_select "#reports li", count: 1
    assert_select "#reports li", text: /-R\$ 300,00/
  end

  test "search form points to the month report" do
    get reports_path
    assert_select "form[action='#{root_path}'] select#month_number"
    assert_select "form[action='#{root_path}'] select#year"
  end
end
