class Admin < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy

  validates :email_address, presence: true, uniqueness: true
end