require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "sidebar lists every menu item and marks the current page" do
    get reports_path
    labels = css_select("aside nav a").map { |a| a["aria-label"] }
    assert_equal [ "Início", "Relatórios Passados", "Importar extrato", "Categorias", "Orçamentos", "Metas", "Configurações" ], labels
    assert_select "aside nav a[aria-current=page]", count: 1
    assert_select "aside nav a[aria-current=page][href='#{reports_path}']"
  end

  test "sidebar starts in auto state (collapsed on phones only) and then remembers the user's choice" do
    get root_path
    assert_select "aside[data-collapsed=auto]"

    cookies[:sidebar_collapsed] = "1"
    get root_path
    assert_select "aside[data-collapsed=true]"

    cookies[:sidebar_collapsed] = "0"
    get root_path
    assert_select "aside[data-collapsed=false]"
  end

  test "future screens show a coming soon placeholder" do
    { budgets_path => "Orçamentos", settings_path => "Configurações" }.each do |path, label|
      get path
      assert_response :success
      assert_select "main h1", text: label
      assert_select "main", text: /Em breve/
    end
  end

  test "theme toggle lives in the sidebar and dark mode is rendered from cookie" do
    get root_path
    assert_select "aside button[data-action='theme#toggle']"
    assert_select "html.dark", count: 0

    cookies[:theme] = "dark"
    get root_path
    assert_select "html.dark"
  end
end
