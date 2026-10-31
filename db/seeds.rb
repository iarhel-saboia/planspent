# Default categories. They must exist on a fresh database too (db:prepare loads schema.rb and skips the
# data in the create_categories migration), and before the sample entries so these get categorized.
[
  [ "Alimentação", "orange" ], [ "Mercado", "lime" ], [ "Transporte", "sky" ], [ "Moradia", "amber" ],
  [ "Contas e serviços", "cyan" ], [ "Saúde", "red" ], [ "Educação", "violet" ], [ "Lazer", "pink" ],
  [ "Compras", "fuchsia" ], [ "Assinaturas", "indigo" ], [ "Viagem", "teal" ], [ "Impostos e taxas", "stone" ],
  [ "Transferências", "blue" ], [ "Salário", "emerald" ], [ "Investimentos", "green" ], [ "Outros", "gray" ]
].each do |name, color|
  Category.find_or_create_by!(name: name) { |category| category.color = color }
end

# Dados de exemplo: bin/rails db:seed
month = Date.current.beginning_of_month

[
  [ "Salário", 6500, :credit, month ],
  [ "Freelance", 1200, :credit, month + 9 ],
  [ "Aluguel", 1800, :debit, month + 4 ],
  [ "Mercado", 642.37, :debit, month + 6 ],
  [ "Internet", 119.90, :debit, month + 9 ],
  [ "Salário", 6500, :credit, month << 1 ],
  [ "Aluguel", 1800, :debit, (month << 1) + 4 ],
  [ "Viagem", 2300, :debit, (month << 1) + 15 ]
].each do |description, amount, kind, date|
  Entry.find_or_create_by!(description: description, kind: kind, occurred_on: date) { |e| e.amount = amount }
end
