class Session < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :admin, optional: true
end