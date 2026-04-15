class Public::DmRoomsController < ApplicationController
  before_action :set_dm_room, only: :show
  before_action :ensure_room_member, only: :show

  def create
    other_user = User.find(params[:user_id])

    if Current.user == other_user
      redirect_to user_path(other_user), alert: "自分自身とはDMできません"
      return
    end

    unless Current.user.mutual_follow_with?(other_user)
      redirect_to user_path(other_user), alert: "相互フォローのユーザーのみDMできます"
      return
    end

    @dm_room = DmRoom.find_or_create_between(Current.user, other_user)
    redirect_to dm_room_path(@dm_room)
  end

  def show
    @other_user = @dm_room.other_user(Current.user)
    @dm_messages = @dm_room.dm_messages.includes(:user).order(:created_at)
    @dm_message = @dm_room.dm_messages.new
  end

  private

  def set_dm_room
    @dm_room = DmRoom.find(params[:id])
  end

  def ensure_room_member
    return if @dm_room.includes_user?(Current.user)

    redirect_to root_path, alert: "このDMルームには入れません"
  end
end