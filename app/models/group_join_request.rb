class GroupJoinRequest < ApplicationRecord
  # 参加申請はグループとユーザーに紐づく
  belongs_to :group
  belongs_to :user

  # =========================
  # ステータス管理
  # =========================

  # 申請状態を管理（申請中 / 承認 / 拒否）
  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2
  }

  # =========================
  # バリデーション
  # =========================

  # 同一ユーザーが同じグループに複数回申請できないようにする
  validates :user_id, uniqueness: { scope: :group_id }

  # すでにメンバーの場合は申請できない
  validate :user_is_not_already_member

  # グループが満員の場合は申請できない（作成時のみチェック）
  validate :group_is_not_full, on: :create

  private

  # すでに参加済みかどうかをチェックする
  def user_is_not_already_member
    return unless group && user

    if group.members.exists?(user.id)
      errors.add(:base, "すでに参加しています。")
    end
  end

  # グループの定員オーバーを防ぐ
  def group_is_not_full
    return unless group

    if group.full?
      errors.add(:base, "定員に達しているため申請できません。")
    end
  end
end