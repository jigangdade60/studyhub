scope module: :public do
  root "homes#top"
  get "about", to: "homes#about"

  get "sign_up", to: "users#new"
  post "sign_up", to: "users#create"
end