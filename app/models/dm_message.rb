class DmMessage < ApplicationRecord
  include Notifiable

  # メッセージはDMルームと送信ユーザーに紐づく
  belongs_to :dm_room
  belongs_to :user

  # 通知をポリモーフィック関連で管理する
  has_many :notifications, as: :notifiable, dependent: :destroy

  # メッセージ本文は必須かつ500文字以内に制限する
  validates :content, presence: true, length: { maximum: 500 }

  # 送信者がDMルームの参加者であることを保証する
  validate :sender_must_belong_to_room

  # メッセージ送信時に相手ユーザーへ通知を送る
  after_create_commit :notify_recipient

  private

  # DMルームに属していないユーザーの送信を防ぐ
  def sender_must_belong_to_room
    return if dm_room.blank? || user.blank?
    return if dm_room.includes_user?(user)

    errors.add(:user, "はこのDMルームの参加者ではありません")
  end

  # 相手ユーザーを特定し、通知を作成する
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