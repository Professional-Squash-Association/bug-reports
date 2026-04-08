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

ActiveRecord::Schema[8.1].define(version: 2026_04_08_094051) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "webhook_secret", default: "", null: false
    t.index ["token"], name: "index_api_keys_on_token", unique: true
  end

  create_table "bug_reports", force: :cascade do |t|
    t.string "callback_url"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "github_issue_number"
    t.string "github_issue_url"
    t.string "github_repo"
    t.string "reporter_email", null: false
    t.string "reporter_name"
    t.string "severity", null: false
    t.string "source", null: false
    t.string "status", default: "pending"
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end
end
