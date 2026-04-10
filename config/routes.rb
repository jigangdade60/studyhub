Rails.application.routes.draw do
  namespace :admin do
    get    "login",  to: "sessions#new"
    post   "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :users, only: %i[index show] do
      member do
        patch :withdraw
        patch :activate
        get :following
        get :followers
      end
    end
  end

  scope module: :public do
    root "homes#top"
    get "/about", to: "homes#about"

    get "/sign_up", to: "users#new", as: :new_user
    post "/sign_up", to: "users#create", as: :sign_up

    get "/login", to: "sessions#new", as: :new_session
    post "/login", to: "sessions#create", as: :session
    delete "/logout", to: "sessions#destroy", as: :logout

    get "/mypage", to: "users#mypage", as: :mypage

    resources :users, only: [:index, :show, :edit, :update, :destroy] do
      member do
        get :following
        get :followers
      end
    end

    resources :posts do
      resources :comments, only: [:create, :destroy]
      resource :like, only: [:create, :destroy]
    end

    resources :likes, only: [:index]

    resources :relationships, only: %i[create destroy]
  end
end