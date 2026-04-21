class Admin::UsersController < Admin::BaseController
  def index
    # 管理者画面では全ユーザーを新しい順で一覧表示する
    @users = User.order(created_at: :desc)
                 .page(params[:page])
                 .per(10)
  end

  def show
    # 管理者が個別ユーザーの詳細を確認する
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])

    # 管理者がユーザーの状態を更新する
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: "ユーザー情報を更新しました。"
    else
      flash.now[:alert] = "更新に失敗しました。"
      render :show, status: :unprocessable_entity
    end
  end

  def withdraw
    @user = User.find(params[:id])

    # 物理削除ではなく is_active を false にして論理的に退会扱いにする
    # データを残したまま運用できるため、投稿や関連データの整合性を保ちやすい
    @user.update!(is_active: false)

    redirect_to admin_user_path(@user), notice: "退会処理を行いました。"
  end

  def activate
    @user = User.find(params[:id])

    # 管理者が退会状態のユーザーを再び有効化できるようにする
    @user.update!(is_active: true)

    redirect_to admin_user_path(@user), notice: "ユーザーを有効化しました。"
  end

  private

  def user_params
    # 管理者画面から更新できる項目を制限する
    params.require(:user).permit(:is_active)
  end
end