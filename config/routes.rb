Rails.application.routes.draw do
  root "uploads#new"

  resource :upload, only: %i[create], controller: "uploads"
  get "uploads/:uid", to: "uploads#show", as: :upload_result
  get "uploads/:uid/status", to: "uploads#status", as: :upload_status
  get "books/:uid/mcp", to: "books/mcp#show", as: :book_mcp

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :books, param: :uid, only: %i[index show create] do
        scope module: :books do
          get :toc, to: "toc#show"
          get "toc/search", to: "toc#search"
          get "pages", to: "pages#index"
          get "pages/:page_number", to: "pages#show", page_number: /\d+/
          get "sections/:id", to: "sections#show"
          get :search, to: "searches#show"
        end
      end
    end
  end
end
