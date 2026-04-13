class Public::GroupMessagesController < ApplicationController
  before_action :require_authentication
  before_action :set_group
  before_action :ensure_member!

  def create
    @group_message = @group.group_messages.new(group_message_params)
    @group_message.user = Current.user

    if @group_message.save
      redirect_to group_path(@group), notice: "メッセージを送信しました。"
    else
      redirect_to group_path(@group), alert: @group_message.errors.full_messages.join(", ")
    end
  end

  private

  def set_group
    @group = Group.find(params[:group_id])
  end

  def ensure_member!
    return if @group.joined_by?(Current.user)

    redirect_to group_path(@group), alert: "チャットは参加者のみ利用できます。"
  end

  def group_message_params
    params.require(:group_message).permit(:content)
  end
end