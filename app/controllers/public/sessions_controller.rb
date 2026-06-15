module Public
  class SessionsController < ApplicationController
    # =========================
    # 認証制御
    # =========================

    # 通常、このアプリでは ApplicationController 側で
    # ログインしていないユーザーを制限している。
    #
    # ただし、ログイン画面の表示 new とログイン処理 create は、
    # まだログインしていないユーザーが使う機能なので、
    # 未ログインでもアクセスできるようにしている。
    allow_unauthenticated_access only: %i[new create]

    # =========================
    # ログイン画面表示
    # =========================

    def new
      # ログインフォームを表示するためのアクション。
      #
      # 特別なデータ取得は不要なので、中身は空。
      # Railsでは対応するビュー
      # app/views/public/sessions/new.html.erb
      # が自動的に表示される。
    end

    # =========================
    # ログイン処理
    # =========================

    def create
      # フォームから送信されたメールアドレスを使って、
      # 該当するユーザーをデータベースから1件検索する。
      #
      # find_by は条件に一致する最初の1件を返し、
      # 見つからなければ nil を返す。
      user = User.find_by(email_address: params[:email_address])

      # user&.authenticate(params[:password]) でパスワードを検証する。
      #
      # &. は safe navigation operator と呼ばれ、
      # user が nil の場合でもエラーにならず nil を返す。
      #
      # authenticate は has_secure_password によって使えるメソッドで、
      # 入力されたパスワードと、DBに保存されている password_digest を照合する。
      #
      # 認証成功時は user オブジェクトを返し、
      # 失敗時は false を返す。
      if user&.authenticate(params[:password])

        # メールアドレスとパスワードが正しくても、
        # 退会済みユーザーはログインできないようにする。
        #
        # is_active? はユーザーが有効状態かどうかを判定するメソッド。
        if user.is_active?

          # 認証に成功し、かつ有効ユーザーであれば、
          # 新しいログインセッションを開始する。
          #
          # start_new_session_for は Authentication モジュールなどで定義されている想定。
          # セッション情報を作成し、ログイン状態を保持する役割。
          start_new_session_for user

          # ログイン後はマイページへ遷移する。
          #
          # notice には成功メッセージを設定する。
          # t("flash.notice.login") により、
          # ja.yml などの翻訳ファイルからメッセージを取得する。
          redirect_to mypage_path, notice: t("flash.notice.login")
        else
          # ユーザーが退会済みの場合はログインさせず、
          # ログイン画面へ戻す。
          #
          # alert にはエラーメッセージを設定する。
          redirect_to new_session_path, alert: t("flash.alert.account_withdrawn")
        end
      else
        # メールアドレスが存在しない、またはパスワードが間違っている場合は
        # ログイン失敗としてログイン画面へ戻す。
        #
        # 「メールアドレスが違う」「パスワードが違う」と分けず、
        # 認証情報が正しくない、という共通メッセージにしている。
        #
        # これは、どのメールアドレスが登録済みかを外部に推測されにくくするため。
        redirect_to new_session_path, alert: t("flash.alert.invalid_credentials")
      end
    end

    # =========================
    # ログアウト処理
    # =========================

    def destroy
      # 現在のログインセッションを終了する。
      #
      # terminate_session は Authentication モジュールなどで定義されている想定。
      # セッション情報を削除し、ログアウト状態にする役割。
      terminate_session

      # ログアウト後はトップページへ遷移する。
      #
      # notice にはログアウト完了メッセージを表示する。
      redirect_to root_path, notice: t("flash.notice.logout")
    end
  end
end
