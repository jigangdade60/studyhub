Rails.application.routes.draw do
  namespace :admin do
    get "comments/index"
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

    resources :comments, only: %i[index destroy]
    resources :groups, only: %i[index destroy]
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

    resources :groups, only: %i[index show new create] do
      member do
        get :requests
      end

      resources :group_join_requests, only: %i[create]
      resources :group_messages, only: %i[create]
    end

    resources :group_join_requests, only: [] do
      member do
        patch :approve
        patch :reject
      end
    end

    resources :dm_rooms, only: %i[show create] do
      resources :dm_messages, only: :create
    end
  end
end