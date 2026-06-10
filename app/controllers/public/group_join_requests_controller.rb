class Public::GroupJoinRequestsController < ApplicationController
  # =========================
  # グループ参加申請コントローラー
  # =========================
  #
  # このコントローラーでは、グループへの参加申請に関する処理を担当する。
  #
  # 主な役割は以下の3つ。
  # 1. ユーザーがグループに参加申請する
  # 2. グループ作成者が参加申請を承認する
  # 3. グループ作成者が参加申請を拒否する
  #
  # 参加申請は誰でも操作できると不正利用につながるため、
  # ログイン確認やグループ作成者確認を before_action で行っている。

  # 参加申請・承認・拒否はログインユーザーのみ操作できるようにする
  #
  # 未ログインユーザーが参加申請を送ったり、
  # 承認・拒否操作を行ったりできないようにするための認証チェック。
  before_action :require_authentication

  # 参加申請作成時は、申請先となるグループを取得する
  #
  # create アクションでは、
  # 「どのグループに参加申請するのか」を特定する必要があるため、
  # URLの group_id を使って @group を取得する。
  before_action :set_group, only: %i[create]

  # 承認・拒否時は、対象の参加申請レコードを取得する
  #
  # approve / reject アクションでは、
  # 「どの参加申請を承認または拒否するのか」を特定する必要があるため、
  # params[:id] を使って @group_join_request を取得する。
  before_action :set_group_join_request, only: %i[approve reject]

  # 承認・拒否はグループ作成者だけが実行できるようにする
  #
  # 参加申請の承認・拒否を誰でもできてしまうと問題があるため、
  # そのグループの作成者だけが操作できるように制限している。
  before_action :ensure_owner!, only: %i[approve reject]

  def create
    # =========================
    # 参加申請作成処理
    # =========================
    #
    # ログイン中ユーザーが、対象グループに参加申請を送る。
    #
    # @group.group_join_requests.new とすることで、
    # 作成する参加申請を対象グループに紐づけている。
    #
    # user: current_user を指定することで、
    # 申請者をログイン中ユーザーに固定している。
    #
    # これにより、フォームやパラメータから別ユーザーIDを送られても、
    # 他人になりすまして申請することを防げる。
    @group_join_request = @group.group_join_requests.new(user: current_user)

    if @group_join_request.save
      # 保存に成功した場合は、グループ詳細画面へ戻す
      #
      # notice には成功メッセージを表示する。
      redirect_to group_path(@group), notice: t("flash.notice.request_sent")
    else
      # 保存に失敗した場合も、グループ詳細画面へ戻す
      #
      # 失敗する例:
      # - すでに同じグループへ申請済み
      # - すでにグループメンバーである
      # - グループの定員に達している
      #
      # モデル側のバリデーションエラーを full_messages で取り出し、
      # 画面に alert として表示している。
      redirect_to group_path(@group), alert: @group_join_request.errors.full_messages.join(", ")
    end
  end

  def approve
    # =========================
    # 参加申請承認処理
    # =========================
    #
    # グループ作成者が、参加申請を承認する処理。
    #
    # 承認する前に、グループの定員を確認している。
    # 定員に達している状態で承認してしまうと、
    # 最大人数を超えてメンバーが追加される可能性があるため。
    if @group_join_request.group.full?
      redirect_to requests_group_path(@group_join_request.group), alert: t("flash.alert.members_full")
      return
    end

    # 参加申請の承認と、グループメンバーへの追加は
    # 必ずセットで成功してほしい処理。
    #
    # 例えば、
    # - 申請状態だけ approved になった
    # - でも GroupMembership の作成に失敗した
    #
    # という状態になると、データの整合性が崩れる。
    #
    # そのため transaction を使い、
    # どちらかが失敗した場合は両方とも取り消されるようにしている。
    ActiveRecord::Base.transaction do
      # 参加申請の status を approved に変更する
      #
      # enum を使っているため、
      # approved! と書くことで status を approved に更新できる。
      @group_join_request.approved!

      # 承認されたユーザーをグループメンバーとして追加する
      #
      # find_or_create_by! を使うことで、
      # すでに同じユーザーがメンバーになっている場合は既存レコードを取得し、
      # 存在しない場合だけ新しく作成する。
      #
      # ! 付きメソッドなので、作成に失敗した場合は例外が発生し、
      # transaction により approved! の更新も取り消される。
      GroupMembership.find_or_create_by!(
        group: @group_join_request.group,
        user: @group_join_request.user
      )
    end

    # 承認後は、参加申請一覧画面へ戻す
    redirect_to requests_group_path(@group_join_request.group), notice: t("flash.notice.request_approved")
  end

  def reject
    # =========================
    # 参加申請拒否処理
    # =========================
    #
    # グループ作成者が、参加申請を拒否する処理。
    #
    # enum を使っているため、
    # rejected! と書くことで status を rejected に更新できる。
    @group_join_request.rejected!

    # 拒否後は、参加申請一覧画面へ戻す
    redirect_to requests_group_path(@group_join_request.group), notice: t("flash.notice.request_rejected")
  end

  private

  def set_group
    # =========================
    # 対象グループ取得
    # =========================
    #
    # create アクションでは、URLに group_id が含まれている想定。
    #
    # 例:
    # POST /groups/:group_id/group_join_requests
    #
    # その group_id を使って、参加申請先のグループを取得する。
    @group = Group.find(params[:group_id])
  end

  def set_group_join_request
    # =========================
    # 対象参加申請取得
    # =========================
    #
    # approve / reject アクションでは、
    # URLの id から対象の参加申請レコードを取得する。
    #
    # 例:
    # PATCH /group_join_requests/:id/approve
    # PATCH /group_join_requests/:id/reject
    #
    # ここで取得した @group_join_request を使って、
    # 承認・拒否処理を行う。
    @group_join_request = GroupJoinRequest.find(params[:id])
  end

  def ensure_owner!
    # =========================
    # グループ作成者チェック
    # =========================
    #
    # 参加申請の承認・拒否は、
    # そのグループを作成したユーザーだけが実行できる。
    #
    # @group_join_request.group で申請先グループを取得し、
    # owned_by?(current_user) でログイン中ユーザーが
    # そのグループの作成者かどうかを確認している。
    return if @group_join_request.group.owned_by?(current_user)

    # グループ作成者ではないユーザーが操作しようとした場合は、
    # 一覧画面へ戻してエラーメッセージを表示する。
    redirect_to groups_path, alert: t("flash.alert.unauthorized")
  end
end