class Public::RelationshipsController < ApplicationController
  before_action :set_user, only: :create
  before_action :set_relationship, only: :destroy

  def create
    current_user.follow(@user) unless current_user == @user || current_user.following?(@user)
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