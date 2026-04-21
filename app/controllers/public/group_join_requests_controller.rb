class Public::GroupJoinRequestsController < ApplicationController
  # 参加申請・承認・拒否はログインユーザーのみ操作できるようにする
  before_action :require_authentication

  # 参加申請作成時は対象グループを取得する
  before_action :set_group, only: %i[create]

  # 承認・拒否時は対象の参加申請レコードを取得する
  before_action :set_group_join_request, only: %i[approve reject]

  # 承認・拒否はグループ作成者だけが実行できるようにする
  before_action :ensure_owner!, only: %i[approve reject]

  def create
    # ログイン中ユーザーの参加申請を作成する
    @group_join_request = @group.group_join_requests.new(user: current_user)

    if @group_join_request.save
      redirect_to group_path(@group), notice: "参加申請を送りました。"
    else
      redirect_to group_path(@group), alert: @group_join_request.errors.full_messages.join(", ")
    end
  end

  def approve
    # 定員に達している場合は承認できないようにする
    if @group_join_request.group.full?
      redirect_to requests_group_path(@group_join_request.group), alert: "定員に達しているため承認できません。"
      return
    end

    ActiveRecord::Base.transaction do
      # 申請状態を承認済みに更新し、同時にグループメンバーへ追加する
      @group_join_request.approved!
      GroupMembership.find_or_create_by!(
        group: @group_join_request.group,
        user: @group_join_request.user
      )
    end

    redirect_to requests_group_path(@group_join_request.group), notice: "参加申請を承認しました。"
  end

  def reject
    # 申請状態を拒否に更新する
    @group_join_request.rejected!
    redirect_to requests_group_path(@group_join_request.group), notice: "参加申請を拒否しました。"
  end

  private

  def set_group
    # URLパラメータから対象グループを取得する
    @group = Group.find(params[:group_id])
  end

  def set_group_join_request
    # 承認・拒否対象の申請レコードを取得する
    @group_join_request = GroupJoinRequest.find(params[:id])
  end

  def ensure_owner!
    # グループ作成者以外は承認・拒否を行えないようにする
    return if @group_join_request.group.owned_by?(current_user)

    redirect_to groups_path, alert: "権限がありません。"
  end
end