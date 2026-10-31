class CategoriesController < ApplicationController
  def index
    @month = Date.current.beginning_of_month
    @totals = Entry.debit.in_month(@month).where.not(category_id: nil).group(:category_id).sum(:amount)
    @counts = Entry.in_month(@month).group(:category_id).count
    @categories = Category.alphabetical.sort_by { |category| -@totals.fetch(category.id, 0) }
    @uncategorized_count = Entry.categorization_uncategorized.count
  end

  # Runs the rules and the learned corrections again on every entry without a category
  def categorize
    entries = Entry.categorization_uncategorized.to_a
    categorized = EntryCategorizer.call(entries)
    notice =
      if entries.empty? then "Nenhum lançamento sem categoria."
      elsif categorized.zero? then "Nenhuma categoria encontrada. Escolha a categoria manualmente para o sistema aprender."
      else "#{categorized} de #{entries.size} lançamentos categorizados."
      end
    redirect_to categories_path, notice: notice
  end
end
