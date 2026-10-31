require "test_helper"

class EntryTest < ActiveSupport::TestCase
  test "parses Brazilian formatted amounts" do
    assert_equal BigDecimal("1234.56"), Entry.new(amount: "1.234,56").amount
    assert_equal BigDecimal("12.5"), Entry.new(amount: "12,50").amount
    assert_equal BigDecimal("99.9"), Entry.new(amount: "99.90").amount
  end

  test "requires positive amount and description" do
    entry = Entry.new(kind: :debit, occurred_on: Date.current, amount: "0")
    assert_not entry.valid?
    assert entry.errors.of_kind?(:amount, :greater_than)
    assert entry.errors.of_kind?(:description, :blank)
  end

  test "in_month scope filters by month" do
    assert_equal %w[Aluguel Salário], Entry.in_month(Date.current).pluck(:description).sort
  end

  test "manual categorization is learned and applied to automatic entries with the same description" do
    a = Entry.create!(description: "UBER *TRIP 01/10", amount: 20, kind: :debit, occurred_on: Date.current, category: categories(:transport), categorization: :automatic)
    b = Entry.create!(description: "UBER *TRIP 05/10", amount: 30, kind: :debit, occurred_on: Date.current, category: categories(:transport), categorization: :automatic)

    a.categorize_manually!(categories(:other))

    assert a.reload.categorization_manual?
    assert_equal categories(:other), b.reload.category
    assert_equal categories(:other), MerchantCategory.lookup("UBER *TRIP")
  end
end
