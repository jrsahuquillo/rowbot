class UserTraining < ApplicationRecord
  belongs_to :user
  belongs_to :training
end
