class Public::UsersController < ApplicationController
  # =========================
  # アクセス制御
  # =========================

  # 新規登録画面(new)と会員登録処理(create)は、
  # まだログインしていないユーザーが利用する画面のため、
  # ログイン必須チェックをスキップする
  allow_unauthenticated_access only: %i[new create]

  # ユーザー詳細・フォロー一覧・フォロワー一覧では、
  # URLの params[:id] から対象ユーザーを取得する
  #
  # 例：
  # /users/1 の場合 → params[:id] は 1
  before_action :set_user, only: %i[show following followers]

  # マイページ・編集・更新・退会処理では、
  # URLのIDではなく「ログイン中のユーザー自身」を操作対象にする
  #
  # これにより、他人のプロフィールを編集・退会できないようにしている
  before_action :set_current_user, only: %i[mypage edit update destroy]

  # 非公開プロフィールのユーザーは、
  # 本人以外から詳細画面・フォロー一覧・フォロワー一覧を見られないようにする
  before_action :ensure_profile_visible, only: %i[show following followers]

  # ユーザー詳細画面とマイページで表示する投稿一覧を取得する
  before_action :set_posts, only: %i[show mypage]

  # ユーザーが参加しているグループを取得する
  before_action :set_joined_groups, only: %i[show mypage]

  # マイページでは、自分が作成したグループも表示するため取得する
  before_action :set_owned_groups, only: %i[mypage]

  # ユーザー詳細画面・マイページで表示する学習時間や投稿数などの統計情報を取得する
  before_action :set_learning_statistics, only: %i[show mypage]

  # =========================
  # 新規登録
  # =========================

  def new
    # 新規登録フォームで使用する空のUserオブジェクトを作成する
    #
    # form_with model: @user のように使うことで、
    # 入力フォームとUserモデルを紐づけられる
    @user = User.new
  end

  def create
    # フォームから送信された値を使って、新しいユーザーを作成する
    #
    # user_paramsを通すことで、
    # 許可した項目だけを保存対象にしている
    @user = User.new(user_params)

    if @user.save
      # 登録に成功した場合、
      # 登録完了と同時にログイン状態を作成する
      #
      # これにより、登録後に再度ログイン画面へ移動する必要がなくなる
      start_new_session_for @user

      # 登録完了後はマイページへ遷移する
      redirect_to mypage_path, notice: t("flash.notice.registration_complete")
    else
      # バリデーションエラーなどで登録に失敗した場合、
      # 入力内容とエラーメッセージを保持したまま新規登録画面を再表示する
      #
      # status: :unprocessable_entity は、
      # 入力内容に問題があり処理できなかったことを表すHTTPステータス
      render :new, status: :unprocessable_entity
    end
  end

  # =========================
  # ユーザー一覧
  # =========================

  def index
    # 検索フォームから送られてきたキーワードを取得する
    @keyword = params[:keyword]

    # ユーザー名で検索し、
    # 公開プロフィールのユーザーだけを対象にする
    #
    # order(created_at: :desc) により、新しく登録したユーザーから表示する
    #
    # with_attached_profile_image は、
    # プロフィール画像を事前読み込みしてN+1問題を防ぐために使用する
    @users = User.search_by_name(@keyword)
                 .public_profiles
                 .order(created_at: :desc)
                 .with_attached_profile_image

    # ログイン中の場合、
    # 自分自身が非公開プロフィールに設定していても、
    # 自分は一覧で確認できるようにする
    #
    # public_profiles は公開ユーザーだけを取得するため、
    # 非公開の自分を or で追加している
    if authenticated? && current_user.present?
      @users = @users.or(User.where(id: current_user.id)).distinct
    end

    # kaminariを使って、10件ずつページネーションする
    @users = @users.page(params[:page]).per(10)
  end

  # =========================
  # ユーザー詳細・マイページ
  # =========================

  def show
    # 表示に必要なデータは before_action で取得済み
    #
    # set_user                 → 表示対象ユーザー
    # ensure_profile_visible   → 非公開プロフィール制御
    # set_posts                → 投稿一覧
    # set_joined_groups        → 参加グループ
    # set_learning_statistics  → 学習統計
  end

  def mypage
    # マイページに必要なデータは before_action で取得済み
    #
    # set_current_user         → ログイン中ユーザー
    # set_posts                → 自分の投稿一覧
    # set_joined_groups        → 自分が参加しているグループ
    # set_owned_groups         → 自分が作成したグループ
    # set_learning_statistics  → 学習統計
  end

  # =========================
  # プロフィール編集
  # =========================

  def edit
    # 編集対象は before_action の set_current_user で取得している
    #
    # URLで他人のIDを指定するのではなく、
    # 常に current_user を編集対象にすることで、
    # 他ユーザーのプロフィールを編集できないようにしている
  end

  def update
    # ログイン中ユーザーのプロフィール情報を更新する
    #
    # user_paramsで許可した項目だけ更新できるようにしている
    if @user.update(user_params)
      # 更新に成功した場合はマイページへ遷移する
      redirect_to mypage_path, notice: t("flash.notice.profile_updated")
    else
      # バリデーションエラーなどで更新に失敗した場合、
      # 入力内容とエラー内容を保持したまま編集画面を再表示する
      render :edit, status: :unprocessable_entity
    end
  end

  # =========================
  # 退会処理
  # =========================

  def destroy
    # ログイン中ユーザー自身を削除する
    #
    # set_current_user により @user = current_user となっているため、
    # 他人のアカウントを削除できない
    @user.destroy

    # 退会後はトップページへ遷移する
    redirect_to root_path, notice: t("flash.notice.account_withdrawn")
  end

  # =========================
  # フォロー一覧
  # =========================

  def following
    # 対象ユーザーがフォローしているユーザー一覧を取得する
    #
    # 他人のページを見る場合は、
    # 非公開プロフィールのユーザーを表示しないように public_profiles を指定する
    @users = @user.following.public_profiles.with_attached_profile_image

    # 自分自身のフォロー一覧を見る場合は、
    # 非公開プロフィールのユーザーも含めて確認できるようにする
    #
    # 例：
    # 自分が非公開ユーザーをフォローしている場合でも、
    # 自分の画面では確認できるようにする
    if authenticated? && current_user.present? && @user == current_user
      @users = @user.following.with_attached_profile_image
    end

    # 10件ずつページネーションする
    @users = @users.page(params[:page]).per(10)
  end

  # =========================
  # フォロワー一覧
  # =========================

  def followers
    # 対象ユーザーをフォローしているユーザー一覧を取得する
    #
    # 他人のページを見る場合は、
    # 非公開プロフィールのユーザーを表示しないように public_profiles を指定する
    @users = @user.followers.public_profiles.with_attached_profile_image

    # 自分自身のフォロワー一覧を見る場合は、
    # 非公開プロフィールのユーザーも含めて確認できるようにする
    #
    # これにより、自分をフォローしている非公開ユーザーも確認できる
    if authenticated? && current_user.present? && @user == current_user
      @users = @user.followers.with_attached_profile_image
    end

    # 10件ずつページネーションする
    @users = @users.page(params[:page]).per(10)
  end

  private

  # =========================
  # ユーザー取得処理
  # =========================

  def set_user
    # URLパラメータのIDから対象ユーザーを取得する
    #
    # show / following / followers のように、
    # 他ユーザーの情報を表示する画面で使用する
    @user = User.find(params[:id])
  end

  def set_current_user
    # ログイン中のユーザーを @user に代入する
    #
    # edit / update / destroy / mypage では、
    # 他人ではなく自分自身を操作対象にする必要があるため、
    # params[:id] ではなく current_user を使う
    @user = current_user
  end

  # =========================
  # プロフィール公開制御
  # =========================

  def ensure_profile_visible
    # visible_to? メソッドで、
    # 現在アクセスしているユーザーがこのプロフィールを閲覧できるか判定する
    #
    # 公開プロフィールの場合 → 誰でも閲覧可能
    # 非公開プロフィールの場合 → 本人のみ閲覧可能
    return if @user.visible_to?(current_user)

    # 閲覧権限がない場合はユーザー一覧へ戻す
    redirect_to users_path, alert: t("flash.alert.profile_private")
  end

  # =========================
  # 投稿一覧取得
  # =========================

  def set_posts
    # 対象ユーザーの投稿を新しい順に取得する
    #
    # @user は show の場合は表示対象ユーザー、
    # mypage の場合はログイン中ユーザーになる
    all_posts = @user.posts.order(created_at: :desc)

    # 投稿一覧を10件ずつページネーションする
    @posts = all_posts.page(params[:page]).per(10)
  end

  # =========================
  # 作成グループ取得
  # =========================

  def set_owned_groups
    # ユーザーが作成したグループを取得する
    #
    # includes(:members) により、
    # グループごとのメンバー取得時のN+1問題を防ぐ
    @owned_groups = @user.owned_groups
                         .includes(:members)
                         .order(created_at: :desc)

    # グループメンバーのプロフィール画像をまとめて事前読み込みする
    #
    # Active Storage の画像を個別に取得するとN+1問題が起きるため、
    # Preloaderを使って一括で読み込んでいる
    members = @owned_groups.flat_map(&:members)

    if members.any?
      ActiveRecord::Associations::Preloader.new(
        records: members,
        associations: { profile_image_attachment: :blob }
      ).call
    end
  end

  # =========================
  # 参加グループ取得
  # =========================

  def set_joined_groups
    # ユーザーが参加しているグループを取得する
    #
    # includes(:owner, :members) により、
    # グループ作成者とメンバー情報を事前読み込みしてN+1問題を防ぐ
    @joined_groups = @user.joined_groups
                          .includes(:owner, :members)
                          .order(created_at: :desc)

    # グループ作成者のプロフィール画像をまとめて取得する
    owners = @joined_groups.map(&:owner).compact

    # グループメンバーのプロフィール画像をまとめて取得する
    members = @joined_groups.flat_map(&:members)

    # owner と members をまとめて、
    # Active Storage のプロフィール画像を一括で事前読み込みする
    #
    # これにより、画面表示時にユーザーごとに画像取得SQLが発行されることを防ぐ
    users = owners + members

    if users.any?
      ActiveRecord::Associations::Preloader.new(
        records: users,
        associations: { profile_image_attachment: :blob }
      ).call
    end
  end

  # =========================
  # 学習統計取得
  # =========================

  def set_learning_statistics
    # 投稿数・総学習時間・週間学習時間などの計算は、
    # Controllerに直接書くと処理が肥大化しやすい
    #
    # そのため、UserStatisticsというService Objectに切り出している
    #
    # Controllerは「画面表示に必要な値を受け取る役割」に絞り、
    # 集計ロジックはService側に任せている
    statistics = UserStatistics.new(@user)

    # 投稿数
    @posts_count = statistics.posts_count

    # 総学習時間
    @total_study_time = statistics.total_study_time

    # 今週の学習時間
    @weekly_study_time = statistics.weekly_study_time

    # 連続学習日数
    @streak_days = statistics.streak_days

    # Chart.jsで週間学習時間を表示するためのデータ
    @weekly_study_chart_data = statistics.weekly_study_chart_data
  end

  # =========================
  # ストロングパラメータ
  # =========================

  def user_params
    # フォームから送られてきたparamsのうち、
    # Userモデルに保存してよい項目だけを許可する
    #
    # これにより、悪意あるユーザーが管理用カラムなどを送信しても、
    # 許可していない値は更新されない
    #
    # 例：
    # is_admin のようなカラムが仮に存在していても、
    # permitに書いていなければ更新対象にならない
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
