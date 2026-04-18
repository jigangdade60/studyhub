module Public
  class SessionsController < ApplicationController
    allow_unauthenticated_access only: %i[new create]

    def new
    end

    def create
      user = User.find_by(email_address: params[:email_address])

      if user&.authenticate(params[:password])
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