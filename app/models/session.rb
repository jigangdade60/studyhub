class Session < ApplicationRecord
  # 1つのセッションは一般ユーザーまたは管理者のどちらかに紐づく
  # どちらにも対応できるよう optional: true にしている
  belongs_to :user, optional: true
  belongs_to :admin, optional: true
end