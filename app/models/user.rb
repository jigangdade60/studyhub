class User < ApplicationRecord
  # パスワードをハッシュ化して安全に管理する（bcrypt）
  has_secure_password

  # プロフィール画像をActive Storageで管理する
  has_one_attached :profile_image

  # セッション（ログイン情報）はユーザー削除時に一緒に削除する
  has_many :sessions, dependent: :destroy

  # 投稿・コメント・いいねはユーザーに紐づく基本機能
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  
  # ユーザーがいいねした投稿を中間テーブル経由で取得できるようにする
  has_many :liked_posts, through: :likes, source: :post

  # =========================
  # フォロー機能（自己結合）
  # =========================

  # フォローしている側（自分 → 他人）
  has_many :active_relationships,
           class_name: "Relationship",
           foreign_key: "follower_id",
           dependent: :destroy

  # フォローしているユーザー一覧
  has_many :following,
           through: :active_relationships,
           source: :followed

  # フォローされている側（他人 → 自分）
  has_many :passive_relationships,
           class_name: "Relationship",
           foreign_key: "followed_id",
           dependent: :destroy

  # フォロワー一覧
  has_many :followers,
           through: :passive_relationships,
           source: :follower

  # =========================
  # グループ機能（もくもく会）
  # =========================

  # 自分が作成したグループ
  has_many :owned_groups,
           class_name: "Group",
           foreign_key: :owner_id,
           dependent: :destroy

  # グループ参加管理
  has_many :group_memberships, dependent: :destroy
  has_many :joined_groups, through: :group_memberships, source: :group

  has_many :group_join_requests, dependent: :destroy
  has_many :group_messages, dependent: :destroy

  # =========================
  # DM機能
  # =========================

  # 送信したDM
  has_many :sent_dm_messages,
           class_name: "DmMessage",
           dependent: :destroy,
           foreign_key: :user_id

  # DMルーム（2ユーザー構造）
  has_many :dm_rooms_as_user1,
           class_name: "DmRoom",
           foreign_key: :user1_id,
           dependent: :destroy

  has_many :dm_rooms_as_user2,
           class_name: "DmRoom",
           foreign_key: :user2_id,
           dependent: :destroy

  # =========================
  # 通知機能
  # =========================

  # 自分に届いた通知
  has_many :received_notifications,
           class_name: "Notification",
           foreign_key: :recipient_id,
           dependent: :destroy

  # 自分が送った通知（いいね・フォローなど）
  has_many :sent_notifications,
           class_name: "Notification",
           foreign_key: :actor_id,
           dependent: :destroy

  # =========================
  # バリデーション
  # =========================

  # ユーザー名は必須かつ20文字以内（UI崩れ防止）
  validates :name, presence: true, length: { maximum: 20 }

  # メールアドレスは必須かつ一意（ログインIDとして使用）
  validates :email_address, presence: true, uniqueness: true

  # メールアドレスの表記ゆれ防止（空白削除 + 小文字化）
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # =========================
  # スコープ（検索・公開制御）
  # =========================

  # 名前検索（部分一致）
  scope :search_by_name, ->(keyword) {
    return all if keyword.blank?
    where("name LIKE ?", "%#{keyword}%")
  }

  # 公開ユーザーのみ取得（非公開ユーザーは除外）
  scope :public_profiles, -> { where(is_public: true) }

  # =========================
  # フォロー関連メソッド
  # =========================

  # ユーザーをフォローする
  def follow(user)
    active_relationships.create(followed_id: user.id)
  end

  # フォロー解除
  def unfollow(user)
    active_relationships.find_by(followed_id: user.id)&.destroy
  end

  # フォローしているか判定
  def following?(user)
    following.include?(user)
  end

  # 相互フォロー判定（DM解放などに使用）
  def mutual_follow_with?(user)
    following?(user) && user.following?(self)
  end

  # =========================
  # 公開範囲制御
  # =========================

  # 自分のプロフィールが公開かどうか
  def public_profile?
    is_public
  end

  # 閲覧可能かどうか（公開 or 自分自身）
  def visible_to?(viewer)
    is_public || self == viewer
  end
end