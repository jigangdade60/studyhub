class Public::UsersController < ApplicationController
  # 新規登録画面と会員登録処理は未ログインでもアクセスできるようにする
  allow_unauthenticated_access only: %i[new create]

  # ユーザー詳細・フォロー一覧・フォロワー一覧では対象ユーザーを取得する
  before_action :set_user, only: %i[show following followers]

  # 非公開プロフィールは本人以外から閲覧できないように制御する
  before_action :ensure_profile_visible, only: %i[show following followers]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      # 登録完了と同時にログイン状態を作り、そのままマイページへ遷移させる
      start_new_session_for @user
      redirect_to mypage_path, notice: "登録が完了しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def index
    @keyword = params[:keyword]

    # 公開ユーザーのみを対象に、名前検索と新着順表示を行う
    @users = User.search_by_name(@keyword)
                 .public_profiles
                 .order(created_at: :desc)

    # ログイン中は、自分が非公開設定でも一覧に表示できるようにする
    if authenticated? && Current.user.present?
      @users = @users.or(User.where(id: Current.user.id)).distinct
    end

    @users = @users.page(params[:page]).per(10)
  end

  def show
    all_posts = @user.posts.order(created_at: :desc)
    @posts = all_posts.page(params[:page]).per(10)

    # 参加中グループをあわせて表示できるように取得する
    @joined_groups = @user.joined_groups
                          .includes(:owner, :members)
                          .order(created_at: :desc)

    # 学習の見える化のために、投稿数・累計学習時間・今週の学習時間・連続学習日数を算出する
    @posts_count = all_posts.count
    @total_study_time = all_posts.sum(:study_time)
    @weekly_study_time = all_posts.where(created_at: Time.current.all_week).sum(:study_time)
    @streak_days = calculate_streak_days(all_posts)

    # 直近7日分の学習時間をグラフ表示用データに変換する
    today = Date.current
    days = (6.days.ago.to_date..today).to_a

    @weekly_study_chart_data = days.map do |day|
      total_minutes = all_posts.where(created_at: day.all_day).sum(:study_time)

      {
        label: %w[日 月 火 水 木 金 土][day.wday],
        minutes: total_minutes
      }
    end
  end

  def mypage
    # マイページは現在ログイン中のユーザー情報を表示する
    @user = Current.user
    all_posts = @user.posts.order(created_at: :desc)
    @posts = all_posts.page(params[:page]).per(10)

    # 自分が作成したグループと参加しているグループを分けて表示する
    @owned_groups = @user.owned_groups
                         .includes(:members)
                         .order(created_at: :desc)

    @joined_groups = @user.joined_groups
                          .includes(:owner, :members)
                          .order(created_at: :desc)

    # 学習サマリー表示用データ
    @posts_count = all_posts.count
    @total_study_time = all_posts.sum(:study_time)
    @weekly_study_time = all_posts.where(created_at: Time.current.all_week).sum(:study_time)
    @streak_days = calculate_streak_days(all_posts)

    # 直近7日分の学習グラフ用データ
    today = Date.current
    days = (6.days.ago.to_date..today).to_a

    @weekly_study_chart_data = days.map do |day|
      total_minutes = all_posts.where(created_at: day.all_day).sum(:study_time)

      {
        label: %w[日 月 火 水 木 金 土][day.wday],
        minutes: total_minutes
      }
    end
  end

  def edit
    # 他ユーザーではなく、自分自身のプロフィールのみ編集できる
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
    # ログイン中ユーザー自身の退会処理
    @user = Current.user
    @user.destroy
    redirect_to root_path, notice: "退会しました。"
  end

  def following
    # 他ユーザーのページでは公開プロフィールのユーザーだけ表示する
    @users = @user.following.public_profiles

    # 自分自身のページでは非公開ユーザーも含めて確認できるようにする
    if authenticated? && Current.user.present? && @user == Current.user
      @users = @user.following
    end

    @users = @users.page(params[:page]).per(10)
  end

  def followers
    # 他ユーザーのページでは公開プロフィールのユーザーだけ表示する
    @users = @user.followers.public_profiles

    # 自分自身のページでは非公開ユーザーも含めて確認できるようにする
    if authenticated? && Current.user.present? && @user == Current.user
      @users = @user.followers
    end

    @users = @users.page(params[:page]).per(10)
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def ensure_profile_visible
    # 非公開ユーザーのプロフィールは本人以外アクセスできないようにする
    return if @user.visible_to?(Current.user)

    redirect_to users_path, alert: "このユーザーのプロフィールは非公開です。"
  end

  def user_params
    # 会員登録・プロフィール更新で受け取るパラメータを制限する
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
    # 投稿日を日付単位に変換し、連続学習日数を計算する
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