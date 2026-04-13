class Group < ApplicationRecord
  belongs_to :owner, class_name: "User"

  has_many :group_memberships, dependent: :destroy
  has_many :members, through: :group_memberships, source: :user

  has_many :group_join_requests, dependent: :destroy
  has_many :group_messages, dependent: :destroy

  validates :name, presence: true, length: { maximum: 50 }
  validates :description, presence: true, length: { maximum: 500 }
  validates :rule, length: { maximum: 500 }
  validates :study_theme, presence: true, length: { maximum: 100 }
  validates :max_members,
            presence: true,
            numericality: { only_integer: true, greater_than: 1, less_than_or_equal_to: 100 }

  scope :search_by_keyword, ->(keyword) {
    return all if keyword.blank?

    where("name LIKE :q OR study_theme LIKE :q", q: "%#{keyword}%")
  }

  def owned_by?(user)
    owner == user
  end

  def joined_by?(user)
    return false if user.blank?
    members.exists?(user.id)
  end

  def pending_request_by?(user)
    return false if user.blank?
    group_join_requests.pending.exists?(user: user)
  end

  def full?
    members.count >= max_members
  end
end