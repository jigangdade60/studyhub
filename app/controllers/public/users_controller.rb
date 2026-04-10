class Public::UsersController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for @user
      redirect_to mypage_path, notice: "登録が完了しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def index
    @keyword = params[:keyword]
    @users = User.search_by_name(@keyword).order(created_at: :desc)
  end

  def show
    @user = User.find(params[:id])
    @posts = @user.posts.order(created_at: :desc)
  end

  def mypage
    @user = Current.user
    @posts = @user.posts.order(created_at: :desc)
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(user_params)
      redirect_to mypage_path, notice: "プロフィールを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user = Current.user
    @user.destroy
    redirect_to root_path, notice: "退会しました。"
  end

  def following
    @user = User.find(params[:id])
    @users = @user.following
  end

  def followers
    @user = User.find(params[:id])
    @users = @user.followers
  end

  private

  def user_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
  end
end