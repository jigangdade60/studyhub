class Admin::BaseController < ApplicationController
  skip_before_action :require_authentication
  before_action :require_admin_authentication

  private

  def require_admin_authentication
    resume_session
    return if current_admin.present?

    redirect_to admin_login_path, alert: "管理者ログインが必要です。"
  end
end
