require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "seeds create the default categories on an empty database, so sample entries get categorized" do
    Entry.delete_all
    MerchantCategory.delete_all
    Category.delete_all

    Rails.application.load_seed

    assert_equal 16, Category.count
    assert_equal "Moradia", Entry.find_by(description: "Aluguel").category&.name

    assert_no_difference "Category.count" do
      Rails.application.load_seed
    end
  end
end
