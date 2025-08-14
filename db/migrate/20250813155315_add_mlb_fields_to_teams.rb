class AddMlbFieldsToTeams < ActiveRecord::Migration[8.0]
  def change
    add_column :teams, :mlb_team_id, :integer
    add_column :teams, :abbreviation, :string
    add_column :teams, :league, :string
    add_column :teams, :division, :string
    add_column :teams, :active, :boolean, default: true, null: false

    add_index :teams, :mlb_team_id, unique: true
  end
end
