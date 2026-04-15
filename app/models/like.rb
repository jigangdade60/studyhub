class Like < ApplicationRecord
  include Notifiable

  belongs_to :user
  belongs_to :post

  has_many :notifications, as: :notifiable, dependent: :destroy

  validates :user_id, uniqueness: { scope: :post_id }

  after_create_commit :notify_post_owner

  private

  def notify_post_owner
    create_notification!(
      recipient: post.user,
      actor: user,
      action: :liked,
      notifiable: self
    )
  end
end