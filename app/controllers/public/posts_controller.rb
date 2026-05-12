class Public::PostsController < ApplicationController
  # 投稿一覧と投稿詳細は未ログインでも閲覧できるようにする
  allow_unauthenticated_access only: %i[index show]

  # 詳細・編集・更新・削除では対象投稿を取得する
  before_action :set_post, only: %i[show edit update destroy]

  # 編集・更新・削除は投稿者本人だけに制限する
  before_action :ensure_correct_user, only: %i[edit update destroy]

  def index
    @tags = Tag.order(:name)
    @sort = params[:sort]
    @period = params[:period]
    @mode = params[:mode] || "all"

    @posts = PostSearchQuery.new(
      params: params,
      current_user: current_user,
      authenticated: authenticated?
    ).call.page(params[:page]).per(10)
  end

  def show
    # 下書きは投稿者本人だけが閲覧できるようにする
    if @post.draft? && (!authenticated? || @post.user != current_user)
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
    # 投稿は必ずログイン中ユーザーに紐づけて作成する
    @post = current_user.posts.build(post_params)

    if @post.save
      # タグは保存後に文字列から分解して関連付ける
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
    # フォームから受け取る投稿関連パラメータを制限する
    params.require(:post).permit(:title, :body, :study_time_hour, :study_time_minute, :tag_names, :status)
  end

  def ensure_correct_user
    # 投稿者本人以外は編集・更新・削除できないようにする
    return if @post.user == current_user

    redirect_to posts_path, alert: "権限がありません。"
  end
end