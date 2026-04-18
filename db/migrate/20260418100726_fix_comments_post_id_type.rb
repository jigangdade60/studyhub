class FixCommentsPostIdType < ActiveRecord::Migration[8.0]
  def change
    change_column :comments, :post_id, :bigint
  end
end
