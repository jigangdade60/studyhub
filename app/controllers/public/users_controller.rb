class Public::UsersController < ApplicationController
  # 新規登録画面と会員登録処理は未ログインでもアクセスできるようにする
  allow_unauthenticated_access only: %i[new create]

  # ユーザー詳細・フォロー一覧・フォロワー一覧では対象ユーザーを取得する
  before_action :set_user, only: %i[show following followers]

  # マイページ・編集・更新・退会では現在ログイン中のユーザーを取得する
  before_action :set_current_user, only: %i[mypage edit update destroy]

  # 非公開プロフィールは本人以外から閲覧できないように制御する
  before_action :ensure_profile_visible, only: %i[show following followers]

  # ユーザー詳細・マイページで表示するデータを取得する
  before_action :set_posts, only: %i[show mypage]
  before_action :set_joined_groups, only: %i[show mypage]
  before_action :set_owned_groups, only: %i[mypage]
  before_action :set_learning_statistics, only: %i[show mypage]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      # 登録完了と同時にログイン状態を作り、そのままマイページへ遷移させる
      start_new_session_for @user
      redirect_to mypage_path, notice: t("flash.notice.registration_complete")
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
    if authenticated? && current_user.present?
      @users = @users.or(User.where(id: current_user.id)).distinct
    end

    @users = @users.page(params[:page]).per(10)
  end

  def show
  end

  def mypage
  end

  def edit
    # 他ユーザーではなく、自分自身のプロフィールのみ編集できる
  end

  def update
    if @user.update(user_params)
      redirect_to mypage_path, notice: t("flash.notice.profile_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # ログイン中ユーザー自身の退会処理
    @user.destroy
    redirect_to root_path, notice: t("flash.notice.account_withdrawn")
  end

  def following
    # 他ユーザーのページでは公開プロフィールのユーザーだけ表示する
    @users = @user.following.public_profiles

    # 自分自身のページでは非公開ユーザーも含めて確認できるようにする
    if authenticated? && current_user.present? && @user == current_user
      @users = @user.following
    end

    @users = @users.page(params[:page]).per(10)
  end

  def followers
    # 他ユーザーのページでは公開プロフィールのユーザーだけ表示する
    @users = @user.followers.public_profiles

    # 自分自身のページでは非公開ユーザーも含めて確認できるようにする
    if authenticated? && current_user.present? && @user == current_user
      @users = @user.followers
    end

    @users = @users.page(params[:page]).per(10)
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_current_user
    @user = current_user
  end

  def ensure_profile_visible
    # 非公開ユーザーのプロフィールは本人以外アクセスできないようにする
    return if @user.visible_to?(current_user)

    redirect_to users_path, alert: t("flash.alert.profile_private")
  end

  def set_posts
    all_posts = @user.posts.order(created_at: :desc)
    @posts = all_posts.page(params[:page]).per(10)
  end

  def set_owned_groups
    @owned_groups = @user.owned_groups
                         .includes(:members)
                         .order(created_at: :desc)
  end

  def set_joined_groups
    @joined_groups = @user.joined_groups
                          .includes(:owner, :members)
                          .order(created_at: :desc)
  end

  def set_learning_statistics
    # 学習サマリー表示用データはService Objectに切り出す
    statistics = UserStatistics.new(@user)

    @posts_count = statistics.posts_count
    @total_study_time = statistics.total_study_time
    @weekly_study_time = statistics.weekly_study_time
    @streak_days = statistics.streak_days
    @weekly_study_chart_data = statistics.weekly_study_chart_data
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
end
