class RenameSlackUserName < ActiveRecord::Migration[5.1]
  def change
    rename_column :users, :slack_user_name, :user_name
  end
end
