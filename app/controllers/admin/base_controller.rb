# 管理者画面共通の親コントローラー
#
# Admin配下のコントローラーで共通して使う認証処理をまとめるためのクラス。
# 例：
# Admin::UsersController < Admin::BaseController
# Admin::CommentsController < Admin::BaseController
#
# このように継承させることで、管理画面全体に
# 「管理者ログインが必要」というルールをまとめて適用できる。
class Admin::BaseController < ApplicationController
  # ApplicationController では、基本的に一般ユーザー向けの認証処理
  # require_authentication が before_action として設定されている。
  #
  # しかし管理画面では、一般ユーザーではなく「管理者」として
  # ログインしているかを確認したい。
  #
  # そのため、一般ユーザー用の認証チェックはここでスキップする。
  skip_before_action :require_authentication

  # 管理画面にアクセスする前に、
  # 管理者としてログインしているかを確認する。
  #
  # Admin::BaseController を継承した管理者用コントローラーでは、
  # 各アクション実行前にこの認証チェックが行われる。
  before_action :require_admin_authentication

  private

  # 管理者としてログインしているかを確認するメソッド。
  #
  # private にしている理由：
  # このメソッドはURLから直接呼び出すアクションではなく、
  # before_action の内部処理として使うため。
  def require_admin_authentication
    # Cookieに保存されているセッションIDをもとに、
    # 現在のセッション情報を復元する。
    #
    # これにより current_user や current_admin を
    # 参照できる状態にする。
    resume_session

    # current_admin が存在する場合は、
    # 管理者としてログイン済みと判断する。
    #
    # return によってここで処理を終了し、
    # 本来アクセスしようとしていた管理画面のアクションへ進む。
    return if current_admin.present?

    # current_admin が存在しない場合は、
    # 管理者としてログインしていない状態。
    #
    # そのため、管理者ログイン画面へリダイレクトする。
    #
    # alert には i18n の翻訳キーを使い、
    # 「管理者としてログインしてください」のような
    # メッセージを表示する。
    redirect_to admin_login_path, alert: t("flash.alert.admin_login_required")
  end
end