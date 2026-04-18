class Admin::UsersController < Admin::BaseController
    def index
      @users = User.order(created_at: :desc)
                   .page(params[:page])
                    .per(10)
    end

    def show
      @user = User.find(params[:id])
    end

    def update
      @user = User.find(params[:id])

      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: "ユーザー情報を更新しました。"
      else
        flash.now[:alert] = "更新に失敗しました。"
        render :show, status: :unprocessable_entity
      end
    end

    def withdraw
      @user = User.find(params[:id])
      @user.update!(is_active: false)

      redirect_to admin_user_path(@user), notice: "退会処理を行いました。"
    end

    def activate
      @user = User.find(params[:id])
      @user.update!(is_active: true)

      redirect_to admin_user_path(@user), notice: "ユーザーを有効化しました。"
    end

    private

    def user_params
      params.require(:user).permit(:is_active)
    end
  
end