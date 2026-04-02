class SessionsController < ApplicationController
  # ログイン画面とログイン処理は未ログインでもアクセス可能
  allow_unauthenticated_access only: %i[new create]

  # ログイン試行回数の制限
  rate_limit to: 10,
             within: 3.minutes,
             only: :create,
             with: -> { redirect_to new_session_url, alert: "しばらく時間をおいて再度お試しください。" }

  def new
  end

  def create
    # メールアドレスとパスワードで認証
    if user = User.authenticate_by(params.permit(:email_address, :password))
      # 新しいセッションを開始
      start_new_session_for user

      # ログイン後はマイページへ遷移
      redirect_to mypage_path, notice: "ログインしました。"
    else
      redirect_to new_session_path, alert: "メールアドレスまたはパスワードが正しくありません。"
    end
  end

  def destroy
    # セッションを終了
    terminate_session

    redirect_to root_path, notice: "ログアウトしました。"
  end
end