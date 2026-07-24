Rails.application.routes.draw do
  resource :session, only: %i[ new create destroy ]

  # Friendlier alias for the login form; /session/new still works.
  get "login", to: "sessions#new", as: :login

  resources :posts do
    resources :comments, only: :create
  end
  resources :comments, only: :destroy

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "posts#index"
end
