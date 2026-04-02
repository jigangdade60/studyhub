Rails.application.routes.draw do
  scope module: :public do
    # トップ・アバウト
    root "homes#top"
    get "about", to: "homes#about"

    # ユーザー登録
    get "sign_up", to: "users#new"
    post "sign_up", to: "users#create"

    # 投稿CRUD
    resources :posts
  end

  # セッション（ログイン）
  resource :session, only: [:new, :create, :destroy]
end