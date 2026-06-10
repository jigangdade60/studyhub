# 管理者ユーザーを表すモデル
# admin_users ではなく Admin モデルとして、
# 管理者ログインや管理画面へのアクセスに使う
class Admin < ApplicationRecord
  # パスワードを安全に扱うための機能
  #
  # has_secure_password を使うことで、
  # password_digest カラムにパスワードをハッシュ化して保存できる
  #
  # 生のパスワードをDBに保存せず、
  # ログイン時には authenticate メソッドで認証できるようになる
  #
  # 例：
  # admin.authenticate("入力されたパスワード")
  #
  # これにより、パスワード認証をRailsの仕組みで安全に実装できる
  has_secure_password

  # 管理者に紐づくログインセッション
  #
  # 1人の管理者がログインすると、
  # sessions テーブルにログイン情報が作成される
  #
  # has_many なので、
  # 1人の管理者が複数のセッションを持てる設計になっている
  # 例：PCとスマホなど、複数端末でログインするケース
  #
  # dependent: :destroy を指定しているため、
  # 管理者アカウントが削除された場合、
  # その管理者に紐づくセッションも一緒に削除される
  #
  # これにより、存在しない管理者のセッションだけがDBに残ることを防げる
  has_many :sessions, dependent: :destroy

  # メールアドレスのバリデーション
  #
  # presence: true は、
  # email_address が空の状態で保存されることを防ぐ
  #
  # uniqueness: true は、
  # 同じメールアドレスの管理者が複数作成されることを防ぐ
  #
  # ログイン時にメールアドレスで管理者を特定するため、
  # メールアドレスが空だったり重複していたりすると、
  # 認証処理で問題が起きる可能性がある
  #
  # そのため、管理者ごとに一意なメールアドレスを必須にしている
  validates :email_address, presence: true, uniqueness: true
end