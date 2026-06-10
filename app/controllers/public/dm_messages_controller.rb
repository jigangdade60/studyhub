class Public::DmMessagesController < ApplicationController
  # =========================
  # before_action
  # =========================

  # メッセージ送信処理の前に、
  # URLに含まれる dm_room_id から対象のDMルームを取得する
  #
  # 例：
  # /dm_rooms/1/dm_messages のようなURLの場合、
  # params[:dm_room_id] には 1 が入る
  before_action :set_dm_room

  # DMルームの参加者だけがメッセージを送信できるようにする
  #
  # URLを直接入力して他人のDMルームにアクセスし、
  # メッセージを送信されることを防ぐための権限チェック
  before_action :ensure_room_member

  # =========================
  # メッセージ送信処理
  # =========================

  def create
    # 対象のDMルームに紐づくメッセージを新しく作成する
    #
    # @dm_room.dm_messages.new とすることで、
    # dm_message の dm_room_id が自動的にセットされる
    #
    # つまり、
    # DmMessage.new(dm_room_id: @dm_room.id, ...)
    # と書くよりも、関連を使って安全に作成できる
    @dm_message = @dm_room.dm_messages.new(dm_message_params)

    # メッセージの送信者をログイン中ユーザーに固定する
    #
    # user_id をフォームから受け取ると、
    # 悪意あるユーザーが別の user_id を送る可能性があるため、
    # current_user を使ってサーバー側で必ず送信者を決める
    @dm_message.user = current_user

    if @dm_message.save
      # 保存に成功した場合は、DMルームの詳細画面へリダイレクトする
      #
      # redirect_to は別のリクエストとして画面を表示し直す処理
      # 二重投稿防止にもつながる
      redirect_to dm_room_path(@dm_room), notice: t("flash.notice.message_sent")
    else
      # 保存に失敗した場合は、DMルーム詳細画面を再表示する
      #
      # 例：
      # ・メッセージ本文が空
      # ・文字数制限を超えている
      #
      # render で show 画面を表示するためには、
      # show 画面で使っている @other_user や @dm_messages も必要になる
      # そのため、set_view_resources で再取得している
      set_view_resources

      # バリデーションエラーとして画面を再表示する
      #
      # status: :unprocessable_entity は HTTP 422 を返す
      # 「リクエスト内容は受け取れたが、入力内容に問題があり保存できない」
      # という意味
      render "public/dm_rooms/show", status: :unprocessable_entity
    end
  end

  private

  # =========================
  # DMルーム取得
  # =========================

  def set_dm_room
    # ネストされたルーティングの dm_room_id から、
    # メッセージを送信する対象のDMルームを取得する
    #
    # routes.rb で dm_rooms の中に dm_messages をネストしているため、
    # params[:dm_room_id] で親のDMルームIDを取得できる
    @dm_room = DmRoom.find(params[:dm_room_id])
  end

  # =========================
  # 権限チェック
  # =========================

  def ensure_room_member
    # 現在ログインしているユーザーが、
    # このDMルームの参加者であれば処理を続行する
    #
    # includes_user? は DmRoom モデル側で定義しているメソッドで、
    # current_user が user1 または user2 に含まれているかを判定する
    return if @dm_room.includes_user?(current_user)

    # DMルームの参加者ではない場合は、
    # トップページへリダイレクトしてアクセスを拒否する
    #
    # これにより、URLを直接入力して他人のDMに入ることを防ぐ
    redirect_to root_path, alert: t("flash.alert.cannot_enter_dm")
  end

  # =========================
  # 画面再表示用データ取得
  # =========================

  def set_view_resources
    # DM相手のユーザーを取得する
    #
    # show画面では「相手の名前」などを表示するため、
    # メッセージ保存失敗時にも @other_user が必要になる
    @other_user = @dm_room.other_user(current_user)

    # DMルーム内のメッセージ一覧を取得する
    #
    # includes(:user) を使うことで、
    # メッセージごとに送信者ユーザーを取得する際のN+1問題を防いでいる
    #
    # order(:created_at) により、
    # 古いメッセージから順番に表示する
    @dm_messages = @dm_room.dm_messages.includes(:user).order(:created_at)
  end

  # =========================
  # Strong Parameters
  # =========================

  def dm_message_params
    # フォームから送られてきた値のうち、
    # メッセージ本文 content のみを許可する
    #
    # user_id や dm_room_id はフォームから受け取らず、
    # サーバー側で current_user や @dm_room から設定する
    #
    # これにより、送信者や送信先DMルームを不正に書き換えられることを防ぐ
    params.require(:dm_message).permit(:content)
  end
end