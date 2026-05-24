class AddCommentsCountToPosts < ActiveRecord::Migration[6.1]
  def change
    add_column :posts, :comments_count, :integer, null: false, default: 0
    add_index :posts, :comments_count
  end
end
