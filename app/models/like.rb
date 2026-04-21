class Like < ApplicationRecord
  include Notifiable

  # いいねはユーザーと投稿をつなぐ中間テーブル（多対多関係）
  belongs_to :user
  belongs_to :post

  # いいねに対する通知をポリモーフィック関連で管理する
  has_many :notifications, as: :notifiable, dependent: :destroy

  # 同一ユーザーが同じ投稿に複数回いいねできないように制御する
  validates :user_id, uniqueness: { scope: :post_id }

  # いいね作成時に投稿者へ通知を送る
  after_create_commit :notify_post_owner

  private

  # 投稿者に「いいねされた」通知を作成する
  def notify_post_owner
    create_notification!(
      recipient: post.user,
      actor: user,
      action: :liked,
      notifiable: self
    )
  end
end