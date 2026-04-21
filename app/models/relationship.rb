class Relationship < ApplicationRecord
  # =========================
  # 自己結合（ユーザー同士のフォロー関係）
  # =========================

  # フォローする側（自分）
  belongs_to :follower, class_name: "User"

  # フォローされる側（相手）
  belongs_to :followed, class_name: "User"

  # =========================
  # バリデーション
  # =========================

  # フォローする側・される側は必須
  validates :follower_id, presence: true
  validates :followed_id, presence: true

  # 同一ユーザーへの重複フォローを防ぐ
  validates :follower_id, uniqueness: { scope: :followed_id }

  # 自分自身をフォローできないようにする
  validate :cannot_follow_self

  private

  # follower と followed が同一の場合はエラーとする
  def cannot_follow_self
    errors.add(:followed_id, "自分自身はフォローできません") if follower_id == followed_id
  end
end