class User < ApplicationRecord
  # =========================
  # 認証機能
  # =========================

  # has_secure_password は Rails の認証機能で、
  # パスワードをそのままDBに保存するのではなく、
  # bcrypt を使ってハッシュ化して保存するための仕組み。
  #
  # users テーブルに password_digest カラムが必要。
  # password / password_confirmation が使えるようになる。
  #
  # 面接では、
  # 「パスワードを平文で保存せず、安全に管理するために使っています」
  # と説明できる。
  has_secure_password

  # =========================
  # プロフィール画像
  # =========================

  # ユーザーのプロフィール画像を Active Storage で管理する。
  #
  # has_one_attached は、
  # 1人のユーザーに1枚の画像を紐づけるための設定。
  #
  # 画像ファイル自体を users テーブルに保存するのではなく、
  # Active Storage の専用テーブルを通して管理する。
  has_one_attached :profile_image

  # =========================
  # セッション管理
  # =========================

  # ユーザーは複数のセッションを持つ。
  #
  # 例：
  # - PCでログイン
  # - スマホでログイン
  #
  # のように、複数端末でログイン情報を持つ可能性があるため has_many にしている。
  #
  # dependent: :destroy により、
  # ユーザーが削除された場合、そのユーザーのセッション情報も削除する。
  # これにより、存在しないユーザーのログイン情報だけが残ることを防ぐ。
  has_many :sessions, dependent: :destroy

  # =========================
  # 投稿・コメント・いいね
  # =========================

  # 1人のユーザーは複数の投稿を作成できる。
  #
  # dependent: :destroy により、
  # ユーザー削除時に、そのユーザーの投稿も削除される。
  has_many :posts, dependent: :destroy

  # 1人のユーザーは複数のコメントを投稿できる。
  #
  # コメントはユーザーに紐づくため、
  # ユーザー削除時にはコメントも削除する設計にしている。
  has_many :comments, dependent: :destroy

  # 1人のユーザーは複数の投稿にいいねできる。
  #
  # likes は「ユーザー」と「投稿」をつなぐ中間テーブルの役割を持つ。
  has_many :likes, dependent: :destroy

  # ユーザーがいいねした投稿一覧を取得するための関連。
  #
  # likes テーブルを経由して、
  # 「このユーザーがいいねした投稿」を取得できる。
  #
  # source: :post は、
  # likes の先にある post を取得するという意味。
  #
  # 例：
  # user.liked_posts
  # => ユーザーがいいねした投稿一覧
  has_many :liked_posts, through: :likes, source: :post

  # =========================
  # フォロー機能（自己結合）
  # =========================
  #
  # フォロー機能は User と User の関係。
  #
  # 例：
  # AさんがBさんをフォローする
  #
  # このように同じ users テーブル同士を関連づけるため、
  # 自己結合という設計にしている。
  #
  # Relationship モデルでは、
  # follower_id が「フォローする側」
  # followed_id が「フォローされる側」
  # を表す。

  # 自分がフォローしている関係を表す。
  #
  # active_relationships は、
  # 「自分から相手に向かうフォロー関係」。
  #
  # class_name: "Relationship" により、
  # active_relationships という名前でも Relationship モデルを参照する。
  #
  # foreign_key: "follower_id" により、
  # relationships テーブルの follower_id が自分の user_id になる。
  has_many :active_relationships,
           class_name: "Relationship",
           foreign_key: "follower_id",
           dependent: :destroy

  # 自分がフォローしているユーザー一覧を取得する。
  #
  # active_relationships を経由して、
  # followed 側のユーザーを取得する。
  #
  # 例：
  # user.following
  # => user がフォローしているユーザー一覧
  has_many :following,
           through: :active_relationships,
           source: :followed

  # 自分がフォローされている関係を表す。
  #
  # passive_relationships は、
  # 「相手から自分に向かうフォロー関係」。
  #
  # foreign_key: "followed_id" により、
  # relationships テーブルの followed_id が自分の user_id になる。
  has_many :passive_relationships,
           class_name: "Relationship",
           foreign_key: "followed_id",
           dependent: :destroy

  # 自分をフォローしているユーザー一覧を取得する。
  #
  # passive_relationships を経由して、
  # follower 側のユーザーを取得する。
  #
  # 例：
  # user.followers
  # => user をフォローしているユーザー一覧
  has_many :followers,
           through: :passive_relationships,
           source: :follower

  # =========================
  # グループ機能（もくもく会）
  # =========================

  # 自分が作成したグループ一覧。
  #
  # Group モデルでは owner として User に紐づけているため、
  # class_name: "Group" と foreign_key: :owner_id を指定している。
  #
  # 例：
  # user.owned_groups
  # => user が作成したグループ一覧
  has_many :owned_groups,
           class_name: "Group",
           foreign_key: :owner_id,
           dependent: :destroy

  # グループ参加情報。
  #
  # group_memberships は、
  # users と groups をつなぐ中間テーブル。
  #
  # 1人のユーザーは複数のグループに参加でき、
  # 1つのグループにも複数のユーザーが参加できるため、
  # 多対多の関係になる。
  has_many :group_memberships, dependent: :destroy

  # 自分が参加しているグループ一覧を取得する。
  #
  # group_memberships を経由して group を取得する。
  #
  # 例：
  # user.joined_groups
  # => user が参加しているグループ一覧
  has_many :joined_groups, through: :group_memberships, source: :group

  # ユーザーが送ったグループ参加申請。
  #
  # 参加申請はユーザーとグループに紐づくため、
  # ユーザー側からも参照できるようにしている。
  has_many :group_join_requests, dependent: :destroy

  # ユーザーがグループ内で送信したメッセージ。
  #
  # グループメッセージは、
  # 「どのグループで」
  # 「誰が送ったか」
  # を管理する必要があるため、User に紐づけている。
  has_many :group_messages, dependent: :destroy

  # =========================
  # DM機能
  # =========================

  # 自分が送信したDMメッセージ一覧。
  #
  # DmMessage モデルの user_id が送信者を表すため、
  # foreign_key: :user_id を指定している。
  #
  # class_name: "DmMessage" により、
  # sent_dm_messages という名前でも DmMessage モデルを参照できる。
  has_many :sent_dm_messages,
           class_name: "DmMessage",
           dependent: :destroy,
           foreign_key: :user_id

  # DMルームは2人のユーザーで構成される。
  #
  # user1_id 側として参加しているDMルームを取得する。
  #
  # 例：
  # dm_room.user1_id == 自分のid
  has_many :dm_rooms_as_user1,
           class_name: "DmRoom",
           foreign_key: :user1_id,
           dependent: :destroy

  # user2_id 側として参加しているDMルームを取得する。
  #
  # 例：
  # dm_room.user2_id == 自分のid
  has_many :dm_rooms_as_user2,
           class_name: "DmRoom",
           foreign_key: :user2_id,
           dependent: :destroy

  # =========================
  # 通知機能
  # =========================

  # 自分に届いた通知。
  #
  # Notification モデルでは recipient が通知を受け取るユーザーを表す。
  #
  # foreign_key: :recipient_id により、
  # notifications テーブルの recipient_id が自分の user_id になる。
  #
  # 例：
  # user.received_notifications
  # => 自分宛ての通知一覧
  has_many :received_notifications,
           class_name: "Notification",
           foreign_key: :recipient_id,
           dependent: :destroy

  # 自分が発生させた通知。
  #
  # Notification モデルでは actor が通知を発生させたユーザーを表す。
  #
  # 例：
  # 自分が誰かの投稿にいいねした場合、
  # actor は自分、recipient は投稿者になる。
  has_many :sent_notifications,
           class_name: "Notification",
           foreign_key: :actor_id,
           dependent: :destroy

  # =========================
  # テーマ設定
  # =========================

  # ユーザーごとのテーマ設定を enum で管理する。
  #
  # light と dark の2種類を定義している。
  #
  # DB上では文字列として "light" または "dark" を保存する。
  #
  # default: "light" により、
  # 新規ユーザー作成時の初期値は light になる。
  #
  # 例：
  # user.light?
  # user.dark?
  # user.dark!
  #
  # のようなメソッドが使える。
  enum :theme, { light: "light", dark: "dark" }, default: "light"

  # =========================
  # バリデーション
  # =========================

  # ユーザー名は必須。
  #
  # presence: true により、
  # 空の名前では登録できないようにしている。
  #
  # length: { maximum: 20 } により、
  # 20文字以内に制限している。
  #
  # これは、長すぎる名前によるUI崩れを防ぐ目的もある。
  validates :name, presence: true, length: { maximum: 20 }

  # メールアドレスは必須かつ一意。
  #
  # email_address はログインIDとして使うため、
  # 空では登録できず、同じメールアドレスで複数登録できないようにしている。
  #
  # uniqueness: true により、
  # 同じメールアドレスの重複登録を防ぐ。
  validates :email_address, presence: true, uniqueness: true

  # メールアドレスを保存する前に正規化する。
  #
  # strip で前後の空白を削除し、
  # downcase で小文字に変換している。
  #
  # 例：
  # " TEST@example.COM "
  # => "test@example.com"
  #
  # これにより、
  # 大文字小文字や空白による表記ゆれを防げる。
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # =========================
  # スコープ（検索・公開制御）
  # =========================

  # ユーザー名で検索するためのスコープ。
  #
  # keyword が空の場合は all を返し、
  # 全ユーザーを対象にする。
  #
  # keyword がある場合は、
  # name カラムにキーワードを含むユーザーを部分一致で検索する。
  #
  # LIKE を使うことで、
  # 完全一致ではなく一部一致の検索ができる。
  #
  # 例：
  # User.search_by_name("田中")
  scope :search_by_name, ->(keyword) {
    return all if keyword.blank?

    where("name LIKE ?", "%#{keyword}%")
  }

  # 公開プロフィールのユーザーだけを取得するスコープ。
  #
  # is_public が true のユーザーのみ取得する。
  #
  # 非公開ユーザーを一覧に出したくない場合などに使う。
  #
  # 例：
  # User.public_profiles
  scope :public_profiles, -> { where(is_public: true) }

  # =========================
  # フォロー関連メソッド
  # =========================

  # 指定したユーザーをフォローする。
  #
  # active_relationships は、
  # 自分がフォローする側の関連。
  #
  # followed_id に相手ユーザーの id を入れることで、
  # 「自分が相手をフォローする」という関係を作成する。
  #
  # 例：
  # current_user.follow(other_user)
  def follow(user)
    active_relationships.create(followed_id: user.id)
  end

  # 指定したユーザーのフォローを解除する。
  #
  # active_relationships から、
  # followed_id が相手ユーザーの id と一致するレコードを探す。
  #
  # &.destroy の &. は安全呼び出し演算子。
  # 対象のレコードが存在する場合だけ destroy を実行する。
  #
  # すでにフォローしていない場合でもエラーにならない。
  def unfollow(user)
    active_relationships.find_by(followed_id: user.id)&.destroy
  end

  # 指定したユーザーをフォローしているかを判定する。
  #
  # following は、自分がフォローしているユーザー一覧。
  #
  # exists? を使うことで、
  # 対象のユーザーが存在するかをDB上で効率よく確認できる。
  #
  # include? よりも、全件読み込みを避けやすいため効率がよい。
  #
  # 例：
  # current_user.following?(other_user)
  # => true または false
  def following?(user)
    following.exists?(id: user.id)
  end

  # 指定したユーザーと相互フォローかどうかを判定する。
  #
  # 自分が相手をフォローしていて、
  # 相手も自分をフォローしている場合に true になる。
  #
  # DM機能を相互フォロー限定にしたい場合などに使える。
  #
  # 例：
  # current_user.mutual_follow_with?(other_user)
  def mutual_follow_with?(user)
    following?(user) && user.following?(self)
  end

  # =========================
  # 公開範囲制御
  # =========================

  # 自分のプロフィールが公開状態かどうかを返す。
  #
  # is_public が true なら公開、
  # false なら非公開。
  #
  # メソッド名を public_profile? にすることで、
  # コントローラーやビュー側で意味がわかりやすくなる。
  def public_profile?
    is_public
  end

  # 指定した閲覧者が、このユーザーのプロフィールを見られるかを判定する。
  #
  # 条件は以下のどちらか。
  #
  # 1. プロフィールが公開されている
  # 2. 閲覧者が本人である
  #
  # これにより、
  # 非公開ユーザーでも本人だけは自分のプロフィールを見られる。
  #
  # 例：
  # user.visible_to?(current_user)
  def visible_to?(viewer)
    is_public || self == viewer
  end
end