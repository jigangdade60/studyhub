class Admin::SessionsController < ApplicationController
  # 管理者ログインでも共通の認証処理を使う
  include Authentication

  # ログイン画面表示とログイン実行は未認証でもアクセスできるようにする
  allow_unauthenticated_access only: %i[new create]

  def new
  end

  def create
    # 入力されたメールアドレスから管理者アカウントを検索する
    admin = Admin.find_by(email_address: params[:email_address])

    # has_secure_password の authenticate でパスワードを検証する
    if admin&.authenticate(params[:password])
      # 管理者用セッションを作成して管理画面トップへ遷移する
      start_new_session_for_admin(admin)
      redirect_to admin_users_path, notice: "管理者ログインしました。"
    else
      # ログイン失敗時は入力画面を再表示し、エラーメッセージを表示する
      flash.now[:alert] = "メールアドレスまたはパスワードが正しくありません。"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    # 管理者ログアウト時も共通のセッション削除処理を使う
    terminate_session
    redirect_to admin_login_path, notice: "管理者ログアウトしました。"
  end
end