class ChangeCommentsUserIdToBigint < ActiveRecord::Migration[8.0]
  def change
    change_column :comments, :user_id, :bigint
  end
end
