class Public::RelationshipsController < ApplicationController
  # フォロー作成時は対象ユーザーを取得する
  before_action :set_user, only: :create

  # フォロー解除時は対象の Relationship レコードを取得する
  before_action :set_relationship, only: :destroy

  def create
    # 自分自身へのフォロー、または既にフォロー済みの場合は作成しない
    unless current_user == @user || current_user.following?(@user)
      current_user.follow(@user)

      # 作成されたフォロー関係を取得し、通知作成に利用する
      relationship = Relationship.find_by(
        follower_id: current_user.id,
        followed_id: @user.id
      )

      # フォロー成功時は相手ユーザーへ通知を送る
      if relationship.present?
        Notification.create!(
          recipient: @user,
          actor: current_user,
          notifiable: relationship,
          action: :followed
        )
      end
    end

    redirect_back fallback_location: user_path(@user), notice: "フォローしました。"
  end

  def destroy
    user = @relationship.followed

    # 自分が作成したフォロー関係だけ解除できるようにする
    @relationship.destroy if @relationship.follower == current_user

    redirect_back fallback_location: user_path(user), notice: "フォロー解除しました。"
  end

  private

  def set_user
    # フォロー対象ユーザーを取得する
    @user = User.find(params[:followed_id])
  end

  def set_relationship
    # フォロー解除対象のレコードを取得する
    @relationship = Relationship.find(params[:id])
  end
end