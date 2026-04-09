Rails.application.routes.draw do
  scope module: :public do
    root "homes#top"
    get "/about", to: "homes#about"

    get "/sign_up", to: "users#new", as: :new_user
    post "/sign_up", to: "users#create", as: :sign_up

    get "/login", to: "sessions#new", as: :new_session
    post "/login", to: "sessions#create", as: :session
    delete "/logout", to: "sessions#destroy", as: :logout

    get "/mypage", to: "users#mypage", as: :mypage

    resources :users, only: [ :index, :show, :edit, :update, :destroy ]
    resources :posts
  end
end