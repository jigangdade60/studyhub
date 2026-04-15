class Public::UsersController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  before_action :set_user, only: %i[show following followers]
  before_action :ensure_profile_visible, only: %i[show following followers]

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

    @users = User.search_by_name(@keyword)
                 .public_profiles
                 .order(created_at: :desc)

    if authenticated? && Current.user.present?
      @users = @users.or(User.where(id: Current.user.id)).distinct
    end
  end

  def show
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

    @posts_count = @posts.count
    @total_study_time = @posts.sum(:study_time)
    @weekly_study_time = @posts.where(created_at: Time.current.all_week).sum(:study_time)
    @streak_days = calculate_streak_days(@posts)

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
    @users = @user.following.public_profiles

    if authenticated? && Current.user.present? && @user == Current.user
      @users = @user.following
    end
  end

  def followers
    @users = @user.followers.public_profiles

    if authenticated? && Current.user.present? && @user == Current.user
      @users = @user.followers
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def ensure_profile_visible
    return if @user.visible_to?(Current.user)

    redirect_to users_path, alert: "このユーザーのプロフィールは非公開です。"
  end

  def user_params
    params.require(:user).permit(
      :name,
      :email_address,
      :password,
      :password_confirmation,
      :profile_image,
      :is_public
    )
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