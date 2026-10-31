require "test_helper"

class EntryCategorizerTest < ActiveSupport::TestCase
  def category_for(description, kind: :debit)
    EntryCategorizer.category_for(description, kind: kind)&.name
  end

  setup do
    %w[Assinaturas Compras Mercado Saúde Transferências].each { |name| Category.find_or_create_by!(name: name) }
  end

  test "matches keywords ignoring case, accents and punctuation" do
    assert_equal "Alimentação", category_for("IFD*BURGER KING")
    assert_equal "Transporte", category_for("UBER *TRIP 12/10")
    assert_equal "Saúde", category_for("DROGARIA SÃO PAULO")
    assert_equal "Mercado", category_for("Supermercado Pão de Açúcar")
  end

  test "keywords must be whole words and the first category in the file wins" do
    assert_nil category_for("BARBEARIA DO ZE")
    assert_equal "Assinaturas", category_for("Amazon Prime Canais")
    assert_equal "Compras", category_for("AMAZON MARKETPLACE")
    assert_equal "Compras", category_for("MERCADO LIVRE*LOJA")
    assert_equal "Transferências", category_for("PIX ENVIADO MARIA")
  end

  test "salary keywords only apply to credits" do
    assert_equal "Salário", category_for("Salário ACME", kind: :credit)
    assert_nil category_for("Salário ACME")
  end

  test "corrections remembered from the user win over the rules" do
    assert_equal "Transporte", category_for("UBER *TRIP 05/11")
    MerchantCategory.remember("UBER *TRIP", categories(:other), source: :manual)
    assert_equal "Outros", category_for("UBER *TRIP 05/11")
  end

  test "saves the result on each entry and returns how many got a category" do
    known = Entry.create!(description: "Netflix", amount: 10, kind: :debit, occurred_on: Date.current)
    unknown = Entry.create!(description: "Loja XPTO", amount: 10, kind: :debit, occurred_on: Date.current)
    assert known.categorization_automatic?
    assert unknown.categorization_uncategorized?

    unknown.update_columns(description: "Posto Ipiranga")
    assert_equal 1, EntryCategorizer.call([ unknown.reload ])
    assert_equal categories(:transport), unknown.reload.category
  end
end
