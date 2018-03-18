class CreateTableTeams < ActiveRecord::Migration[5.1]
  def change
    create_table :teams do |t|
      t.string :name
      t.string :slack_team_id
      t.timestamps
    end

    remove_column :users, :slack_team_id, :string
  end
end
