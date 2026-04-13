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

    @owned_groups = @user.owned_groups
                         .includes(:members)
                         .order(created_at: :desc)

    @joined_groups = @user.joined_groups
                          .includes(:owner, :members)
                          .order(created_at: :desc)

    # 学習サマリー
    @posts_count = @posts.count
    @total_study_time = @posts.sum(:study_time)
    @weekly_study_time = @posts.where(created_at: Time.current.all_week).sum(:study_time)
    @streak_days = calculate_streak_days(@posts)

    # 直近7日分の学習時間データ
    today = Date.current
    days = (6.days.ago.to_date..today).to_a

    @weekly_study_chart_data = days.map do |day|
      total_minutes = @posts.where(created_at: day.all_day).sum(:study_time)

      {
        label: %w[日 月 火 水 木 金 土][day.wday],
        minutes: total_minutes
      }
    end
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
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation, :profile_image)
  end

  def calculate_streak_days(posts)
    studied_dates = posts.pluck(:created_at)
                         .map(&:to_date)
                         .uniq
                         .sort
                         .reverse

    streak = 0
    current_day = Date.current

    studied_dates.each do |date|
      if date == current_day
        streak += 1
        current_day -= 1
      else
        break
      end
    end

    streak
  end
end