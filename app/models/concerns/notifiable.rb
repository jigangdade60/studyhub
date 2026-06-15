# 通知作成に関する共通処理をまとめたモジュール
# Concernとして定義することで、複数のControllerやModelから使い回せる
module Notifiable
  extend ActiveSupport::Concern

  private

  # 通知を作成するための共通メソッド
  #
  # recipient: 通知を受け取るユーザー
  # actor: 通知を発生させたユーザー
  # action: 通知の種類
  #         例: :like, :comment, :follow, :dm など
  # notifiable: 通知の対象となるオブジェクト
  #             例: Post, Comment, DmMessage など
  def create_notification!(recipient:, actor:, action:, notifiable:)
    # 通知を受け取るユーザー、または通知を発生させたユーザーが存在しない場合は処理を終了する
    # nilのまま通知を作成しようとするとエラーになる可能性があるため、事前にチェックしている
    return if recipient.blank? || actor.blank?

    # 自分自身の操作に対しては通知を作成しない
    # 例: 自分の投稿に自分でいいねした場合、自分に通知を送る必要はない
    return if recipient == actor

    # 通知作成処理を非同期ジョブに渡す
    # perform_laterを使うことで、通知作成をバックグラウンドで実行できる
    #
    # 例えば、いいねやコメントの処理中に通知作成まで同期的に行うと、
    # 画面の反応が遅くなる可能性がある
    # そのため、ユーザー操作へのレスポンスを優先し、
    # 通知作成は後から実行する設計にしている
    NotificationJob.perform_later(
      # 通知を受け取るユーザーのID
      recipient.id,

      # 通知を発生させたユーザーのID
      actor.id,

      # 通知の種類
      # Symbolで渡された場合でも、文字列として扱えるように変換している
      action.to_s,

      # 通知対象のクラス名
      # 例: Post, Comment, DmMessage など
      # ポリモーフィックな通知対象を扱うために、クラス名を渡している
      notifiable.class.name,

      # 通知対象のID
      # クラス名とIDを渡すことで、ジョブ側で対象レコードを特定できる
      notifiable.id
    )
  end
end
