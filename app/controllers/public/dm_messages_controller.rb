class Public::DmMessagesController < ApplicationController
  # メッセージ送信時は対象のDMルームを取得する
  before_action :set_dm_room

  # DMルーム参加者のみメッセージ送信できるようにする
  before_action :ensure_room_member

  def create
    # DMルームに紐づくメッセージを作成する
    @dm_message = @dm_room.dm_messages.new(dm_message_params)

    # 送信者はログイン中ユーザーに固定する
    @dm_message.user = Current.user

    if @dm_message.save
      redirect_to dm_room_path(@dm_room), notice: "メッセージを送信しました"
    else
      # エラー時はDM画面を再表示できるように必要なデータを再取得する
      @other_user = @dm_room.other_user(Current.user)
      @dm_messages = @dm_room.dm_messages.includes(:user).order(:created_at)
      render "public/dm_rooms/show", status: :unprocessable_entity
    end
  end

  private

  def set_dm_room
    # URLパラメータから対象DMルームを取得する
    @dm_room = DmRoom.find(params[:dm_room_id])
  end

  def ensure_room_member
    # DMルーム参加者以外はメッセージ送信できないようにする
    return if @dm_room.includes_user?(Current.user)

    redirect_to root_path, alert: "このDMルームには入れません"
  end

  def dm_message_params
    # メッセージ本文のみ受け取る
    params.require(:dm_message).permit(:content)
  end
end