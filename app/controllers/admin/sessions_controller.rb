class Admin::SessionsController < ApplicationController
  # ================================
  # 管理者ログイン用コントローラー
  # ================================
  # このコントローラーは、管理者のログイン画面表示、
  # ログイン処理、ログアウト処理を担当する。
  #
  # 一般ユーザー用の SessionsController とは別に、
  # 管理者専用のログイン処理として分けている。

  # 管理者ログインでも、共通の認証処理を利用する。
  #
  # Authentication モジュールには、
  # セッションの開始・終了、
  # current_user / current_admin の取得、
  # 認証チェックなどの共通処理が定義されている。
  include Authentication

  # ログイン画面表示とログイン実行は、
  # まだログインしていない状態でもアクセスできるようにする。
  #
  # 通常は Authentication によってログイン必須になるが、
  # ログイン画面自体は未ログインで見られないと困るため、
  # new と create だけ認証チェックをスキップしている。
  #
  # only: %i[new create]
  # → newアクションとcreateアクションだけを対象にするという意味。
  allow_unauthenticated_access only: %i[new create]

  def new
    # 管理者ログイン画面を表示するアクション。
    #
    # 特別な処理は行わず、
    # app/views/admin/sessions/new.html.erb を表示する。
    #
    # Railsでは、アクション内に処理を書かなくても、
    # アクション名に対応するビューが自動的に表示される。
  end

  def create
    # 入力されたメールアドレスをもとに、
    # 管理者アカウントを検索する。
    #
    # params[:email_address]
    # → ログインフォームで入力されたメールアドレス。
    #
    # find_by は、条件に一致するレコードがあれば取得し、
    # 見つからなければ nil を返す。
    admin = Admin.find_by(email_address: params[:email_address])

    # 管理者が存在し、かつパスワードが正しいかを確認する。
    #
    # admin&.authenticate(params[:password])
    # → admin が nil でなければ authenticate を実行する。
    #
    # authenticate は has_secure_password によって使えるメソッドで、
    # 入力されたパスワードとDBに保存されている暗号化済みパスワードを照合する。
    #
    # &. を使うことで、admin が nil の場合でもエラーにならず、
    # nil を返してログイン失敗として扱える。
    if admin&.authenticate(params[:password])
      # ログイン成功時の処理。
      #
      # start_new_session_for_admin(admin)
      # → 管理者用のセッションを新しく作成する。
      #
      # これにより、以降のリクエストで current_admin を使って
      # ログイン中の管理者を取得できるようになる。
      start_new_session_for_admin(admin)

      # ログイン成功後は、管理者用のユーザー一覧画面へ遷移する。
      #
      # notice には i18n の翻訳キーを使い、
      # 「管理者としてログインしました」のようなメッセージを表示する。
      redirect_to admin_users_path, notice: t("flash.notice.admin_logged_in")
    else
      # ログイン失敗時の処理。
      #
      # メールアドレスが存在しない場合、
      # またはパスワードが間違っている場合はこちらに入る。
      #
      # セキュリティ上、
      # 「メールアドレスが違います」
      # 「パスワードが違います」
      # のように分けず、
      # 「メールアドレスまたはパスワードが違います」のように
      # 共通のエラーメッセージにする。
      flash.now[:alert] = t("flash.alert.invalid_credentials")

      # ログイン画面を再表示する。
      #
      # redirect_to ではなく render を使うことで、
      # 同じリクエスト内で new.html.erb を表示できる。
      #
      # status: :unprocessable_entity
      # → 入力内容に問題があり処理できなかったことを表すHTTPステータス。
      #   バリデーションエラーやログイン失敗時によく使われる。
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    # 管理者ログアウト処理。
    #
    # terminate_session は Authentication モジュールに定義された
    # 共通のセッション削除処理。
    #
    # 現在のセッション情報を削除することで、
    # current_admin が取得できなくなり、ログアウト状態になる。
    terminate_session

    # ログアウト後は管理者ログイン画面へ遷移する。
    #
    # notice には i18n の翻訳キーを使い、
    # 「ログアウトしました」のようなメッセージを表示する。
    redirect_to admin_login_path, notice: t("flash.notice.admin_logged_out")
  end
end