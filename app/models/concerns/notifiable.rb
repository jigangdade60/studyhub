module Notifiable
  extend ActiveSupport::Concern

  private

  def create_notification!(recipient:, actor:, action:, notifiable:)
    return if recipient.blank? || actor.blank?
    return if recipient == actor
    # 非同期で通知を作成する
    NotificationJob.perform_later(
      recipient.id,
      actor.id,
      action.to_s,
      notifiable.class.name,
      notifiable.id
    )
  end
end
