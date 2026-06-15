# Currentクラスは、リクエスト中の「現在の状態」を一時的に保持するためのクラス
# Railsの ActiveSupport::CurrentAttributes を継承している
#
# 例えば、
# 「現在ログインしているユーザー」
# 「現在のセッション情報」
# 「現在ログインしている管理者」
# などを、アプリ全体から参照しやすくする目的で使う
#
# Railsでは、1回のリクエストごとに Current の値がリセットされるため、
# 別のユーザーの情報が混ざらないように管理できる
class Current < ActiveSupport::CurrentAttributes
  # Current.session という形で、
  # 現在のリクエストに紐づくセッション情報を保持できるようにしている
  #
  # ここでいう session は、Rails標準の session ハッシュではなく、
  # 自分で作成した Sessionモデルのインスタンスを想定している
  #
  # 例：
  # Current.session = Session.find_by(id: cookies.signed[:session_id])
  #
  # こうすることで、ログイン中のユーザー情報を
  # Current.session 経由で取得できる
  attribute :session

  # delegate は、あるオブジェクトに処理を委譲するためのRailsの機能
  #
  # ここでは、
  # Current.user
  # Current.admin
  # と書いたときに、実際には
  # Current.session.user
  # Current.session.admin
  # を呼び出すようにしている
  #
  # つまり、sessionを経由せずに、
  # Current.user のようにシンプルに現在のユーザーを取得できる
  delegate :user, :admin, to: :session, allow_nil: true

  # allow_nil: true を付けている理由
  #
  # ログインしていない状態では、Current.session が nil になる可能性がある
  #
  # もし allow_nil: true がない場合、
  # Current.session が nil の状態で Current.user を呼ぶと、
  # nil.user を呼ぼうとしてエラーになる
  #
  # allow_nil: true を付けることで、
  # Current.session が nil の場合でもエラーにせず、
  # Current.user や Current.admin は nil を返すようになる
  #
  # そのため、未ログインユーザーがアクセスするページでも安全に使える
end
