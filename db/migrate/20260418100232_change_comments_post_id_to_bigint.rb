class ChangeCommentsPostIdToBigint < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :comments, :posts if foreign_key_exists?(:comments, :posts)

    change_column :comments, :post_id, :bigint

    add_foreign_key :comments, :posts
  end
end
