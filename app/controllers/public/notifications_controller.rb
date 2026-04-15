class Public::NotificationsController < ApplicationController
  before_action :require_authentication

  def index
    @notifications = Current.user.received_notifications.recent
  end

  def read
    notification = Current.user.received_notifications.find(params[:id])
    notification.mark_as_read!
    redirect_to notification.target_path
  end

  def read_all
    Current.user.received_notifications.unread.update_all(read_at: Time.current)
    redirect_to notifications_path, notice: "すべての通知を既読にしました。"
  end
end