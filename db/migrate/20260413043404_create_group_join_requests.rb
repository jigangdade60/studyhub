class CreateGroupJoinRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :group_join_requests do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :group_join_requests, [:group_id, :user_id], unique: true
  end
end