Rails.application.routes.draw do
  root "uploads#new"

  resource :upload, only: %i[create], controller: "uploads"
  get "books/:uid/mcp", to: "books/mcp#show", as: :book_mcp

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :books, param: :uid, only: %i[index show create] do
        scope module: :books do
          get :toc, to: "toc#show"
          get "toc/search", to: "toc#search"
          get "pages/:page_number", to: "pages#show"
          get :search, to: "searches#show"
        end
      end
    end
  end
end
