class Public::NotificationsController < ApplicationController
  # 通知機能はログインユーザーのみ利用できるようにする
  before_action :require_authentication

  def index
    # ログイン中ユーザーが受け取った通知を新着順で表示する
    @notifications = Current.user.received_notifications.recent
    @notifications = @notifications.page(params[:page]).per(10)
  end

  def read
    # 自分宛の通知だけ取得し、既読化したうえで通知先画面へ遷移する
    notification = Current.user.received_notifications.find(params[:id])
    notification.mark_as_read!
    redirect_to notification.target_path
  end

  def read_all
    # 未読通知をまとめて既読にする
    Current.user.received_notifications.unread.update_all(read_at: Time.current)
    redirect_to notifications_path, notice: "すべての通知を既読にしました。"
  end
end