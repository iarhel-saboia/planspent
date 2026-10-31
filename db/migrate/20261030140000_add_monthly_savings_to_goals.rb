class AddMonthlySavingsToGoals < ActiveRecord::Migration[8.1]
  def change
    # savings: reach a total amount; monthly: save a fixed amount or a share of the income every month
    add_column :goals, :kind, :integer, null: false, default: 0
    add_column :goals, :target_percent, :decimal, precision: 5, scale: 2
    change_column_null :goals, :target_amount, true
  end
end
