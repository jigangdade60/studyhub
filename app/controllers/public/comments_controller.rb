class Public::CommentsController < ApplicationController
  before_action :set_post, only: %i[create destroy]

  def create
    # コメントは対象投稿に紐づけて作成する
    @comment = @post.comments.build(comment_params)

    # コメント投稿者はログイン中ユーザーに固定する
    @comment.user = current_user

    if @comment.save
      redirect_to post_path(@post), notice: t("flash.notice.comment_created")
    else
      # バリデーションエラー時は投稿詳細画面を再表示できるように表示用データを再取得する
      set_view_resources
      render "public/posts/show", status: :unprocessable_entity
    end
  end

  def destroy
    # 自分が投稿したコメントだけ削除できるようにする
    @comment = current_user.comments.find(params[:id])
    @comment.destroy

    redirect_to post_path(@post), notice: t("flash.notice.comment_deleted")
  end

  private

  def set_post
    # ネストされたルーティングから対象投稿を取得する
    @post = Post.find(params[:post_id])
  end

  def set_view_resources
    @comments = @post.comments.includes(:user).order(created_at: :desc)
  end

  def comment_params
    # コメント本文のみ受け取る
    params.require(:comment).permit(:body)
  end
end
