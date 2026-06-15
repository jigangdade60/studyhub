class PasswordsController < ApplicationController
  # パスワードリセット機能は、ログインしていないユーザーが利用する機能
  # そのため、このコントローラー全体でログイン認証をスキップする
  # 例：ログインできない人が「パスワードを忘れた場合」に使う
  allow_unauthenticated_access

  # edit と update では、URLに含まれるトークンから対象ユーザーを取得する
  # パスワードリセット用トークンが正しいかを確認し、
  # 正しい場合のみ @user に対象ユーザーをセットする
  before_action :set_user_by_token, only: %i[edit update]

  def new
    # パスワードリセット申請画面を表示する
    # ユーザーはここで登録済みのメールアドレスを入力する
  end

  def create
    # 入力されたメールアドレスに一致するユーザーを検索する
    # 見つかった場合のみ、パスワードリセットメールを送信する
    if user = User.find_by(email_address: params[:email_address])
      # パスワード再設定用のメールを非同期で送信する
      # deliver_later を使うことで、メール送信処理をバックグラウンドに回し、
      # 画面のレスポンスが遅くならないようにしている
      PasswordsMailer.reset(user).deliver_later
    end

    # セキュリティ上、メールアドレスが存在するかどうかを画面上で区別しない
    # 存在しないメールアドレスでも同じメッセージを表示することで、
    # 第三者に登録済みメールアドレスを推測されにくくしている
    redirect_to new_session_path, notice: t("flash.notice.password_reset_sent")
  end

  def edit
    # パスワード再設定画面を表示する
    # before_action の set_user_by_token により、
    # 有効なトークンの場合のみ @user が取得される
  end

  def update
    # 新しいパスワードと確認用パスワードを受け取り、ユーザー情報を更新する
    # params.permit により、更新を許可するパラメータを限定している
    # これにより、意図しないカラムが更新されることを防ぐ
    if @user.update(params.permit(:password, :password_confirmation))
      # パスワード更新に成功した場合は、ログイン画面へ遷移する
      redirect_to new_session_path, notice: t("flash.notice.password_reset_complete")
    else
      # パスワードと確認用パスワードが一致しない場合や、
      # バリデーションエラーがある場合は、再設定画面へ戻す
      redirect_to edit_password_path(params[:token]), alert: t("flash.alert.password_mismatch")
    end
  end

  private

  def set_user_by_token
    # URLパラメータの token を使って、パスワード再設定対象のユーザーを取得する
    # Rails の password_reset_token は署名付きトークンで、
    # 改ざんされていないか、有効期限内かを検証できる
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    # トークンが無効・期限切れ・改ざんされている場合は例外が発生する
    # その場合はパスワードリセット申請画面へ戻す
    redirect_to new_password_path, alert: t("flash.alert.password_reset_invalid")
  end
end
