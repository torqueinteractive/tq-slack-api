class AddFieldsToEncryptUserTokens < ActiveRecord::Migration[5.1]
  def self.up
    add_column :users, :encrypted_token, :string
    add_column :users, :encrypted_token_iv, :string

    User.all.each do |user|
      user.token = user.access_token
      user.save!
    end
  end

  def self.down
    remove_column :users, :encrypted_token, :string
    remove_column :users, :encrypted_token_iv, :string
  end
end