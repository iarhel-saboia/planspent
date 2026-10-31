class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :entries do |t|
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.integer :kind, null: false, default: 0
      t.date :occurred_on, null: false

      t.timestamps
    end
    add_index :entries, :occurred_on
  end
end
