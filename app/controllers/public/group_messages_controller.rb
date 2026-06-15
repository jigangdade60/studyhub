class Public::GroupMessagesController < ApplicationController
  # =========================
  # 認証・事前処理
  # =========================

  # グループチャット機能は、ログインしているユーザーだけが利用できる
  # 未ログインユーザーがメッセージ投稿できないようにするための制御
  before_action :require_authentication

  # createアクションを実行する前に、
  # URLパラメータのgroup_idから対象のグループを取得する
  #
  # グループメッセージは「どのグループに投稿されたか」が必要なので、
  # 先に@groupを取得しておく
  before_action :set_group

  # グループチャットは、そのグループに参加しているユーザーだけが利用できる
  #
  # 参加していないユーザーがURLを直接入力して
  # メッセージを投稿することを防ぐために、
  # 投稿前にメンバー判定を行う
  before_action :ensure_member!

  def create
    # =========================
    # グループメッセージ作成処理
    # =========================

    # 対象グループに紐づくメッセージを新しく作成する
    #
    # @group.group_messages.new と書くことで、
    # group_id が自動的にセットされる
    #
    # つまり、
    # GroupMessage.new(group_id: @group.id, ...)
    # と書くよりも、関連を使って安全に作成できる
    @group_message = @group.group_messages.new(group_message_params)

    # メッセージの投稿者は、必ずログイン中のユーザーに固定する
    #
    # フォームからuser_idを受け取ってしまうと、
    # 悪意のあるユーザーが他人のIDを送信して
    # なりすまし投稿できてしまう可能性がある
    #
    # そのため、user_idはparamsから受け取らず、
    # サーバー側でcurrent_userをセットする
    @group_message.user = current_user

    # メッセージの保存を実行する
    if @group_message.save
      # 保存に成功した場合は、グループ詳細画面へリダイレクトする
      #
      # redirect_toを使うことで、投稿後に再読み込みしても
      # 同じメッセージが二重投稿されにくくなる
      redirect_to group_path(@group), notice: t("flash.notice.message_sent")
    else
      # 保存に失敗した場合も、グループ詳細画面へ戻す
      #
      # 例：
      # ・メッセージ本文が空
      # ・文字数制限を超えている
      #
      # モデル側のバリデーションエラーをfull_messagesで取得し、
      # 画面に表示できるようにalertへ渡している
      redirect_to group_path(@group), alert: @group_message.errors.full_messages.join(", ")
    end
  end

  private

  # =========================
  # 対象グループ取得
  # =========================

  def set_group
    # ネストされたルーティングのgroup_idから、
    # メッセージ投稿先のグループを取得する
    #
    # 例：
    # POST /groups/1/group_messages
    #
    # この場合、params[:group_id]には「1」が入る
    @group = Group.find(params[:group_id])
  end

  # =========================
  # グループメンバー確認
  # =========================

  def ensure_member!
    # ログイン中ユーザーが対象グループのメンバーであれば、
    # そのまま処理を続行する
    #
    # joined_by? はGroupモデル側に定義したメソッドで、
    # 「このユーザーがグループに参加しているか」を判定する
    return if @group.joined_by?(current_user)

    # メンバーではない場合は、グループ詳細画面へ戻す
    #
    # これにより、未参加ユーザーがURLを直接叩いて
    # グループチャットに投稿することを防げる
    redirect_to group_path(@group), alert: t("flash.alert.cannot_enter_group_chat")
  end

  # =========================
  # ストロングパラメータ
  # =========================

  def group_message_params
    # フォームから送られてきた値のうち、
    # メッセージ本文であるcontentだけを許可する
    #
    # user_idやgroup_idは許可しない
    #
    # 理由：
    # ・user_idはcurrent_userからサーバー側でセットする
    # ・group_idはURLのgroup_idから取得した@groupに紐づける
    #
    # これにより、ユーザーが不正にuser_idやgroup_idを送信して
    # 他人になりすましたり、別グループへ投稿したりすることを防ぐ
    params.require(:group_message).permit(:content)
  end
end
