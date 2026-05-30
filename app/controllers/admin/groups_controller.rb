class Admin::GroupsController < ApplicationController
  # 管理者のみグループ管理機能を利用できるようにする
  before_action :require_admin_authentication

  # 削除時は対象グループを取得する
  before_action :set_group, only: %i[destroy]

  def index
    # 管理者がグループ一覧を確認しやすいように、
    # 作成者とメンバー情報も含めて新しい順で表示する
    @groups = Group.includes(:owner, :members)
             .order(created_at: :desc)
             .page(params[:page]).per(10)

    owners = @groups.map(&:owner).compact
    members = @groups.flat_map(&:members)
    ActiveRecord::Associations::Preloader.new(records: owners + members, associations: { profile_image_attachment: :blob }).call if (owners + members).any?
  end

  def destroy
    # 管理者は不適切なグループを削除できる
    # 一般ユーザーとは異なり、作成者でなくても削除可能
    @group.destroy
    redirect_to admin_groups_path, notice: t("flash.notice.group_deleted")
  end

  private

  def set_group
    # URLパラメータから対象グループを取得する
    @group = Group.find(params[:id])
  end

  def require_admin_authentication
    # 管理者としてログインしているかを確認する
    return if current_admin.present?

    redirect_to admin_login_path, alert: t("flash.alert.admin_login_required")
  end
end
