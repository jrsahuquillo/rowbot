class Training < ApplicationRecord
  belongs_to :user #role: 'admin'
  has_many :user_trainings
  has_many :users, through: :user_trainings

  scope :joinable, -> { where('date >= ?', Time.now) }
end
