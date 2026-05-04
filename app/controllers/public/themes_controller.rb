class Public::ThemesController < ApplicationController
  def update
    current_user.update!(
      theme: current_user.dark? ? "light" : "dark"
    )

    redirect_back fallback_location: posts_path
  end
end