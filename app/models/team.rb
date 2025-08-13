class Team < ApplicationRecord
  has_many :players, dependent: :destroy
  
  validates :name, presence: true
  validates :city, presence: true
end