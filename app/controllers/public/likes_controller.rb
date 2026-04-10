module Public
  class LikesController < ApplicationController
    def create
      @post = Post.find(params[:post_id])
      @post.likes.find_or_create_by!(user: current_user)

      respond_to do |format|
        format.html { redirect_back fallback_location: posts_path, notice: "いいねしました。" }
        format.turbo_stream
      end
    end

    def destroy
      @post = Post.find(params[:post_id])
      like = @post.likes.find_by(user: current_user)
      like&.destroy

      respond_to do |format|
        format.html { redirect_back fallback_location: posts_path, notice: "いいねを取り消しました。" }
        format.turbo_stream
      end
    end
  end
end