# config/routes.rb

scope module: :public do
  root "homes#top"
  get "about", to: "homes#about"
end

resource :session, 