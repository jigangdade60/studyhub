class Public::RelationshipsController < ApplicationController
  before_action :set_user, only: :create
  before_action :set_relationship, only: :destroy

  def create
    unless current_user == @user || current_user.following?(@user)
      current_user.follow(@user)

      relationship = Relationship.find_by(
        follower_id: current_user.id,
        followed_id: @user.id
      )

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
    @relationship.destroy if @relationship.follower == current_user
    redirect_back fallback_location: user_path(user), notice: "フォロー解除しました。"
  end

  private

  def set_user
    @user = User.find(params[:followed_id])
  end

  def set_relationship
    @relationship = Relationship.find(params[:id])
  end
end