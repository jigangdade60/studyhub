class AddDemoToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :demo, :boolean, default: false, null: false
  end
end
