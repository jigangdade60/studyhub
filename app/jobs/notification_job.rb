# 通知を非同期で作成するためのJobクラス
# Jobとは、時間がかかる処理や後回しにしたい処理を
# リクエスト処理とは別で実行するための仕組み
class NotificationJob < ApplicationJob
  # このJobを default キューに登録する
  # queue_as :default により、Railsの標準的なキューで処理される
  queue_as :default

  # perform は Job が実行されたときに呼ばれるメソッド
  #
  # recipient_id     : 通知を受け取るユーザーのID
  # actor_id         : 通知を発生させたユーザーのID
  # action           : 通知の種類（いいね、コメント、フォロー、DMなど）
  # notifiable_type  : 通知対象のモデル名（Post、Comment、Relationshipなど）
  # notifiable_id    : 通知対象レコードのID
  def perform(recipient_id, actor_id, action, notifiable_type, notifiable_id)
    # 通知を受け取るユーザーをIDから取得する
    # find ではなく find_by を使うことで、
    # 対象ユーザーが削除済みでも例外を出さず nil を返せる
    recipient = User.find_by(id: recipient_id)

    # 通知を発生させたユーザーをIDから取得する
    # 例：いいねした人、コメントした人、フォローした人
    actor = User.find_by(id: actor_id)

    # recipient または actor が存在しない場合は通知を作らず処理を終了する
    # 非同期処理では、Jobが実行される前にユーザーが削除される可能性があるため
    return if recipient.blank? || actor.blank?

    # 自分自身の操作では通知を作成しない
    # 例：自分の投稿に自分でいいねした場合などに通知が出ないようにする
    return if recipient == actor

    # 通知レコードを作成する
    # create! を使うことで、保存に失敗した場合は例外を発生させる
    # 非同期Jobでは失敗を検知しやすくするため create! を使っている
    Notification.create!(
      # 通知を受け取るユーザー
      recipient: recipient,

      # 通知を発生させたユーザー
      actor: actor,

      # 通知の種類を指定する
      # action は文字列やシンボルで渡される可能性があるため、
      # to_sym でシンボルに変換して enum に対応させる
      action: action.to_sym,

      # 通知対象のモデル名
      # ポリモーフィック関連の type 側にあたる
      # 例："Post", "Comment", "Relationship", "DmMessage"
      notifiable_type: notifiable_type,

      # 通知対象レコードのID
      # ポリモーフィック関連の id 側にあたる
      notifiable_id: notifiable_id
    )
  end
end
