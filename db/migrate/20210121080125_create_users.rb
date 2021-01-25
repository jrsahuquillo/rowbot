class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :telegram_id
      t.string :username
      t.string :first_name
      t.string :last_name
      t.string :level
      t.string :gender
      t.string :role, default: 'rower'
      t.boolean :enabled, default: false
      t.jsonb :bot_command_data, default: {}

      t.timestamps null: false
    end
  end
end
