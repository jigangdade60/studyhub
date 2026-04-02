class User < ApplicationRecord
  has_secure_password

  # セッション管理
  has_many :sessions, dependent: :destroy

  # 投稿との関連（追加）
  has_many :posts, dependent: :destroy

  # メール正規化
  normalizes :email_address, with: ->(e) { e.strip.downcase }
end