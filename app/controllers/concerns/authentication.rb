module Authentication
  extend ActiveSupport::Concern

  included do
    # 基本は全画面でログイン必須にし、
    # ログイン不要な画面だけ allow_unauthenticated_access で除外する
    before_action :require_authentication

    # view から現在のログイン状態やログイン中ユーザーを参照できるようにする
    helper_method :authenticated?, :current_user, :current_admin, :admin_authenticated?
  end

  class_methods do
    # 未ログインでも閲覧できるアクションを個別に許可する
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  # 一般ユーザーでログインしているかを判定する
  def authenticated?
    current_user.present?
  end

  # 管理者でログインしているかを判定する
  def admin_authenticated?
    current_admin.present?
  end

  # 現在のセッションから一般ユーザーを取得する
  def current_user
    resume_session&.user
  end

  # 現在のセッションから管理者を取得する
  def current_admin
    resume_session&.admin
  end

  # 毎リクエスト時にセッションを復元し、
  # セッションがなければログイン画面へ誘導する
  def require_authentication
    resume_session || request_authentication
  end

  # Cookieに保存された session_id からセッション情報を復元し、
  # Current に保持してリクエスト中どこからでも参照できるようにする
  def resume_session
    Current.session = find_session_by_cookie
    Current.session
  end

  # 署名付きCookieから session_id を取得し、対応する Session レコードを探す
  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  # 未認証時は、アクセスしようとしたURLを保存してログイン画面へリダイレクトする
  # /admin 配下は管理者ログイン画面、それ以外は一般ユーザーログイン画面へ分岐する
  def request_authentication
    session[:return_to_after_authenticating] = request.url

    if request.path.start_with?("/admin")
      redirect_to admin_login_path
    else
      redirect_to new_session_path
    end
  end

  # ログイン後は元のURLへ戻し、保存がなければトップへ遷移する
  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end

  # 一般ユーザーのログイン成功時に Session レコードを作成し、
  # そのIDを署名付きCookieに保存してログイン状態を維持する
  def start_new_session_for(user)
    user.sessions.create!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    ).tap do |session_record|
      Current.session = session_record
      cookies.signed.permanent[:session_id] = {
        value: session_record.id,
        httponly: true,
        same_site: :lax
      }
    end
  end

  # 管理者ログイン用のセッション作成処理
  # 一般ユーザーと同じ Session モデルを使い、admin を紐付けて管理する
  def start_new_session_for_admin(admin)
    Session.create!(
      admin: admin,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    ).tap do |session_record|
      Current.session = session_record
      cookies.signed.permanent[:session_id] = {
        value: session_record.id,
        httponly: true,
        same_site: :lax
      }
    end
  end

  # ログアウト時はDB上のセッションとCookieを削除し、セッション情報を完全に破棄する
  def terminate_session
    Current.session&.destroy
    Current.session = nil
    cookies.delete(:session_id)
    reset_session
  end
end