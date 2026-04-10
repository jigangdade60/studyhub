class Public::PostsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  before_action :set_post, only: %i[show edit update destroy]
  before_action :ensure_correct_user, only: %i[edit update destroy]

  def index
    @tags = Tag.order(:name)

    @posts = Post.includes(:user, :tags, :likes, :comments)
                 .order(created_at: :desc)
                 .keyword_search(params[:keyword])
                 .tag_search(params[:tag_name])
  end

  def show
    @comment = Comment.new
    @comments = @post.comments.includes(:user).order(created_at: :desc)
  end

  def new
    @post = Post.new
  end

  def create
    @post = Current.user.posts.build(post_params)

    if @post.save
      @post.save_tags(post_params[:tag_names])
      redirect_to post_path(@post), notice: "投稿を作成しました。"
    else
      flash.now[:alert] = "投稿に失敗しました。"
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @post.update(post_params)
      @post.save_tags(post_params[:tag_names])
      redirect_to post_path(@post), notice: "投稿を更新しました。"
    else
      flash.now[:alert] = "更新に失敗しました。"
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to posts_path, notice: "投稿を削除しました。"
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :body, :study_time_hour, :study_time_minute, :tag_names)
  end

  def ensure_correct_user
    return if @post.user == Current.user

    redirect_to posts_path, alert: "権限がありません。"
  end
end