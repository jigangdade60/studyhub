class Group < ApplicationRecord
  # =========================
  # 所有者（グループ作成者）
  # =========================

  # グループはユーザーが作成し、ownerとして紐づける
  belongs_to :owner, class_name: "User"

  # =========================
  # メンバー管理
  # =========================

  # グループ参加は中間テーブルで管理（多対多関係）
  has_many :group_memberships, dependent: :destroy
  has_many :members, through: :group_memberships, source: :user

  # 参加申請・グループ内メッセージ
  has_many :group_join_requests, dependent: :destroy
  has_many :group_messages, dependent: :destroy

  # =========================
  # バリデーション
  # =========================

  # グループ名・説明・学習テーマは必須
  validates :name, presence: true, length: { maximum: 50 }
  validates :description, presence: true, length: { maximum: 500 }
  validates :rule, length: { maximum: 500 }
  validates :study_theme, presence: true, length: { maximum: 100 }

  # 最大人数は2人以上100人以下の整数で制限
  validates :max_members,
            presence: true,
            numericality: { only_integer: true, greater_than: 1, less_than_or_equal_to: 100 }

  # =========================
  # 検索機能
  # =========================

  # グループ名または学習テーマで部分一致検索
  scope :search_by_keyword, ->(keyword) {
    return all if keyword.blank?

    where("name LIKE :q OR study_theme LIKE :q", q: "%#{keyword}%")
  }

  # =========================
  # 権限・状態判定メソッド
  # =========================

  # 指定ユーザーがグループの作成者かどうか
  def owned_by?(user)
    owner == user
  end

  # 指定ユーザーがグループに参加しているか
  def joined_by?(user)
    return false if user.blank?
    members.exists?(user.id)
  end

  # 指定ユーザーが参加申請中かどうか
  def pending_request_by?(user)
    return false if user.blank?
    group_join_requests.pending.exists?(user: user)
  end

  # グループが満員かどうか
  def full?
    members.count >= max_members
  end
end