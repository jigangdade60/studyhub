class Public::PostsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  before_action :set_post, only: %i[show edit update destroy]
  before_action :ensure_correct_user, only: %i[edit update destroy]

  def index
    @tags = Tag.order(:name)
    @sort = params[:sort]
    @period = params[:period]
    @mode = params[:mode] || "all"

    base_posts =
      if authenticated?
        Post.includes(:user, :tags, :likes, :comments)
            .where("posts.status = ? OR posts.user_id = ?", Post.statuses[:published], Current.user.id)
      else
        Post.includes(:user, :tags, :likes, :comments)
            .where(status: :published)
      end

    if @mode == "following"
      base_posts =
        if authenticated?
          base_posts.where(user_id: Current.user.following_ids)
        else
          Post.none
        end
    end

    filtered_posts = base_posts
                     .keyword_search(params[:keyword])
                     .tag_search(params[:tag_name])
                     .period_search(params[:period])
                     .distinct

    @posts =
      case @sort
      when "old"
        filtered_posts.order(created_at: :asc)
      when "likes"
        filtered_posts
          .left_joins(:likes)
          .group("posts.id")
          .order(Arel.sql("COUNT(likes.id) DESC"), created_at: :desc)
      when "comments"
        filtered_posts
          .left_joins(:comments)
          .group("posts.id")
          .order(Arel.sql("COUNT(comments.id) DESC"), created_at: :desc)
      else
        filtered_posts.order(created_at: :desc)
      end
      
    @posts = @posts.page(params[:page]).per(10)
  end

  def show
    if @post.draft? && (!authenticated? || @post.user != Current.user)
      redirect_to posts_path, alert: "この投稿は表示できません。"
      return
    end

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
      redirect_to post_path(@post), notice: @post.draft? ? "下書きを保存しました。" : "投稿を作成しました。"
    else
      flash.now[:alert] = "投稿に失敗しました。"
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @post.update(post_params)
      @post.save_tags(post_params[:tag_names])
      redirect_to post_path(@post), notice: @post.draft? ? "下書きを更新しました。" : "投稿を更新しました。"
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
    params.require(:post).permit(:title, :body, :study_time_hour, :study_time_minute, :tag_names, :status)
  end

  def ensure_correct_user
    return if @post.user == Current.user

    redirect_to posts_path, alert: "権限がありません。"
  end
end