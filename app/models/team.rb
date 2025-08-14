class Team < ApplicationRecord
  has_many :players, dependent: :destroy

  validates :name, presence: true
  validates :city, presence: true

  def display_name = [ city, name ].compact.join(" ")
end
