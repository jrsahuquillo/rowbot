class CreateTrainings < ActiveRecord::Migration[6.1]
  def change
    create_table :trainings do |t|
      t.string :title
      t.datetime :date
      t.string :level
      t.string :gender
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
