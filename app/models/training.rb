class Training < ApplicationRecord
  belongs_to :user #role: 'admin'
  has_many :user_trainings
  has_many :users, through: :user_trainings

  scope :joinable, -> { where('date >= ?', Time.now) }

  def boat_capacity
    {
      'Falucho' => '8',
      'Llaüt' => '8',
      'Yola' => '2',
      'Dos de Mar' => '2'
    }
  end

  def capacity
    boat_capacity[boat]
  end
end
