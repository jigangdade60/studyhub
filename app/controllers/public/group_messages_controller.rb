class Public::GroupMessagesController < ApplicationController
  # グループチャットはログインユーザーのみ利用可能
  before_action :require_authentication

  # メッセージ投稿時は対象グループを取得する
  before_action :set_group

  # グループ参加者のみチャットを利用できるように制御する
  before_action :ensure_member!

  def create
    # グループに紐づくメッセージを作成する
    @group_message = @group.group_messages.new(group_message_params)

    # 投稿者はログイン中ユーザーに固定する
    @group_message.user = Current.user

    if @group_message.save
      redirect_to group_path(@group), notice: "メッセージを送信しました。"
    else
      redirect_to group_path(@group), alert: @group_message.errors.full_messages.join(", ")
    end
  end

  private

  def set_group
    # URLパラメータから対象グループを取得する
    @group = Group.find(params[:group_id])
  end

  def ensure_member!
    # グループ参加者以外はチャットを利用できないようにする
    return if @group.joined_by?(Current.user)

    redirect_to group_path(@group), alert: "チャットは参加者のみ利用できます。"
  end

  def group_message_params
    # メッセージ本文のみ受け取る
    params.require(:group_message).permit(:content)
  end
end