class DmRoom < ApplicationRecord
  # DMルームは2人のユーザーで構成する
  belongs_to :user1, class_name: "User"
  belongs_to :user2, class_name: "User"

  # ルーム内のメッセージ
  has_many :dm_messages, dependent: :destroy

  # 同一ユーザー同士のDMを禁止する
  validate :different_users

  # user1_id < user2_id の順に統一して、同じ組み合わせの重複ルームを防ぐ
  validate :ordered_users

  # 2人のユーザー間のDMルームを取得し、なければ新規作成する
  # ユーザーIDを昇順にそろえることで、同じ2人で常に同一ルームを参照できる
  def self.find_or_create_between(user_a, user_b)
    smaller_id, larger_id = [user_a.id, user_b.id].sort
    find_or_create_by!(user1_id: smaller_id, user2_id: larger_id)
  end

  # 指定ユーザーがこのDMルームの参加者かどうか判定する
  def includes_user?(user)
    user1_id == user.id || user2_id == user.id
  end

  # ルーム内の相手ユーザーを取得する
  def other_user(current_user)
    user1_id == current_user.id ? user2 : user1
  end

  private

  # 自分自身とのDMルームは作成できないようにする
  def different_users
    errors.add(:base, "同じユーザー同士ではDMできません") if user1_id == user2_id
  end

  # user1_id を常に user2_id より小さく保ち、
  # 同じ2人で別順序の重複レコードができないようにする
  def ordered_users
    return if user1_id.blank? || user2_id.blank?
    return if user1_id < user2_id

    errors.add(:base, "user1_idはuser2_idより小さくしてください")
  end
end