class Public::RelationshipsController < ApplicationController
  # =========================
  # フォロー機能のコントローラ
  # =========================
  # このコントローラでは、
  # ・ユーザーをフォローする処理
  # ・フォローを解除する処理
  # を管理している
  #
  # Relationshipモデルは、
  # 「誰が誰をフォローしているか」を表す中間テーブルの役割を持つ

  # フォロー作成時は、まずフォロー対象のユーザーを取得する
  # createアクションでは params[:followed_id] を使って対象ユーザーを探すため、
  # 事前に @user に代入しておく
  before_action :set_user, only: :create

  # フォロー解除時は、削除対象のRelationshipレコードを取得する
  # destroyアクションでは params[:id] から対象のフォロー関係を探す
  before_action :set_relationship, only: :destroy

  def create
    # =========================
    # フォロー作成処理
    # =========================

    # current_user はログイン中のユーザーを表す
    # @user はフォローされる対象のユーザーを表す
    #
    # 以下の2つの場合はフォローを作成しない
    # 1. 自分自身をフォローしようとしている場合
    # 2. すでにフォロー済みの場合
    #
    # これにより、
    # 不正なフォローや重複フォローを防いでいる
    unless current_user == @user || current_user.following?(@user)

      # Userモデルに定義している follow メソッドを呼び出し、
      # ログイン中ユーザーが対象ユーザーをフォローする
      #
      # 実際には Relationship レコードが作成される
      # follower_id: current_user.id
      # followed_id: @user.id
      current_user.follow(@user)

      # フォロー通知を作成するために、
      # 今作成された Relationship レコードを取得する
      #
      # 通知では「どのフォロー関係によって発生した通知か」を
      # notifiable として紐づけるため、Relationshipのidが必要になる
      relationship = Relationship.find_by(
        follower_id: current_user.id,
        followed_id: @user.id
      )

      # Relationship が正常に作成されている場合のみ通知処理を実行する
      #
      # present? を使うことで、
      # nil の場合に通知処理が実行されないようにしている
      if relationship.present?

        # NotificationJob を使って、フォロー通知を非同期で作成する
        #
        # perform_later は「今すぐDBに通知を作る」のではなく、
        # バックグラウンドジョブとして後で実行するためのメソッド
        #
        # 通知作成を非同期にすることで、
        # フォロー処理の画面遷移を遅くしないようにしている
        NotificationJob.perform_later(
          @user.id,                 # recipient_id: 通知を受け取るユーザー
          current_user.id,          # actor_id: 通知を発生させたユーザー
          :followed,                # action: 通知の種類
          relationship.class.name,  # notifiable_type: 通知対象のモデル名
          relationship.id           # notifiable_id: 通知対象レコードのID
        )
      end
    end

    # フォロー処理後は、直前にいたページへ戻る
    #
    # redirect_back は「前のページに戻る」ためのメソッド
    # fallback_location は、戻り先が取得できなかった場合の遷移先
    #
    # ここでは、戻り先がない場合はフォロー対象ユーザーの詳細ページへ遷移する
    redirect_back fallback_location: user_path(@user), notice: t("flash.notice.follow")
  end

  def destroy
    # =========================
    # フォロー解除処理
    # =========================

    # 削除する Relationship から、
    # フォローされていたユーザーを取得しておく
    #
    # destroy 後に @relationship を使えなくなる可能性があるため、
    # 先に user 変数へ退避している
    user = @relationship.followed

    # 自分が作成したフォロー関係だけ削除できるようにする
    #
    # 例えば、他人のフォロー関係のIDをURLに直接入力された場合でも、
    # @relationship.follower が current_user でなければ削除しない
    #
    # これにより、不正なフォロー解除を防いでいる
    @relationship.destroy if @relationship.follower == current_user

    # フォロー解除後は、直前にいたページへ戻る
    #
    # 戻り先が取得できない場合は、
    # フォロー解除されたユーザーの詳細ページへ遷移する
    redirect_back fallback_location: user_path(user), notice: t("flash.notice.unfollow")
  end

  private

  # =========================
  # privateメソッド
  # =========================
  # private以下のメソッドは、
  # コントローラ内部だけで使用する補助的な処理
  #
  # 外部から直接呼び出す必要がないため private にしている

  def set_user
    # フォロー対象のユーザーを取得する
    #
    # params[:followed_id] は、
    # フォローボタンなどから送られてくる「フォローされる側のユーザーID」
    #
    # 例：
    # current_user が user_id: 1
    # @user が user_id: 3 の場合、
    # 「1番のユーザーが3番のユーザーをフォローする」という意味になる
    @user = User.find(params[:followed_id])
  end

  def set_relationship
    # フォロー解除対象のRelationshipレコードを取得する
    #
    # params[:id] には Relationship のIDが入る
    #
    # Relationshipは、
    # follower_id と followed_id を持っており、
    # 「誰が誰をフォローしているか」を表す
    @relationship = Relationship.find(params[:id])
  end
end
