class RemoveOldAccessTokenColumn < ActiveRecord::Migration[5.1]
  def change
    remove_column :users, :access_token, :string
  end
end
