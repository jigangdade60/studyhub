class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy

  validates :name, presence: true, length: { maximum: 20 }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  scope :search_by_name, ->(keyword) {
    return all if keyword.blank?

    where("name LIKE ?", "%#{keyword}%")
  }
end