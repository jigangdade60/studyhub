class Public::GroupJoinRequestsController < ApplicationController
  before_action :require_authentication
  before_action :set_group, only: %i[create]
  before_action :set_group_join_request, only: %i[approve reject]
  before_action :ensure_owner!, only: %i[approve reject]

  def create
    @group_join_request = @group.group_join_requests.new(user: current_user)

    if @group_join_request.save
      redirect_to group_path(@group), notice: "参加申請を送りました。"
    else
      redirect_to group_path(@group), alert: @group_join_request.errors.full_messages.join(", ")
    end
  end

  def approve
    if @group_join_request.group.full?
      redirect_to requests_group_path(@group_join_request.group), alert: "定員に達しているため承認できません。"
      return
    end

    ActiveRecord::Base.transaction do
      @group_join_request.approved!
      GroupMembership.find_or_create_by!(
        group: @group_join_request.group,
        user: @group_join_request.user
      )
    end

    redirect_to requests_group_path(@group_join_request.group), notice: "参加申請を承認しました。"
  end

  def reject
    @group_join_request.rejected!
    redirect_to requests_group_path(@group_join_request.group), notice: "参加申請を拒否しました。"
  end

  private

  def set_group
    @group = Group.find(params[:group_id])
  end

  def set_group_join_request
    @group_join_request = GroupJoinRequest.find(params[:id])
  end

  def ensure_owner!
    return if @group_join_request.group.owned_by?(current_user)

    redirect_to groups_path, alert: "権限がありません。"
  end
end