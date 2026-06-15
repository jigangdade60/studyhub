# 認証処理を共通化するためのモジュール
#
# ApplicationController などに include することで、
# ログイン状態の確認、現在ログイン中のユーザー取得、
# セッション開始・終了処理を共通で使えるようにする。
#
# Rails 8 の標準認証に近い考え方で、
# DB上の Session レコードと Cookie を使ってログイン状態を管理している。
module Authentication
  extend ActiveSupport::Concern

  # included do は、このモジュールを include したクラスに
  # 自動で設定を追加するための書き方。
  #
  # ここでは ApplicationController に include される想定で、
  # before_action や helper_method をまとめて設定している。
  included do
    # =========================
    # セッション復元
    # =========================

    # 毎リクエストの最初に、Cookie に保存されている session_id をもとに
    # DB上の Session レコードを探し、Current.session にセットする。
    #
    # これにより、ログイン必須ページだけでなく、
    # 公開ページでも current_user / current_admin を使えるようになる。
    before_action :resume_session

    # =========================
    # 認証チェック
    # =========================

    # 基本的には全ページをログイン必須にする。
    #
    # ログイン不要なページだけ、
    # 各Controller側で allow_unauthenticated_access を使って除外する。
    #
    # 例：
    # allow_unauthenticated_access only: %i[index show]
    before_action :require_authentication

    # =========================
    # Viewで使えるメソッド
    # =========================

    # Controller内の private メソッドは、そのままだとViewから呼び出せない。
    #
    # helper_method に指定することで、
    # ERBファイルなどのViewでも以下のメソッドを使えるようにしている。
    #
    # 例：
    # <% if authenticated? %>
    #   <%= current_user.name %>
    # <% end %>
    helper_method :authenticated?, :current_user, :current_admin, :admin_authenticated?
  end

  # class_methods do は、
  # このモジュールを include したControllerクラス側で使える
  # クラスメソッドを定義するための書き方。
  class_methods do
    # =========================
    # 未ログインでもアクセス可能にする設定
    # =========================

    # デフォルトでは require_authentication によりログイン必須だが、
    # ログイン画面、新規登録画面、トップページなどは
    # 未ログインでもアクセスできる必要がある。
    #
    # そのため、Controller側でこのメソッドを呼び出すことで、
    # 指定したアクションだけ認証チェックをスキップできる。
    #
    # 例：
    # allow_unauthenticated_access only: %i[new create]
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  # =========================
  # ログイン状態の判定
  # =========================

  # 一般ユーザーでログインしているかを判定するメソッド。
  #
  # current_user が存在すればログイン済み、
  # nil なら未ログインと判断する。
  def authenticated?
    current_user.present?
  end

  # 管理者でログインしているかを判定するメソッド。
  #
  # 一般ユーザーと管理者のログイン状態を分けて判定することで、
  # 管理者画面では admin_authenticated? を使って制御できる。
  def admin_authenticated?
    current_admin.present?
  end

  # =========================
  # 現在ログイン中のユーザー取得
  # =========================

  # 現在ログインしている一般ユーザーを取得する。
  #
  # Current.user は、Current.session に紐づく user を返す想定。
  # これにより、ControllerやViewで毎回 Session を探す必要がなくなる。
  def current_user
    Current.user
  end

  # 現在ログインしている管理者を取得する。
  #
  # 一般ユーザーと管理者で同じ Session モデルを使いつつ、
  # user / admin のどちらに紐づいているかでログイン種別を判断している。
  def current_admin
    Current.admin
  end

  # =========================
  # 認証必須チェック
  # =========================

  # ログイン済みかどうかを確認する。
  #
  # Current.session が存在すればログイン済みなのでそのまま処理を続ける。
  # 存在しなければ request_authentication を呼び出してログイン画面へ誘導する。
  #
  # Rubyでは || を使うことで、
  # 左側が false または nil の場合だけ右側を実行できる。
  def require_authentication
    Current.session || request_authentication
  end

  # =========================
  # セッション復元処理
  # =========================

  # Cookie に保存された session_id から Session レコードを復元する。
  #
  # 復元した Session を Current.session にセットすることで、
  # そのリクエスト中はどこからでも現在のログイン情報を参照できる。
  #
  # Current はリクエスト単位で情報を保持する仕組みなので、
  # current_user を毎回DB検索する必要を減らせる。
  def resume_session
    Current.session = find_session_by_cookie
    Current.session
  end

  # Cookie に保存されている session_id を取得し、
  # DB上の Session レコードを検索する。
  #
  # cookies.signed を使っているため、
  # Cookieの値はRailsによって署名される。
  #
  # 署名付きCookieにすることで、ユーザーが勝手に session_id を改ざんしても
  # Rails側で不正なCookieとして検知できる。
  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  # =========================
  # 未認証時の処理
  # =========================

  # 未ログインユーザーがログイン必須ページにアクセスした場合の処理。
  #
  # まず、アクセスしようとしていたURLを session に保存する。
  # これにより、ログイン後に元のページへ戻すことができる。
  #
  # 例：
  # 未ログインで /posts/1 にアクセス
  # → ログイン画面へ移動
  # → ログイン成功後に /posts/1 へ戻る
  def request_authentication
    session[:return_to_after_authenticating] = request.url

    # 管理者画面へのアクセスであれば、管理者ログイン画面へリダイレクトする。
    #
    # /admin から始まるURLかどうかで、
    # 一般ユーザー用ログイン画面と管理者用ログイン画面を分岐している。
    if request.path.start_with?("/admin")
      redirect_to admin_login_path
    else
      redirect_to new_session_path
    end
  end

  # =========================
  # ログイン後のリダイレクト先
  # =========================

  # ログイン成功後に遷移するURLを決める。
  #
  # session[:return_to_after_authenticating] があれば、
  # 未ログイン時にアクセスしようとしていたURLへ戻す。
  #
  # なければ root_url、つまりトップページへ遷移する。
  #
  # delete を使うことで、一度使った戻り先URLをセッションから削除している。
  # これにより、次回ログイン時に古いURLへ飛ばされることを防げる。
  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end

  # =========================
  # 一般ユーザーのログイン処理
  # =========================

  # 一般ユーザーのログイン成功時に呼び出す処理。
  #
  # Session レコードをDBに作成し、
  # その Session ID を Cookie に保存することでログイン状態を維持する。
  def start_new_session_for(user)
    # セッション固定攻撃対策。
    #
    # セッション固定攻撃とは、
    # 攻撃者が用意したセッションIDをユーザーに使わせ、
    # ログイン後にそのセッションを乗っ取る攻撃。
    #
    # reset_session をログイン成功時に実行することで、
    # ログイン前の古いセッション情報を破棄し、
    # 新しいセッションIDを発行できる。
    reset_session

    # user.sessions.create! により、
    # ログインした一般ユーザーに紐づく Session レコードを作成する。
    #
    # user_agent:
    #   利用しているブラウザや端末情報を保存する。
    #
    # ip_address:
    #   ログイン時のIPアドレスを保存する。
    #
    # これらは、ログイン履歴の確認や不審なログインの調査に役立つ。
    user.sessions.create!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    ).tap do |session_record|
      # 作成した Session レコードを Current.session に保存する。
      #
      # これにより、ログイン直後の同じリクエスト内でも
      # current_user を使えるようになる。
      Current.session = session_record

      # 作成した Session レコードのIDをCookieに保存する。
      #
      # 次回以降のリクエストでは、
      # この Cookie の session_id を使って Session レコードを復元する。
      cookies.signed[:session_id] = {
        value: session_record.id,

        # Cookieの有効期限。
        #
        # ここでは2週間ログイン状態を維持する設定。
        # 期限を過ぎるとCookieが無効になり、再ログインが必要になる。
        expires: 2.weeks.from_now,

        # secure: true の場合、HTTPS通信時のみCookieを送信する。
        #
        # 本番環境ではHTTPSを使う想定なので true。
        # 開発環境では http://localhost を使うことが多いため false にしている。
        secure: Rails.env.production?,

        # httponly: true にすると、
        # JavaScriptからCookieを読み取れなくなる。
        #
        # XSS攻撃でCookieを盗まれるリスクを軽減できる。
        httponly: true,

        # same_site: :lax は、
        # 外部サイトからのリクエスト時にCookie送信を制限する設定。
        #
        # CSRF攻撃への対策として有効。
        # :lax は通常の画面遷移ではCookieを送信しつつ、
        # 危険な外部リクエストでは制限するバランスのよい設定。
        same_site: :lax
      }
    end
  end

  # =========================
  # 管理者のログイン処理
  # =========================

  # 管理者ログイン成功時に呼び出す処理。
  #
  # 一般ユーザーと同じ Session モデルを使いつつ、
  # admin に紐づく Session レコードとして作成する。
  #
  # Session モデル側で
  # belongs_to :user, optional: true
  # belongs_to :admin, optional: true
  # のようにしておくことで、
  # 一般ユーザー用セッションと管理者用セッションを共通管理できる。
  def start_new_session_for_admin(admin)
    # 管理者ログイン時も、一般ユーザーと同様に
    # セッション固定攻撃対策として reset_session を実行する。
    reset_session

    # 管理者に紐づく Session レコードを作成する。
    #
    # 一般ユーザーの場合は user.sessions.create! を使っていたが、
    # 管理者の場合は Session.create!(admin: admin) として
    # admin を直接紐づけている。
    Session.create!(
      admin: admin,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    ).tap do |session_record|
      # 作成した管理者セッションを Current.session に保存する。
      #
      # これにより、ログイン直後から current_admin を参照できる。
      Current.session = session_record

      # 管理者用セッションIDも、一般ユーザーと同じく署名付きCookieに保存する。
      #
      # 管理者ログインは特に権限が強いため、
      # secure / httponly / same_site の設定が重要になる。
      cookies.signed[:session_id] = {
        value: session_record.id,
        expires: 2.weeks.from_now,
        secure: Rails.env.production?,
        httponly: true,
        same_site: :lax
      }
    end
  end

  # =========================
  # ログアウト処理
  # =========================

  # ログアウト時に呼び出す処理。
  #
  # DB上の Session レコード、Current.session、Cookie、Railsセッションを削除し、
  # ログイン状態を完全に破棄する。
  def terminate_session
    # 現在の Session レコードが存在すればDBから削除する。
    #
    # これにより、たとえCookieに古い session_id が残っていても、
    # DB上に対応するセッションが存在しないためログイン状態は復元されない。
    Current.session&.destroy

    # リクエスト中に保持している Current.session も nil にする。
    #
    # これにより、ログアウト後の同じリクエスト内で
    # 誤って current_user / current_admin が残ることを防ぐ。
    Current.session = nil

    # ブラウザ側に保存されている session_id Cookie を削除する。
    #
    # これにより、次回リクエスト時に古い session_id が送信されなくなる。
    cookies.delete(:session_id)

    # Rails標準の session も破棄する。
    #
    # session[:return_to_after_authenticating] など、
    # Railsセッションに保存していた情報もまとめて削除できる。
    reset_session
  end
end
