class AddFieldsToEncryptUserTokens < ActiveRecord::Migration[5.1]
  def self.up
    add_column :users, :encrypted_access_token, :string
    add_column :users, :encrypted_access_token_iv, :string

    User.each do |user|
      user.access_token
      # convert over the tokens to the new encrypted fields
    end
  end

  def self.down
    remove_column :users, :encrypted_access_token, :string
    remove_column :users, :encrypted_access_token_iv, :string
  end
end