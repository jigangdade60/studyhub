class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :posts, dependent: :destroy

  validates :name, presence: true, length: { maximum: 20 }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end