class Admin::BaseController < ApplicationController
    include Authentication
    before_action :require_admin_authentication

    private

    def require_admin_authentication
      resume_session
      redirect_to admin_login_path, alert: "管理者ログインが必要です。" unless current_admin.present?
    end
  
end