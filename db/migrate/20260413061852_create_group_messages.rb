class CreateGroupMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :group_messages do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false

      t.timestamps
    end
  end
end