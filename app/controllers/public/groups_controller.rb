class Public::GroupsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  before_action :set_group, only: %i[show requests]
  before_action :require_authentication, only: %i[new create requests]
  before_action :ensure_owner!, only: %i[requests]

  def index
    @keyword = params[:keyword]
    @groups = Group.includes(:owner, :members)
                   .search_by_keyword(@keyword)
                   .order(created_at: :desc)
                    .page(params[:page]).per(10)
  end

  def show
    @group_messages = @group.group_messages.includes(:user).order(created_at: :asc)
    @group_message = GroupMessage.new
  end

  def new
    @group = Group.new
  end

  def create
    @group = Group.new(group_params)
    @group.owner = current_user

    ActiveRecord::Base.transaction do
      @group.save!
      GroupMembership.create!(group: @group, user: current_user)
    end

    redirect_to group_path(@group), notice: "もくもく会を作成しました。"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def requests
    @requests = @group.group_join_requests
                      .pending
                      .includes(:user)
                      .order(created_at: :asc)
  end

  private

  def set_group
    @group = Group.find(params[:id])
  end

  def ensure_owner!
    return if @group.owned_by?(current_user)

    redirect_to groups_path, alert: "権限がありません。"
  end

  def group_params
    params.require(:group).permit(:name, :description, :rule, :study_theme, :max_members)
  end
end