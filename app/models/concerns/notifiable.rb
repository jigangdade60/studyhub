module Notifiable
  extend ActiveSupport::Concern

  private

  def create_notification!(recipient:, actor:, action:, notifiable:)
    return if recipient.blank? || actor.blank?
    return if recipient == actor

    Notification.create!(
      recipient: recipient,
      actor: actor,
      action: action,
      notifiable: notifiable
    )
  end
end