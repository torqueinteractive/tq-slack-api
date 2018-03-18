class AddSlackUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :users do |t|
      t.string :access_token
      t.string :slack_user_id
      t.string :slack_team_id
      t.timestamps
    end
  end
end
