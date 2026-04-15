class User < ApplicationRecord
  has_secure_password
  has_one_attached :profile_image

  has_many :sessions, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :liked_posts, through: :likes, source: :post

  has_many :active_relationships,
           class_name: "Relationship",
           foreign_key: "follower_id",
           dependent: :destroy

  has_many :following,
           through: :active_relationships,
           source: :followed

  has_many :passive_relationships,
           class_name: "Relationship",
           foreign_key: "followed_id",
           dependent: :destroy

  has_many :followers,
           through: :passive_relationships,
           source: :follower

  has_many :owned_groups,
           class_name: "Group",
           foreign_key: :owner_id,
           dependent: :destroy

  has_many :group_memberships, dependent: :destroy
  has_many :joined_groups, through: :group_memberships, source: :group

  has_many :group_join_requests, dependent: :destroy
  has_many :group_messages, dependent: :destroy

  has_many :sent_dm_messages,
           class_name: "DmMessage",
           dependent: :destroy,
           foreign_key: :user_id

  has_many :dm_rooms_as_user1,
           class_name: "DmRoom",
           foreign_key: :user1_id,
           dependent: :destroy

  has_many :dm_rooms_as_user2,
           class_name: "DmRoom",
           foreign_key: :user2_id,
           dependent: :destroy

  has_many :received_notifications,
           class_name: "Notification",
           foreign_key: :recipient_id,
           dependent: :destroy

  has_many :sent_notifications,
           class_name: "Notification",
           foreign_key: :actor_id,
           dependent: :destroy

  validates :name, presence: true, length: { maximum: 20 }
  validates :email_address, presence: true, uniqueness: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  scope :search_by_name, ->(keyword) {
    return all if keyword.blank?
    where("name LIKE ?", "%#{keyword}%")
  }

  scope :public_profiles, -> { where(is_public: true) }

  def follow(user)
    active_relationships.create(followed_id: user.id)
  end

  def unfollow(user)
    active_relationships.find_by(followed_id: user.id)&.destroy
  end

  def following?(user)
    following.include?(user)
  end

  def mutual_follow_with?(user)
    following?(user) && user.following?(self)
  end

  def public_profile?
    is_public
  end

  def visible_to?(viewer)
    is_public || self == viewer
  end
end