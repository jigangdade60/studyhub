class Admin::GroupsController < ApplicationController
  before_action :require_admin_authentication
  before_action :set_group, only: %i[destroy]

  def index
    @groups = Group.includes(:owner, :members).order(created_at: :desc)
  end

  def destroy
    @group.destroy
    redirect_to admin_groups_path, notice: "もくもく会を削除しました。"
  end

  private

  def set_group
    @group = Group.find(params[:id])
  end

  def require_admin_authentication
    return if current_admin.present?

    redirect_to admin_login_path, alert: "管理者ログインが必要です。"
  end
end