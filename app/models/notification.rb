class Notification < ApplicationRecord
  # =========================
  # 関連付け
  # =========================

  # 通知を受け取るユーザー
  #
  # 通常の belongs_to :user ではなく、
  # recipient という名前で User モデルに紐づけている。
  #
  # 例：
  # AさんがBさんの投稿にいいねした場合、
  # recipient は「通知を受け取るBさん」になる。
  belongs_to :recipient, class_name: "User"

  # 通知を発生させたユーザー
  #
  # actor も User モデルに紐づくが、
  # 役割としては「通知を起こした人」を表している。
  #
  # 例：
  # AさんがBさんの投稿にいいねした場合、
  # actor は「いいねしたAさん」になる。
  belongs_to :actor, class_name: "User"

  # 通知対象をポリモーフィック関連で管理する
  #
  # 通知の対象は、いいね・コメント・投稿・DM・フォローなど複数ある。
  # それぞれ別々に like_id, comment_id, dm_message_id のようなカラムを持つと、
  # 通知の種類が増えるたびにテーブル設計が複雑になる。
  #
  # polymorphic: true を使うことで、
  # notifiable_type にモデル名、
  # notifiable_id に対象データのIDを保存できる。
  #
  # 例：
  # notifiable_type: "Comment"
  # notifiable_id: 5
  #
  # これにより、1つの notifications テーブルで
  # 複数種類の通知対象を共通管理できる。
  belongs_to :notifiable, polymorphic: true

  # =========================
  # enumによる通知種別管理
  # =========================

  # 通知の種類を enum で管理する
  #
  # DB上では整数で保存されるが、
  # Rails上では liked や commented のような名前で扱える。
  #
  # 例：
  # notification.liked?
  # notification.commented?
  # notification.action
  #
  # 数字だけで管理すると意味が分かりにくいため、
  # enum を使って可読性を高めている。
  enum :action, {
    liked: 0,      # いいね通知
    commented: 1, # コメント通知
    posted: 2,    # 新規投稿通知
    message: 3,   # DM通知
    followed: 4   # フォロー通知
  }

  # =========================
  # scope
  # =========================

  # 新しい通知から順番に取得するための scope
  #
  # 通知一覧画面では、基本的に最新の通知を上に表示したいため、
  # created_at の降順で並び替えている。
  #
  # 使用例：
  # current_user.received_notifications.recent
  scope :recent, -> { order(created_at: :desc) }

  # 未読通知だけを取得するための scope
  #
  # read_at が nil の場合は、まだ読まれていない通知と判断する。
  #
  # boolean の read カラムではなく read_at を使うことで、
  # 「既読かどうか」だけでなく「いつ既読にしたか」も記録できる。
  #
  # 使用例：
  # current_user.received_notifications.unread
  scope :unread, -> { where(read_at: nil) }

  # =========================
  # バリデーション
  # =========================

  # 通知の種類は必須
  #
  # action がないと、
  # 「いいね通知なのか、コメント通知なのか、DM通知なのか」が判断できない。
  #
  # そのため、通知を作成する際には必ず action を保存するようにしている。
  validates :action, presence: true

  # =========================
  # 既読判定
  # =========================

  # 通知が既読かどうかを判定するメソッド
  #
  # read_at に日時が入っていれば既読、
  # nil であれば未読と判断する。
  #
  # メソッド名を read? にすることで、
  # if notification.read?
  # のように自然な形で条件分岐できる。
  def read?
    read_at.present?
  end

  # =========================
  # 既読処理
  # =========================

  # 通知を既読にするメソッド
  #
  # 未読の場合だけ read_at に現在時刻を保存する。
  # すでに既読の場合は、既読日時を上書きしない。
  #
  # update! のように ! がついているメソッドを使うことで、
  # 保存に失敗した場合に例外を発生させられる。
  # これにより、エラーに気づきやすくなる。
  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  # =========================
  # 表示用メッセージ
  # =========================

  # 通知種別に応じて、画面に表示するメッセージを返す
  #
  # DBには action と actor を保存しておき、
  # 表示するときに人間が読める文章へ変換している。
  #
  # 例：
  # action が liked の場合
  # 「〇〇さんがあなたの投稿にいいねしました」
  #
  # このようにモデル側にまとめることで、
  # Viewに条件分岐を大量に書かずに済み、見通しがよくなる。
  def message
    case action
    when "liked"
      "#{actor.name}さんがあなたの投稿にいいねしました"
    when "commented"
      "#{actor.name}さんがあなたの投稿にコメントしました"
    when "posted"
      "#{actor.name}さんが新しく投稿しました"
    when "message"
      "#{actor.name}さんから新しいDMがあります"
    when "followed"
      "#{actor.name}さんがあなたをフォローしました"
    else
      # 想定外の action が入った場合でも、
      # 画面がエラーにならないようにデフォルト文言を返す。
      "新しい通知があります"
    end
  end

  # =========================
  # 通知クリック時の遷移先
  # =========================

  # 通知内容に応じて、クリック時の遷移先URLを返す
  #
  # 通知の種類によって遷移先が異なるため、
  # notifiable のクラスを見てURLを切り替えている。
  #
  # 例：
  # コメント通知 → コメントされた投稿詳細へ
  # いいね通知 → いいねされた投稿詳細へ
  # DM通知 → DMルームへ
  # フォロー通知 → フォローしたユーザーの詳細ページへ
  #
  # これを View 側に書くと条件分岐が複雑になるため、
  # モデル側の target_path メソッドにまとめている。
  def target_path
    case notifiable
    when Post
      # 新規投稿通知の場合は、その投稿の詳細ページへ遷移する。
      Rails.application.routes.url_helpers.post_path(notifiable)

    when Comment
      # コメント通知の場合、
      # 通知対象は Comment だが、ユーザーに見せたいのは投稿詳細画面。
      # そのため、notifiable.post でコメント元の投稿を取得している。
      Rails.application.routes.url_helpers.post_path(notifiable.post)

    when Like
      # いいね通知の場合も、
      # 通知対象は Like だが、遷移先はいいねされた投稿詳細画面。
      Rails.application.routes.url_helpers.post_path(notifiable.post)

    when DmMessage
      # DM通知の場合は、
      # 対象メッセージが所属しているDMルームへ遷移する。
      Rails.application.routes.url_helpers.dm_room_path(notifiable.dm_room)

    when Relationship
      # フォロー通知の場合は、
      # フォローしてくれたユーザーの詳細ページへ遷移する。
      #
      # actor が「フォローした人」なので、
      # user_path(actor) としている。
      Rails.application.routes.url_helpers.user_path(actor)

    else
      # 想定外の通知対象だった場合でもエラーにせず、
      # 通知一覧ページへ遷移させる。
      Rails.application.routes.url_helpers.notifications_path
    end
  end
end