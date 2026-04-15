class DmRoom < ApplicationRecord
  belongs_to :user1, class_name: "User"
  belongs_to :user2, class_name: "User"

  has_many :dm_messages, dependent: :destroy

  validate :different_users
  validate :ordered_users

  def self.find_or_create_between(user_a, user_b)
    smaller_id, larger_id = [user_a.id, user_b.id].sort
    find_or_create_by!(user1_id: smaller_id, user2_id: larger_id)
  end

  def includes_user?(user)
    user1_id == user.id || user2_id == user.id
  end

  def other_user(current_user)
    user1_id == current_user.id ? user2 : user1
  end

  private

  def different_users
    errors.add(:base, "同じユーザー同士ではDMできません") if user1_id == user2_id
  end

  def ordered_users
    return if user1_id.blank? || user2_id.blank?
    return if user1_id < user2_id

    errors.add(:base, "user1_idはuser2_idより小さくしてください")
  end
end