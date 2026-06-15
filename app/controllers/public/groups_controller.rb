class Public::GroupsController < ApplicationController
  # =========================
  # アクセス制御
  # =========================

  # グループ一覧(index)とグループ詳細(show)は、
  # 未ログインユーザーでも閲覧できるようにする
  #
  # 例：
  # ・サービスの雰囲気を見てもらう
  # ・どんな学習グループがあるか確認してもらう
  #
  # ただし、グループ作成や参加申請の管理など、
  # ユーザー操作が必要な機能はログイン必須にしている
  allow_unauthenticated_access only: %i[index show]

  # show と requests では、特定のグループ情報が必要になるため、
  # アクション実行前に URL パラメータから対象グループを取得する
  #
  # before_action を使うことで、
  # 各アクション内に同じ Group.find(params[:id]) を何度も書かずに済む
  before_action :set_group, only: %i[show requests]

  # グループ作成画面(new)、作成処理(create)、参加申請一覧(requests)は、
  # ログインユーザーだけが利用できるようにする
  #
  # 未ログインのままグループ作成や申請管理ができると、
  # 「誰が作成したか」「誰が管理者か」が判断できないため
  before_action :require_authentication, only: %i[new create requests]

  # 参加申請一覧は、グループの作成者だけが確認できるようにする
  #
  # 他のユーザーが申請一覧を見られると、
  # 申請者情報が漏れる可能性があるため、権限チェックを行う
  before_action :ensure_owner!, only: %i[requests]

  # =========================
  # グループ一覧
  # =========================

  def index
    # 検索フォームから送られてきたキーワードを取得する
    # View側で検索欄に入力値を残すためにも使用できる
    @keyword = params[:keyword]

    # グループ一覧を取得する
    #
    # includes(:owner, :members)
    # → グループの作成者(owner)と参加メンバー(members)を事前に読み込む
    # → Viewで owner や members を表示するときの N+1 問題を防ぐため
    #
    # search_by_keyword(@keyword)
    # → モデル側に定義した検索処理を呼び出す
    # → Controllerに検索ロジックを直接書きすぎないようにしている
    #
    # order(created_at: :desc)
    # → 新しく作成されたグループから順に表示する
    #
    # page(params[:page]).per(10)
    # → kaminari によるページネーション
    # → 1ページあたり10件ずつ表示する
    @groups = Group.includes(:owner, :members)
                   .search_by_keyword(@keyword)
                   .order(created_at: :desc)
                   .page(params[:page]).per(10)

    # =========================
    # プロフィール画像のプリロード
    # =========================

    # グループ作成者のユーザー情報を取得する
    owners = @groups.map(&:owner).compact

    # 各グループに参加しているメンバーをまとめて取得する
    members = @groups.flat_map(&:members)

    # owner と members のプロフィール画像を事前に読み込む
    #
    # Active Storage の画像は、
    # profile_image_attachment や blob を参照すると追加SQLが発生しやすい
    #
    # そのため、一覧画面で複数ユーザーのプロフィール画像を表示する場合、
    # 事前に preload して N+1 問題を防いでいる
    #
    # (owners + members).any? をつけることで、
    # 対象ユーザーがいない場合に不要なプリロード処理を実行しないようにしている
    ActiveRecord::Associations::Preloader.new(
      records: owners + members,
      associations: { profile_image_attachment: :blob }
    ).call if (owners + members).any?
  end

  # =========================
  # グループ詳細
  # =========================

  def show
    # グループに紐づくメッセージ一覧を取得する
    #
    # includes(:user)
    # → 各メッセージの投稿者情報を事前に読み込む
    # → Viewで message.user を表示するときの N+1 問題を防ぐ
    #
    # order(created_at: :asc)
    # → チャットの流れが自然になるように、古いメッセージから順に表示する
    @group_messages = @group.group_messages
                            .includes(:user)
                            .order(created_at: :asc)

    # グループ詳細画面に表示する新規メッセージ投稿フォーム用の空インスタンス
    #
    # form_with model: で使うために用意している
    @group_message = GroupMessage.new
  end

  # =========================
  # グループ作成画面
  # =========================

  def new
    # グループ作成フォーム用の空インスタンスを作成する
    #
    # Viewの form_with model: @group で使用する
    @group = Group.new
  end

  # =========================
  # グループ作成処理
  # =========================

  def create
    # フォームから送信された値をもとに、新しいグループを作成する
    #
    # group_params を使うことで、
    # 許可した項目だけを受け取るようにしている
    @group = Group.new(group_params)

    # グループ作成者をログイン中ユーザーに設定する
    #
    # owner はフォームから送らせるのではなく、
    # current_user を使ってサーバー側で設定する
    #
    # これにより、他人を作成者にする不正なリクエストを防げる
    @group.owner = current_user

    # グループ作成と作成者のメンバー登録は、
    # 必ずセットで成功してほしい処理
    #
    # そのため transaction を使い、
    # どちらか一方でも失敗した場合は全体をロールバックする
    ActiveRecord::Base.transaction do
      # グループを保存する
      #
      # save! は保存に失敗すると例外を発生させる
      # transaction 内で例外が発生するとロールバックされる
      @group.save!

      # グループ作成者自身を、作成したグループのメンバーとして登録する
      #
      # これにより、作成者もグループ参加者として扱える
      GroupMembership.create!(group: @group, user: current_user)
    end

    # 作成に成功した場合は、作成したグループの詳細画面へ遷移する
    redirect_to group_path(@group), notice: t("flash.notice.group_created")

  # save! や create! がバリデーションエラーなどで失敗した場合、
  # ActiveRecord::RecordInvalid が発生する
  rescue ActiveRecord::RecordInvalid
    # 入力内容に問題がある場合は、グループ作成画面を再表示する
    #
    # render を使うことで、@group のエラー情報を保持したまま画面表示できる
    #
    # status: :unprocessable_entity は、
    # バリデーションエラーで処理できなかったことを表すHTTPステータス
    render :new, status: :unprocessable_entity
  end

  # =========================
  # 参加申請一覧
  # =========================

  def requests
    # グループに対する参加申請のうち、
    # pending、つまり「申請中」のものだけを取得する
    #
    # この画面はグループ作成者が、
    # 参加申請を承認・拒否するために確認する画面
    @requests = @group.group_join_requests
                      .pending
                      .includes(:user)
                      .order(created_at: :asc)

    # includes(:user)
    # → 申請者のユーザー情報を事前に読み込む
    # → Viewで request.user を表示するときの N+1 問題を防ぐ
    #
    # order(created_at: :asc)
    # → 古い申請から順に表示し、申請順に確認できるようにしている
  end

  private

  # =========================
  # 共通処理
  # =========================

  def set_group
    # URLの :id を使って、対象のグループを取得する
    #
    # 例：
    # /groups/1 の場合、params[:id] は 1 になる
    #
    # show や requests では特定のグループ情報が必要なので、
    # before_action で事前に取得している
    @group = Group.find(params[:id])
  end

  def ensure_owner!
    # 現在ログインしているユーザーが、
    # このグループの作成者かどうかを確認する
    #
    # owned_by? は Group モデル側に定義した判定メソッド
    # Controller側では「作成者かどうか」という意図が分かりやすくなる
    return if @group.owned_by?(current_user)

    # 作成者ではないユーザーが申請管理画面にアクセスしようとした場合、
    # グループ一覧画面へ戻す
    #
    # これにより、権限のないユーザーが参加申請情報を閲覧することを防ぐ
    redirect_to groups_path, alert: t("flash.alert.unauthorized")
  end

  def group_params
    # Strong Parameters
    #
    # フォームから送られてきた params のうち、
    # グループ作成・更新に必要な項目だけを許可する
    #
    # これにより、owner_id など本来ユーザーが変更してはいけない値を
    # 不正に送信されても保存されないようにしている
    params.require(:group).permit(
      :name,
      :description,
      :rule,
      :study_theme,
      :max_members
    )
  end
end
