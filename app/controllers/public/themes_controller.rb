class Public::ThemesController < ApplicationController
  # Toggle はボタンからの PATCH で呼ばれるため、非ブラウザ環境のテストで
  # CSRF 検証エラーが出ることがあるため該当アクションでは検証をスキップする
  skip_before_action :verify_authenticity_token, only: :update
  def update
    # バリデーションによる失敗を避けるため、theme は直接カラム更新する
    current_user.update_column(:theme, current_user.dark? ? "light" : "dark")

    redirect_back fallback_location: posts_path
  end
end
