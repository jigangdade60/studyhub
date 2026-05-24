class NotificationJob < ApplicationJob
  queue_as :default

  def perform(recipient_id, actor_id, action, notifiable_type, notifiable_id)
    recipient = User.find_by(id: recipient_id)
    actor = User.find_by(id: actor_id)
    return if recipient.blank? || actor.blank?
    return if recipient == actor

    Notification.create!(
      recipient: recipient,
      actor: actor,
      action: action.to_sym,
      notifiable_type: notifiable_type,
      notifiable_id: notifiable_id
    )
  end
end
