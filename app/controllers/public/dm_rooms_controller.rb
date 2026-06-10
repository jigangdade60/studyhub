class Public::DmRoomsController < ApplicationController
  # =========================
  # DMルーム取得・アクセス制御
  # =========================

  # showアクションでは、URLのidから表示対象のDMルームを取得する
  # 例: /dm_rooms/1 にアクセスされた場合、id=1のDMルームを取得する
  before_action :set_dm_room, only: :show

  # DMルームは参加者2人だけが閲覧できるようにする
  # 第三者がURLを直接入力しても閲覧できないように制御している
  before_action :ensure_room_member, only: :show

  # =========================
  # DMルーム作成
  # =========================

  def create
    # DMを開始したい相手ユーザーを取得する
    # params[:user_id] は、プロフィール画面などから送られてくる相手ユーザーのID
    other_user = User.find(params[:user_id])

    # 自分自身とはDMを作成できないようにする
    # 例: 自分のプロフィール画面からDM開始ボタンを押された場合の不正操作対策
    if current_user == other_user
      redirect_to user_path(other_user), alert: t("flash.alert.cannot_dm_self")
      return
    end

    # 相互フォローしているユーザー同士だけDMできるようにする
    # 一方的なフォローや、全く関係のないユーザーからDMが送られるのを防ぐため
    unless current_user.mutual_follow_with?(other_user)
      redirect_to user_path(other_user), alert: t("flash.alert.dm_requires_follow")
      return
    end

    # 2人のユーザーの組み合わせに対応するDMルームを取得する
    # すでにルームがあればそのルームを使い、
    # まだ存在しなければ新しく作成する
    #
    # find_or_create_between は DmRoomモデル側に定義したクラスメソッドで、
    # user1_id / user2_id の順番をそろえることで
    # 同じ2人のDMルームが重複して作られないようにしている
    @dm_room = DmRoom.find_or_create_between(current_user, other_user)

    # 作成または取得したDMルームの詳細画面へ遷移する
    redirect_to dm_room_path(@dm_room)
  end

  # =========================
  # DMルーム詳細表示
  # =========================

  def show
    # 現在ログインしているユーザーから見たDM相手を取得する
    # 例: user1が自分ならuser2を返し、user2が自分ならuser1を返す
    @other_user = @dm_room.other_user(current_user)

    # DMルームに紐づくメッセージ一覧を取得する
    #
    # includes(:user) を使うことで、
    # メッセージごとの送信者情報をまとめて取得し、
    # N+1問題を防いでいる
    #
    # order(:created_at) により、古いメッセージから順番に表示する
    @dm_messages = @dm_room.dm_messages.includes(:user).order(:created_at)

    # メッセージ投稿フォーム用の空のDmMessageインスタンスを作成する
    # form_with model: で利用するために必要
    @dm_message = @dm_room.dm_messages.new
  end

  private

  # =========================
  # DMルーム取得処理
  # =========================

  def set_dm_room
    # URLパラメータのidから対象のDMルームを取得する
    # 存在しないidの場合はActiveRecord::RecordNotFoundが発生する
    @dm_room = DmRoom.find(params[:id])
  end

  # =========================
  # DMルーム参加者チェック
  # =========================

  def ensure_room_member
    # 現在ログインしているユーザーが、
    # このDMルームの参加者であれば閲覧を許可する
    return if @dm_room.includes_user?(current_user)

    # 参加者でない場合は、トップページへリダイレクトする
    # URLを直接入力して他人のDMを見ようとする不正アクセスを防ぐ
    redirect_to root_path, alert: t("flash.alert.cannot_enter_dm")
  end
end