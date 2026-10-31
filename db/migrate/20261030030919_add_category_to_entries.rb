class AddCategoryToEntries < ActiveRecord::Migration[8.1]
  def change
    add_reference :entries, :category, foreign_key: { on_delete: :nullify }
    # 0 pending, 1 automatic, 2 manual, 3 uncategorized. Entries created before this feature start uncategorized.
    add_column :entries, :categorization, :integer, null: false, default: 3
    change_column_default :entries, :categorization, from: 3, to: 0
  end
end
