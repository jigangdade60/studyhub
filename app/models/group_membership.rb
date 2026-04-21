class GroupMembership < ApplicationRecord
  # グループとユーザーをつなぐ中間テーブル（多対多関係）
  belongs_to :group
  belongs_to :user

  # 同一ユーザーが同じグループに複数回参加できないようにする
  validates :user_id, uniqueness: { scope: :group_id }
end