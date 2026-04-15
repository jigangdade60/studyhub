class DmMessage < ApplicationRecord
  belongs_to :dm_room
  belongs_to :user

  validates :content, presence: true, length: { maximum: 500 }
  validate :sender_must_belong_to_room

  private

  def sender_must_belong_to_room
    return if dm_room.blank? || user.blank?
    return if dm_room.includes_user?(user)

    errors.add(:user, "はこのDMルームの参加者ではありません")
  end
end