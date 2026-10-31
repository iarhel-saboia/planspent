class CreateMerchantCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :merchant_categories do |t|
      t.string :pattern, null: false
      t.references :category, null: false, foreign_key: { on_delete: :cascade }
      t.integer :source, null: false, default: 0

      t.timestamps
    end
    add_index :merchant_categories, :pattern, unique: true
  end
end
