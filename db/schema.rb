# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_01_26_200214) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "trainings", force: :cascade do |t|
    t.string "title"
    t.datetime "date"
    t.string "level"
    t.string "gender"
    t.string "boat"
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_trainings_on_user_id"
  end

  create_table "user_trainings", force: :cascade do |t|
    t.integer "user_id"
    t.integer "training_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "telegram_id"
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.string "level"
    t.string "gender"
    t.string "role", default: "rower"
    t.boolean "enabled", default: false
    t.jsonb "bot_command_data", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "trainings", "users"
end
