require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  test "lists categories with this month's spending" do
    get categories_path
    assert_response :success
    assert_select "#categories li", count: Category.count
    assert_select "#categories li", text: /Moradia.*R\$ 1\.500,00/m
    assert_select "button", text: /Categorizar 1 sem categoria/
  end

  test "categorizes entries without a category using the rules" do
    entries(:old_groceries).update_columns(description: "Supermercado Bom Preço")
    Category.create!(name: "Mercado")

    post categorize_entries_path

    assert_equal "Mercado", entries(:old_groceries).reload.category.name
    assert entries(:old_groceries).categorization_automatic?
    assert_redirected_to categories_path
    assert_equal "1 de 1 lançamentos categorizados.", flash[:notice]
  end
end
