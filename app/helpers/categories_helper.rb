module CategoriesHelper
  def category_options
    @category_options ||= Category.alphabetical.pluck(:name, :id)
  end
end
