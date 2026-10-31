require "test_helper"

class MerchantCategoryTest < ActiveSupport::TestCase
  test "normalizes descriptions into patterns" do
    assert_equal "uber trip sao paulo", MerchantCategory.pattern_for("UBER *TRIP 12/10 SÃO PAULO")
    assert_equal "", MerchantCategory.pattern_for("12/10 0001")
  end

  test "automatic results never override a manual choice" do
    MerchantCategory.remember("Padaria Pão Quente", categories(:food), source: :manual)
    MerchantCategory.remember("PADARIA PAO QUENTE", categories(:other), source: :automatic)
    assert_equal categories(:food), MerchantCategory.lookup("padaria pao quente")
  end
end
