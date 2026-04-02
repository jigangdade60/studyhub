class Public::UsersController < ApplicationController
  # サインアップ関連は未ログインでもアクセス可能
  allow_unauthenticated_access only: %i[new create]

  # マイページ関連はログインユーザーのみ
  before_action :set_current_user, only: %i[mypage edit update destroy]

  def new
    # 新規登録用のユーザーインスタンス
    @user = User.new
  end

  def create
    # 新規登録処理
    @user = User.new(user_params)

    if @user.save
      redirect_to new_session_path, notice: "アカウントを作成しました。ログインしてください。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def mypage
    # ログイン中ユーザーの投稿一覧を新しい順で取得
    @posts = @user.posts.order(created_at: :desc)
  end

  def edit
  end

  def update
    # ユーザー情報を更新
    if @user.update(user_params)
      redirect_to mypage_path, notice: "ユーザー情報を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # 退会対象のユーザーを保持
    user = @user

    # 先にログアウト処理を行う
    terminate_session

    # ユーザーを物理削除
    user.destroy

    # 退会後は新規登録画面へ遷移
    redirect_to new_user_path, notice: "退会処理が完了しました。ご利用ありがとうございました。"
  end

  private

  def set_current_user
    # 現在ログインしているユーザーを取得
    @user = Current.user
  end

  def user_params
    # 編集・登録を許可するカラム
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
  end
end