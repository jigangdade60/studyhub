class GroupMessage < ApplicationRecord
  belongs_to :group
  belongs_to :user

  validates :content, presence: true, length: { maximum: 500 }
end