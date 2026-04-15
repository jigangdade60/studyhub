class AddIsPublicToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :is_public, :boolean, null: false, default: true
  end
end