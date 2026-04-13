class GroupJoinRequest < ApplicationRecord
  belongs_to :group
  belongs_to :user

  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2
  }

  validates :user_id, uniqueness: { scope: :group_id }
  validate :user_is_not_already_member
  validate :group_is_not_full, on: :create

  private

  def user_is_not_already_member
    return unless group && user

    if group.members.exists?(user.id)
      errors.add(:base, "すでに参加しています。")
    end
  end

  def group_is_not_full
    return unless group

    if group.full?
      errors.add(:base, "定員に達しているため申請できません。")
    end
  end
end