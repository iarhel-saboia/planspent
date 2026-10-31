class CreateCategories < ActiveRecord::Migration[8.1]
  DEFAULTS = [
    [ "Alimentação", "orange" ], [ "Mercado", "lime" ], [ "Transporte", "sky" ], [ "Moradia", "amber" ],
    [ "Contas e serviços", "cyan" ], [ "Saúde", "red" ], [ "Educação", "violet" ], [ "Lazer", "pink" ],
    [ "Compras", "fuchsia" ], [ "Assinaturas", "indigo" ], [ "Viagem", "teal" ], [ "Impostos e taxas", "stone" ],
    [ "Transferências", "blue" ], [ "Salário", "emerald" ], [ "Investimentos", "green" ], [ "Outros", "gray" ]
  ].freeze

  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :color, null: false, default: "gray"

      t.timestamps
    end
    add_index :categories, :name, unique: true

    reversible do |dir|
      dir.up do
        now = Time.current
        rows = DEFAULTS.map { |name, color| { name: name, color: color, created_at: now, updated_at: now } }
        Class.new(ActiveRecord::Base) { self.table_name = "categories" }.insert_all!(rows)
      end
    end
  end
end
