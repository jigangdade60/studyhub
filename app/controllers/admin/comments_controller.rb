class Admin::CommentsController < ApplicationController
  include Authentication
  before_action :set_comment, only: [:destroy]

  def index
    @comments = Comment.includes(:user, :post).order(created_at: :desc)
  end

  def destroy
    @comment.destroy
    redirect_to admin_comments_path, notice: "コメントを削除しました。"
  end

  private

  def set_comment
    @comment = Comment.find(params[:id])
  end
end