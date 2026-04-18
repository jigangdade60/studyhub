class AddDemoToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :demo, :boolean, default: false, null: false
  end
end
