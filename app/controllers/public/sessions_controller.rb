module Public
  class SessionsController < ApplicationController
    # ログイン画面表示とログイン実行は未認証でもアクセスできるようにする
    allow_unauthenticated_access only: %i[new create]

    def new
    end

    def create
      # 入力されたメールアドレスからユーザーを検索する
      user = User.find_by(email_address: params[:email_address])

      # has_secure_password の authenticate でパスワードを検証する
      if user&.authenticate(params[:password])
        # 退会済みユーザーはログインさせない
        if user.is_active?
          start_new_session_for user
          redirect_to mypage_path, notice: "ログインしました。"
        else
          redirect_to new_session_path, alert: "このアカウントは退会済みです。"
        end
      else
        redirect_to new_session_path, alert: "メールアドレスまたはパスワードが正しくありません。"
      end
    end

    def destroy
      terminate_session
      redirect_to root_path, notice: "ログアウトしました。"
    end
  end
end