class AddLikesCountToPosts < ActiveRecord::Migration[6.1]
  def change
    add_column :posts, :likes_count, :integer, null: false, default: 0
    add_index :posts, :likes_count
  end
end
