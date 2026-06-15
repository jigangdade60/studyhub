# DMメッセージを管理するモデル
# dm_messagesテーブルに対応している
#
# このモデルでは主に以下を担当している
# - DMルームとの紐づけ
# - 送信ユーザーとの紐づけ
# - メッセージ本文のバリデーション
# - 送信者がそのDMルームの参加者かどうかのチェック
# - メッセージ送信後の通知作成
class DmMessage < ApplicationRecord
  # 通知作成処理を共通化したモジュールを読み込む
  #
  # create_notification! メソッドを使えるようにしている
  # いいね・コメント・DMなど、通知を作る処理を共通化する目的
  include Notifiable

  # ----------------------------------------
  # アソシエーション
  # ----------------------------------------

  # DMメッセージは、必ず1つのDMルームに紐づく
  #
  # 例：
  # あるDMルームの中に、複数のメッセージが存在する
  #
  # dm_messages テーブルには dm_room_id がある想定
  belongs_to :dm_room

  # DMメッセージは、必ず1人の送信ユーザーに紐づく
  #
  # 例：
  # 「このメッセージを送ったのは誰か」を表す
  #
  # dm_messages テーブルには user_id がある想定
  belongs_to :user

  # このDMメッセージに紐づく通知を管理する
  #
  # as: :notifiable によって、Notificationモデル側の
  # notifiable_type / notifiable_id を使ったポリモーフィック関連になる
  #
  # つまり、Notificationは
  # - Comment
  # - Like
  # - DmMessage
  # など、複数種類の通知対象に対応できる
  #
  # dependent: :destroy により、
  # DMメッセージが削除されたら、そのメッセージに紐づく通知も削除される
  has_many :notifications, as: :notifiable, dependent: :destroy

  # ----------------------------------------
  # バリデーション
  # ----------------------------------------

  # contentはメッセージ本文
  #
  # presence: true により、空のメッセージは送信できない
  #
  # length: { maximum: 500 } により、
  # 500文字を超える長文メッセージは保存できない
  #
  # 入力値をモデル側で制限することで、
  # ViewやControllerだけに依存せず、データの整合性を守っている
  validates :content, presence: true, length: { maximum: 500 }

  # 独自バリデーション
  #
  # メッセージ送信者が、そのDMルームの参加者であることを確認する
  #
  # 例えば、URLやリクエストを直接操作して、
  # 関係ないDMルームにメッセージを送ろうとする不正操作を防ぐ
  validate :sender_must_belong_to_room

  # ----------------------------------------
  # コールバック
  # ----------------------------------------

  # メッセージ作成がDBにコミットされた後に通知を作成する
  #
  # after_create_commit を使う理由は、
  # メッセージの保存が確定してから通知処理を実行したいため
  #
  # after_create だと、DB保存がロールバックされる可能性がある段階で
  # 通知処理が走ってしまう場合がある
  #
  # そのため、通知やメール送信などの外部処理は
  # after_create_commit を使う方が安全
  after_create_commit :notify_recipient

  private

  # ----------------------------------------
  # 送信者チェック
  # ----------------------------------------

  # 送信者がDMルームの参加者かどうかを確認するメソッド
  #
  # このメソッドは validate から呼ばれる
  #
  # 目的：
  # DMルームに参加していないユーザーが、
  # 不正にメッセージを送信することを防ぐ
  def sender_must_belong_to_room
    # dm_room または user が存在しない場合はここで処理を抜ける
    #
    # belongs_to のバリデーションや他のチェックに任せるため、
    # このメソッドでは参加者チェックだけを担当する
    return if dm_room.blank? || user.blank?

    # dm_room.includes_user?(user) で、
    # このユーザーがDMルームの参加者かどうかを確認している
    #
    # true の場合は正しい参加者なので、エラーを追加せず処理を抜ける
    return if dm_room.includes_user?(user)

    # ここまで来た場合、
    # user はこのDMルームの参加者ではない
    #
    # errors.add により、バリデーションエラーを追加する
    # これにより、このDmMessageは保存されない
    errors.add(:user, "はこのDMルームの参加者ではありません")
  end

  # ----------------------------------------
  # 通知作成
  # ----------------------------------------

  # DMメッセージ送信後に、相手ユーザーへ通知を送るメソッド
  #
  # このメソッドは after_create_commit から呼ばれる
  def notify_recipient
    # DMルームには user1 と user2 の2人がいる想定
    #
    # 送信者が user1 なら、通知の受信者は user2
    # 送信者が user2 なら、通知の受信者は user1
    #
    # つまり、「自分ではない方の相手」を recipient にしている
    recipient =
      if dm_room.user1 == user
        dm_room.user2
      else
        dm_room.user1
      end

    # Notifiable モジュールで定義した create_notification! を呼び出す
    #
    # recipient: 通知を受け取るユーザー
    # actor: 通知を発生させたユーザー、つまりメッセージ送信者
    # action: 通知の種類。ここではDMメッセージなので :message
    # notifiable: 通知対象。ここでは作成されたDMメッセージ自身
    #
    # これにより、
    # 「〇〇さんからメッセージが届きました」
    # のような通知を作成できる
    create_notification!(
      recipient: recipient,
      actor: user,
      action: :message,
      notifiable: self
    )
  end
end
