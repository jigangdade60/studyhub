class Like < ApplicationRecord
  # =========================
  # 通知作成用の共通処理
  # =========================

  # Notifiableモジュールを読み込む
  # create_notification! メソッドを使えるようにして、
  # いいね通知・コメント通知・DM通知などで共通の通知作成処理を使い回す
  include Notifiable

  # =========================
  # 関連付け
  # =========================

  # いいねは、必ず「誰がいいねしたか」というユーザー情報を持つ
  # likesテーブルの user_id と usersテーブルを紐づけている
  belongs_to :user

  # いいねは、必ず「どの投稿にいいねしたか」という投稿情報を持つ
  # likesテーブルの post_id と postsテーブルを紐づけている
  #
  # counter_cache: true を付けることで、
  # いいねが作成・削除されたときに、
  # postsテーブルの likes_count カラムを自動で増減してくれる
  #
  # 毎回 likes.count で集計するとDBへの負荷が増えるため、
  # 一覧画面や並び替えで高速にいいね数を表示できるようにしている
  belongs_to :post, counter_cache: true

  # このいいねに紐づく通知を管理する
  #
  # as: :notifiable はポリモーフィック関連を表している
  # 通知対象は Like だけでなく、Comment や DmMessage などもあり得るため、
  # Notificationモデル側で notifiable_type と notifiable_id を使って
  # 「何に対する通知か」を柔軟に管理できるようにしている
  #
  # dependent: :destroy により、
  # いいねが削除された場合、そのいいねに紐づく通知も一緒に削除される
  # 不要な通知データが残らないようにするため
  has_many :notifications, as: :notifiable, dependent: :destroy

  # =========================
  # バリデーション
  # =========================

  # 同じユーザーが同じ投稿に複数回いいねできないようにする
  #
  # uniqueness: { scope: :post_id } は、
  # 「user_id単体で一意」ではなく、
  # 「user_id と post_id の組み合わせで一意」という意味
  #
  # つまり、
  # 同じユーザーが別の投稿にいいねするのはOK
  # ただし、同じユーザーが同じ投稿に2回いいねするのはNG
  validates :user_id, uniqueness: { scope: :post_id }

  # =========================
  # コールバック
  # =========================

  # いいねがDBに保存されたあとに、投稿者へ通知を送る
  #
  # after_create_commit は、
  # create処理が成功し、DBへの保存が確定したあとに実行される
  #
  # after_create ではなく after_create_commit を使うことで、
  # 保存が確定する前に通知処理が走ってしまうことを防げる
  # 特に非同期ジョブで通知を作る場合は、DB保存後に実行する方が安全
  after_create_commit :notify_post_owner

  private

  # =========================
  # 通知作成処理
  # =========================

  # 投稿者に「いいねされた」通知を作成する
  #
  # recipient: 通知を受け取る人
  # 今回は「いいねされた投稿の投稿者」
  #
  # actor: 通知を発生させた人
  # 今回は「いいねしたユーザー」
  #
  # action: 通知の種類
  # 今回は :liked として、いいね通知であることを表す
  #
  # notifiable: 通知対象
  # 今回は、このLikeインスタンス自身を渡す
  #
  # 実際の通知作成処理は Notifiable モジュールの create_notification! に任せている
  # これにより、通知処理を各モデルに重複して書かずに済む
  def notify_post_owner
    create_notification!(
      recipient: post.user,
      actor: user,
      action: :liked,
      notifiable: self
    )
  end
end
