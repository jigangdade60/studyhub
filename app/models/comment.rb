class Comment < ApplicationRecord
  # コメントは投稿したユーザーと対象の投稿に紐づく
  belongs_to :user
  belongs_to :post

  # コメントに対する通知をポリモーフィック関連で管理する
  has_many :notifications, as: :notifiable, dependent: :destroy

  # コメント本文は必須かつ300文字以内に制限する
  validates :body, presence: true, length: { maximum: 300 }

  # コメント作成後、投稿者へ通知を送る
  after_create_commit :notify_post_owner

  private

  # 自分自身の投稿へのコメントでなければ、投稿者へ通知を作成する
  def notify_post_owner
    return if post.user == user

    Notification.create!(
      recipient: post.user,
      actor: user,
      action: :commented,
      notifiable: self
    )
  end
end