module Public
  class LikesController < ApplicationController
    # いいね機能はログインユーザーのみ利用できるようにする
    before_action :require_authentication

    def index
      # 自分がいいねした投稿一覧を取得する
      @liked_posts = current_user.liked_posts
                                 .includes(:user)
                                 .order(created_at: :desc)

      @liked_posts = @liked_posts.page(params[:page]).per(10)
    end

    def create
      @post = Post.find(params[:post_id])

      # 同じ投稿への重複いいねを防ぎつつ、いいねを作成する
      @post.likes.find_or_create_by!(user: current_user)

      respond_to do |format|
        # 通常リクエスト時は元の画面へ戻す
        format.html { redirect_back fallback_location: posts_path, notice: "いいねしました。" }

        # Turbo Stream により一覧やボタン表示を非同期で更新する
        format.turbo_stream
      end
    end

    def destroy
      @post = Post.find(params[:post_id])

      # ログイン中ユーザー自身のいいねだけ削除する
      like = @post.likes.find_by(user: current_user)
      like&.destroy

      respond_to do |format|
        # 通常リクエスト時は元の画面へ戻す
        format.html { redirect_back fallback_location: posts_path, notice: "いいねを取り消しました。" }

        # Turbo Stream により一覧やボタン表示を非同期で更新する
        format.turbo_stream
      end
    end
  end
end