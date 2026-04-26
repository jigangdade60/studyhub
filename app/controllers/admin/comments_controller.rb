class Admin::CommentsController < ApplicationController
  # 管理画面でも共通の認証機能を利用する
  include Authentication

  # 削除時は対象コメントを事前に取得する
  before_action :set_comment, only: [:destroy]

  def index
    # 管理者がコメント一覧を確認しやすいように、
    # 投稿者と対象投稿もあわせて取得して新しい順に表示する
    @comments = Comment.includes(:user, :post).order(created_at: :desc)
                       .page(params[:page]).per(10)
  end

  def destroy
    # 管理者は不適切なコメントを削除できる
    # 一般ユーザーと異なり、本人以外のコメントも管理権限で削除可能
    @comment.destroy
    redirect_to admin_comments_path, notice: "コメントを削除しました。"
  end

  private

  def set_comment
    # URLパラメータから対象コメントを取得する
    @comment = Comment.find(params[:id])
  end
end