class Public::DmRoomsController < ApplicationController
  # DMルーム表示時は対象ルームを取得する
  before_action :set_dm_room, only: :show

  # DMルームの参加者のみ閲覧できるようにする
  before_action :ensure_room_member, only: :show

  def create
    other_user = User.find(params[:user_id])

    # 自分自身とのDMルーム作成は許可しない
    if Current.user == other_user
      redirect_to user_path(other_user), alert: "自分自身とはDMできません"
      return
    end

    # 相互フォローのユーザー同士だけDMできるように制御する
    unless Current.user.mutual_follow_with?(other_user)
      redirect_to user_path(other_user), alert: "相互フォローのユーザーのみDMできます"
      return
    end

    # 2人の組み合わせに対応するDMルームを取得し、なければ新規作成する
    @dm_room = DmRoom.find_or_create_between(Current.user, other_user)
    redirect_to dm_room_path(@dm_room)
  end

  def show
    # DM相手のユーザー情報と、ルーム内のメッセージ一覧を表示する
    @other_user = @dm_room.other_user(Current.user)
    @dm_messages = @dm_room.dm_messages.includes(:user).order(:created_at)
    @dm_message = @dm_room.dm_messages.new
  end

  private

  def set_dm_room
    # URLパラメータから対象DMルームを取得する
    @dm_room = DmRoom.find(params[:id])
  end

  def ensure_room_member
    # DMルーム参加者以外は閲覧できないようにする
    return if @dm_room.includes_user?(Current.user)

    redirect_to root_path, alert: "このDMルームには入れません"
  end
end