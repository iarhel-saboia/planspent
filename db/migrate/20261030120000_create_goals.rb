class CreateGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :goals do |t|
      t.string :name, null: false
      t.decimal :target_amount, precision: 12, scale: 2, null: false
      t.date :target_date
      t.string :color, null: false, default: "indigo"
      t.timestamps
    end

    # Contributions to a goal are regular entries: a debit puts money aside, a credit takes it back
    add_reference :entries, :goal, foreign_key: { on_delete: :nullify }
  end
end
