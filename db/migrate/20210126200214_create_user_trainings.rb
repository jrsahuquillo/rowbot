class CreateUserTrainings < ActiveRecord::Migration[6.1]
  def change
    create_table :user_trainings do |t|
      t.integer :user_id
      t.integer :training_id

      t.timestamps
    end
  end
end
