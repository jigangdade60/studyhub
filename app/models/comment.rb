class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :post

  has_many :notifications, as: :notifiable, dependent: :destroy

  validates :body, presence: true, length: { maximum: 300 }

  after_create_commit :notify_post_owner

  private

  def notify_post_owner
    create_notification!(
      recipient: post.user,
      actor: user,
      action: :commented,
      notifiable: self
    )
  end
end