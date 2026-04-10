class AddAdminToSessions < ActiveRecord::Migration[8.0]
  def change
    add_reference :sessions, :admin, foreign_key: true, null: true
    change_column_null :sessions, :user_id, true
  end
end