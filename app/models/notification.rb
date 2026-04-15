class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User"
  belongs_to :notifiable, polymorphic: true

  enum :action, {
    liked: 0,
    commented: 1,
    posted: 2,
    message: 3
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }

  validates :action, presence: true

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

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
    else
      "新しい通知があります"
    end
  end

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
    else
      Rails.application.routes.url_helpers.notifications_path
    end
  end
end