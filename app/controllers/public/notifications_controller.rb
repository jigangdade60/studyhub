class Public::NotificationsController < ApplicationController
  # =========================
  # 認証制御
  # =========================

  # 通知はログインしているユーザー本人に関係する情報のため、
  # 未ログインユーザーには利用させない
  before_action :require_authentication

  # =========================
  # 通知一覧
  # =========================

  def index
    # ログイン中ユーザーが「受け取った通知」だけを取得する
    #
    # Notificationには、
    # ・recipient：通知を受け取るユーザー
    # ・actor：通知を発生させたユーザー
    # があるため、ここでは recipient が current_user の通知を取得している
    #
    # current_user.received_notifications とすることで、
    # 他人宛の通知が表示されないようにしている
    @notifications = current_user.received_notifications.recent

    # 通知件数が多くなっても一覧画面が重くならないように、
    # kaminariで10件ずつページネーションする
    @notifications = @notifications.page(params[:page]).per(10)
  end

  # =========================
  # 通知を1件既読にして遷移
  # =========================

  def read
    # URLのparams[:id]から通知を取得する
    #
    # Notification.find(params[:id])ではなく、
    # current_user.received_notifications.find(params[:id]) とすることで、
    # ログイン中ユーザー宛の通知だけ取得できる
    #
    # これにより、URLを直接書き換えて他人の通知を既読化することを防ぐ
    notification = current_user.received_notifications.find(params[:id])

    # 通知を既読状態にする
    #
    # mark_as_read! は Notificationモデル側で定義しているメソッドで、
    # read_at に現在時刻を入れることで「既読」と判定できるようにしている
    notification.mark_as_read!

    # 通知の種類に応じた遷移先へリダイレクトする
    #
    # 例：
    # ・いいね通知 → 投稿詳細画面
    # ・コメント通知 → 投稿詳細画面
    # ・フォロー通知 → ユーザー詳細画面
    # ・DM通知 → DMルーム画面
    #
    # 遷移先の判定をControllerではなくNotificationモデル側の
    # target_path に任せることで、Controllerをシンプルにしている
    redirect_to notification.target_path
  end

  # =========================
  # 通知をまとめて既読にする
  # =========================

  def read_all
    # ログイン中ユーザーが受け取った通知のうち、
    # 未読通知だけを対象にする
    #
    # unread は Notificationモデル側で定義しているscopeで、
    # read_at が nil の通知を取得する
    current_user.received_notifications.unread.update_all(read_at: Time.current)

    # 一覧画面に戻し、まとめて既読にしたことをフラッシュメッセージで伝える
    redirect_to notifications_path, notice: t("flash.notice.notifications_read")
  end
end