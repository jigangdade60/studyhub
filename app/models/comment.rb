# Commentモデル
# ユーザーが投稿に対して書き込む「コメント」を管理するモデル
class Comment < ApplicationRecord
  # Notifiableモジュールを読み込む
  # 通知作成処理を共通化しているため、
  # コメント作成時の通知処理でも同じメソッドを使えるようにしている
  include Notifiable

  # コメントは、必ず1人のユーザーに紐づく
  # つまり「誰がコメントしたか」を表す関連付け
  #
  # commentsテーブルには user_id があり、
  # その user_id を使って Userモデルと関連している
  belongs_to :user

  # コメントは、必ず1つの投稿に紐づく
  # つまり「どの投稿に対するコメントか」を表す関連付け
  #
  # commentsテーブルには post_id があり、
  # その post_id を使って Postモデルと関連している
  #
  # counter_cache: true を指定することで、
  # コメントが作成・削除されたときに、
  # postsテーブルの comments_count カラムが自動で増減する
  #
  # これにより、投稿ごとのコメント数を表示するときに
  # comments.count のように毎回集計しなくてよくなり、
  # パフォーマンス改善につながる
  belongs_to :post, counter_cache: true

  # コメントに紐づく通知を管理する
  #
  # as: :notifiable はポリモーフィック関連を表している
  # これにより、Notificationモデルは
  # コメントだけでなく、いいね・DMなど複数の通知対象を扱える
  #
  # dependent: :destroy により、
  # コメントが削除されたとき、そのコメントに紐づく通知も一緒に削除される
  #
  # 例：
  # コメントを削除したのに通知だけ残る、という不整合を防ぐ
  has_many :notifications, as: :notifiable, dependent: :destroy

  # コメント本文のバリデーション
  #
  # presence: true により、空のコメントは保存できない
  # length: { maximum: 300 } により、300文字を超えるコメントは保存できない
  #
  # これにより、意味のない空投稿や長すぎるコメントを防ぎ、
  # アプリとして扱いやすいデータだけを保存できる
  validates :body, presence: true, length: { maximum: 300 }

  # コメントがDBに保存されたあとに通知処理を実行する
  #
  # after_create_commit は、
  # コメント作成処理が完全に成功してDBに反映された後に呼ばれる
  #
  # after_create ではなく after_create_commit を使うことで、
  # DB保存が確定してから通知ジョブを実行できるため、
  # 通知だけ作られてコメントが存在しない、という状態を防ぎやすい
  after_create_commit :notify_post_owner

  private

  # コメント作成後に、投稿者へ通知を送るためのメソッド
  #
  # 例：
  # Aさんの投稿にBさんがコメントした場合、
  # Aさんに「Bさんがコメントしました」という通知を送る
  def notify_post_owner
    # 自分自身の投稿に自分でコメントした場合は通知しない
    #
    # 理由：
    # 自分の行動を自分に通知しても意味が薄く、
    # 通知欄が不要な通知で増えてしまうため
    return if post.user == user

    # Notifiableモジュールで定義している create_notification! メソッドを呼び出す
    #
    # recipient: 通知を受け取る人
    # 今回はコメントされた投稿の投稿者
    #
    # actor: 通知のきっかけを作った人
    # 今回はコメントを書いたユーザー
    #
    # action: 通知の種類
    # 今回は「コメントされた」という意味で :commented を指定
    #
    # notifiable: 通知の対象
    # 今回は作成されたコメント自身
    create_notification!(
      recipient: post.user,
      actor: user,
      action: :commented,
      notifiable: self
    )
  end
end