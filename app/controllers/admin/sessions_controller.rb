class Admin::SessionsController < ApplicationController
  include Authentication
  allow_unauthenticated_access only: %i[new create]

  def new
  end

  def create
    admin = Admin.find_by(email_address: params[:email_address])

    if admin&.authenticate(params[:password])
      start_new_session_for_admin(admin)
      redirect_to admin_users_path, notice: "管理者ログインしました。"
    else
      flash.now[:alert] = "メールアドレスまたはパスワードが正しくありません。"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    redirect_to admin_login_path, notice: "管理者ログアウトしました。"
  end
end
