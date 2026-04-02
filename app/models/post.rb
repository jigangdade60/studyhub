class Post < ApplicationRecord
  # 投稿は1人のユーザーに紐づく
  belongs_to :user

  # バリデーション
  validates :title, presence: true
  validates :body, presence: true
end