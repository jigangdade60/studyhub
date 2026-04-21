class GroupMessage < ApplicationRecord
  # グループ内でのメッセージはグループとユーザーに紐づく
  belongs_to :group
  belongs_to :user

  # メッセージ内容は必須かつ500文字以内に制限する
  validates :content, presence: true, length: { maximum: 500 }
end