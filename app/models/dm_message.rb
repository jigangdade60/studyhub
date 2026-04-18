class DmMessage < ApplicationRecord
  include Notifiable

  belongs_to :dm_room
  belongs_to :user

  has_many :notifications, as: :notifiable, dependent: :destroy

  validates :content, presence: true, length: { maximum: 500 }
  validate :sender_must_belong_to_room

  after_create_commit :notify_recipient

  private

  def sender_must_belong_to_room
    return if dm_room.blank? || user.blank?
    return if dm_room.includes_user?(user)

    errors.add(:user, "はこのDMルームの参加者ではありません")
  end

  def notify_recipient
    recipient =
      if dm_room.user1 == user
        dm_room.user2
      else
        dm_room.user1
      end

    create_notification!(
      recipient: recipient,
      actor: user,
      action: :message,
      notifiable: self
    )
  end
end