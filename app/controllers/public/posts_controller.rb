class Public::PostsController < ApplicationController
  # 一覧・詳細はログイン不要
  allow_unauthenticated_access only: %i[index show]

  # 投稿取得
  before_action :set_post, only: %i[show edit update destroy]

  # 投稿者本人チェック
  before_action :ensure_correct_user, only: %i[edit update destroy]

  # 投稿一覧
  def index
    @posts = Post.includes(:user).order(created_at: :desc)
  end

  # 投稿詳細
  def show
  end

  # 新規投稿
  def new
    @post = Post.new
  end

  # 作成処理
  def create
    @post = Current.user.posts.build(post_params)

    if @post.save
      redirect_to post_path(@post), notice: "投稿を作成しました。"
    else
      flash.now[:alert] = "投稿に失敗しました。"
      render :new, status: :unprocessable_entity
    end
  end

  # 編集画面
  def edit
  end

  # 更新処理
  def update
    if @post.update(post_params)
      redirect_to post_path(@post), notice: "投稿を更新しました。"
    else
      flash.now[:alert] = "更新に失敗しました。"
      render :edit, status: :unprocessable_entity
    end
  end

  # 削除処理
  def destroy
    @post.destroy
    redirect_to posts_path, notice: "投稿を削除しました。"
  end

  private

  # 投稿取得
  def set_post
    @post = Post.find(params[:id])
  end

  # パラメータ
  def post_params
    params.require(:post).permit(:title, :body, :study_time_hour, :study_time_minute)
  end

  # 本人チェック
  def ensure_correct_user
    return if @post.user == Current.user

    redirect_to posts_path, alert: "権限がありません。"
  end
end