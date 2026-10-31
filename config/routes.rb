Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :entries, only: %i[create update destroy]
  get "relatorios", to: "reports#index", as: :reports
  get "categorias", to: "categories#index", as: :categories
  post "categorias/categorizar", to: "categories#categorize", as: :categorize_entries
  get "importar", to: "imports#new", as: :new_import
  post "importar", to: "imports#create", as: :imports
  post "importar/confirmar", to: "imports#confirm", as: :confirm_import
  resources :goals, path: "metas", only: %i[index show create update destroy] do
    resources :contributions, path: "aportes", only: :create, controller: "goal_contributions"
  end

  # Future screens, currently showing a "coming soon" placeholder
  get "orcamentos", to: "placeholders#show", as: :budgets, defaults: { page: "budgets" }
  get "configuracoes", to: "placeholders#show", as: :settings, defaults: { page: "settings" }

  root "entries#index"
end
