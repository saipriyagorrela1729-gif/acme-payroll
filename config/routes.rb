Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      get "health", to: "health#show"
      get "departments", to: "meta#departments"
      get "countries", to: "meta#countries"
      get "summary", to: "summary#show"

      resources :employees do
        get :export, on: :collection
        resources :salary_records, only: [ :create ]
      end
    end
  end

  # SPA fallback: serve the built React app for any non-API path (client-side
  # routing). API requests are handled above; assets by the static server.
  get "*path", to: "home#index",
      constraints: ->(req) { !req.path.start_with?("/api", "/assets", "/up") }
end
