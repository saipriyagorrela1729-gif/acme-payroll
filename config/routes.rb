Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      get "health", to: "health#show"
      get "departments", to: "meta#departments"
      get "countries", to: "meta#countries"

      resources :employees do
        resources :salary_records, only: [ :create ]
      end
    end
  end
end
