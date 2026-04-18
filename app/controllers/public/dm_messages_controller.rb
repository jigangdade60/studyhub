class Public::DmMessagesController < ApplicationController
  before_action :set_dm_room
  before_action :ensure_room_member

  def create
    @dm_message = @dm_room.dm_messages.new(dm_message_params)
    @dm_message.user = Current.user

    if @dm_message.save
      redirect_to dm_room_path(@dm_room), notice: "メッセージを送信しました"
    else
      @other_user = @dm_room.other_user(Current.user)
      @dm_messages = @dm_room.dm_messages.includes(:user).order(:created_at)
      render "public/dm_rooms/show", status: :unprocessable_entity
    end
  end

  private

  def set_dm_room
    @dm_room = DmRoom.find(params[:dm_room_id])
  end

  def ensure_room_member
    return if @dm_room.includes_user?(Current.user)

    redirect_to root_path, alert: "このDMルームには入れません"
  end

  def dm_message_params
    params.require(:dm_message).permit(:content)
  end
end