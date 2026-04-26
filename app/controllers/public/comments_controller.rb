class Public::CommentsController < ApplicationController
  def create
    # ネストされたルーティングから対象投稿を取得する
    @post = Post.find(params[:post_id])

    # コメントは対象投稿に紐づけて作成する
    @comment = @post.comments.build(comment_params)

    # コメント投稿者はログイン中ユーザーに固定する
    @comment.user = current_user

    if @comment.save
      redirect_to post_path(@post), notice: "コメントを投稿しました。"
    else
      # バリデーションエラー時は投稿詳細画面を再表示できるようにコメント一覧も再取得する
      @comments = @post.comments.includes(:user).order(created_at: :desc)
      render "public/posts/show", status: :unprocessable_entity
    end
  end

  def destroy
    @post = Post.find(params[:post_id])

    # 自分が投稿したコメントだけ削除できるようにする
    @comment = current_user.comments.find(params[:id])
    @comment.destroy

    redirect_to post_path(@post), notice: "コメントを削除しました。"
  end

  private

  def comment_params
    # コメント本文のみ受け取る
    params.require(:comment).permit(:body)
  end
end