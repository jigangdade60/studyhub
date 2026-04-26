class Admin::BaseController < ApplicationController
  # ApplicationController で設定されている一般ユーザー認証をスキップする
  # 管理画面では独自の管理者認証を行うため
  skip_before_action :require_authentication

  # 管理者専用の認証チェックを実行する
  before_action :require_admin_authentication

  private

  # 管理者としてログインしているかを確認する処理
  def require_admin_authentication
    # Cookieからセッションを復元する
    resume_session

    # current_admin が存在すれば管理者ログイン済みとみなす
    return if current_admin.present?

    # 未ログインの場合は管理者ログイン画面へリダイレクト
    redirect_to admin_login_path, alert: "管理者ログインが必要です。"
  end
end