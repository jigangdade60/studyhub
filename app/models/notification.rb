class Notification < ApplicationRecord
  # 通知を受け取るユーザー
  belongs_to :recipient, class_name: "User"

  # 通知を発生させたユーザー
  belongs_to :actor, class_name: "User"

  # 通知対象（いいね・コメント・フォロー・DMなど）を
  # ポリモーフィック関連で共通管理する
  belongs_to :notifiable, polymorphic: true

  # 通知の種類を管理する
  enum :action, {
    liked: 0,
    commented: 1,
    posted: 2,
    message: 3,
    followed: 4
  }

  # 新着順表示用
  scope :recent, -> { order(created_at: :desc) }

  # 未読通知のみ取得する
  scope :unread, -> { where(read_at: nil) }

  validates :action, presence: true

  # 既読かどうかを判定する
  def read?
    read_at.present?
  end

  # 未読の場合のみ既読日時を保存する
  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  # 通知種別に応じて表示用メッセージを返す
  def message
    case action
    when "liked"
      "#{actor.name}さんがあなたの投稿にいいねしました"
    when "commented"
      "#{actor.name}さんがあなたの投稿にコメントしました"
    when "posted"
      "#{actor.name}さんが新しく投稿しました"
    when "message"
      "#{actor.name}さんから新しいDMがあります"
    when "followed"
      "#{actor.name}さんがあなたをフォローしました"
    else
      "新しい通知があります"
    end
  end

  # 通知内容に応じて遷移先URLを切り替える
  def target_path
    case notifiable
    when Post
      Rails.application.routes.url_helpers.post_path(notifiable)
    when Comment
      Rails.application.routes.url_helpers.post_path(notifiable.post)
    when Like
      Rails.application.routes.url_helpers.post_path(notifiable.post)
    when DmMessage
      Rails.application.routes.url_helpers.dm_room_path(notifiable.dm_room)
    when Relationship
      Rails.application.routes.url_helpers.user_path(actor)
    else
      Rails.application.routes.url_helpers.notifications_path
    end
  end
end