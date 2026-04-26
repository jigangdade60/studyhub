class Public::GroupsController < ApplicationController
  # グループ一覧と詳細は未ログインでも閲覧できるようにする
  allow_unauthenticated_access only: %i[index show]

  # 詳細表示と申請一覧表示では対象グループを取得する
  before_action :set_group, only: %i[show requests]

  # グループ作成と申請管理はログインユーザーのみ利用できるようにする
  before_action :require_authentication, only: %i[new create requests]

  # 参加申請一覧はグループ作成者だけが閲覧できるようにする
  before_action :ensure_owner!, only: %i[requests]

  def index
    @keyword = params[:keyword]

    # 作成者・参加メンバーを含めて取得し、キーワード検索と新着順で一覧表示する
    @groups = Group.includes(:owner, :members)
                   .search_by_keyword(@keyword)
                   .order(created_at: :desc)
                   .page(params[:page]).per(10)
  end

  def show
    # グループ詳細ではメッセージ一覧と新規投稿フォームを表示する
    @group_messages = @group.group_messages.includes(:user).order(created_at: :asc)
    @group_message = GroupMessage.new
  end

  def new
    @group = Group.new
  end

  def create
    @group = Group.new(group_params)

    # グループ作成者を owner として紐づける
    @group.owner = current_user

    ActiveRecord::Base.transaction do
      # グループ作成と同時に、作成者自身をメンバー登録する
      @group.save!
      GroupMembership.create!(group: @group, user: current_user)
    end

    redirect_to group_path(@group), notice: "もくもく会を作成しました。"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def requests
    # 作成者が参加申請中ユーザーを確認できるようにする
    @requests = @group.group_join_requests
                      .pending
                      .includes(:user)
                      .order(created_at: :asc)
  end

  private

  def set_group
    # URLパラメータから対象グループを取得する
    @group = Group.find(params[:id])
  end

  def ensure_owner!
    # グループ作成者以外は申請管理画面にアクセスできないようにする
    return if @group.owned_by?(current_user)

    redirect_to groups_path, alert: "権限がありません。"
  end

  def group_params
    # フォームから受け取るグループ作成項目を制限する
    params.require(:group).permit(:name, :description, :rule, :study_theme, :max_members)
  end
end