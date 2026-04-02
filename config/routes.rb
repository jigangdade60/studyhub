Rails.application.routes.draw do
  # topページ
  root "homes#top"

  # aboutページ
  get "/about", to: "homes#about"

  # サインアップ関連
  get "/sign_up", to: "users#new", as: :new_user
  post "/sign_up", to: "users#create", as: :users

  # ログイン関連
  get "/login", to: "sessions#new", as: :new_session
  post "/login", to: "sessions#create", as: :session
  delete "/logout", to: "sessions#destroy", as: :logout

  # マイページ関連
  get "/mypage", to: "users#mypage", as: :mypage

  # ユーザー関連
  resources :users, only: [ :new, :create, :edit, :update, :destroy ]

  # 投稿関連
  resources :posts
end