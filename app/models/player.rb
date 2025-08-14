class Player < ApplicationRecord
  belongs_to :team

  validates :name, presence: true
  validates :position, presence: true
  validates :jersey_number, presence: true, uniqueness: { scope: :team_id }
end
